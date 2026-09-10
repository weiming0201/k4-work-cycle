#!/usr/bin/env python3
"""End-to-end conformance checks for the five-Skill work cycle."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SKILL_NAMES = ("k4-observe", "k4-goal", "k4-plan", "k4-run", "k4-finish")


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode()


def write_json(path: Path, value: Any) -> None:
    path.write_bytes(canonical_bytes(value))


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_bytes())


def published_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for path in root.rglob("*"):
        relative = path.relative_to(root)
        if not path.is_file() or any(part in {".git", "__pycache__"} for part in relative.parts):
            continue
        if relative.as_posix() == "manifest.json":
            continue
        files.append(relative)
    return sorted(files, key=lambda item: item.as_posix())


def manifest_input(root: Path) -> dict[str, Any]:
    entrypoints = {
        "k4-observe": ["skills/k4-observe/scripts/materialize"],
        "k4-goal": ["skills/k4-goal/scripts/materialize"],
        "k4-plan": ["skills/k4-plan/scripts/materialize"],
        "k4-run": ["skills/k4-run/scripts/append", "skills/k4-run/scripts/project", "skills/k4-run/scripts/validate"],
        "k4-finish": ["skills/k4-finish/scripts/materialize"],
    }
    return {
        "extension_id": "k4-work-cycle",
        "extension_version": "0.4.1",
        "semantic_entry": "WORKFLOW.md",
        "cue_version": "v0.17.1",
        "shared_tool": "tools/stable-result",
        "skills": [
            {
                "name": name,
                "path": f"skills/{name}",
                "protocol": f"skills/{name}/assets/protocol.cue",
                "entrypoints": entrypoints[name],
            }
            for name in SKILL_NAMES
        ],
        "files": [
            {
                "path": relative.as_posix(),
                "sha256": hashlib.sha256((root / relative).read_bytes()).hexdigest(),
            }
            for relative in published_files(root)
        ],
    }


def invoke(*words: str, cwd: Path, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(words, cwd=cwd, env=env, capture_output=True, text=True, check=False)


def generate_manifest(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="k4-manifest-", dir=root.parent) as directory:
        temporary = Path(directory)
        semantic = temporary / "input.json"
        output = temporary / "manifest.json"
        write_json(semantic, manifest_input(root))
        result = invoke(
            str(root / "tools/stable-result"),
            "--contract",
            str(root / "manifest.cue"),
            "materialize",
            "--input",
            str(semantic),
            "--output",
            str(output),
            cwd=root,
        )
        if result.returncode != 0:
            raise AssertionError(f"manifest generation failed\n{result.stdout}{result.stderr}")
        os.replace(output, root / "manifest.json")


def validate_manifest(root: Path) -> None:
    if read_json(root / "manifest.json")["document"] != manifest_input(root):
        raise AssertionError("manifest does not match current published files")
    result = invoke(
        str(root / "tools/stable-result"),
        "--contract",
        str(root / "manifest.cue"),
        "validate",
        "--document",
        str(root / "manifest.json"),
        cwd=root,
    )
    if result.returncode != 0:
        raise AssertionError(f"manifest validation failed\n{result.stdout}{result.stderr}")


class Harness:
    def __init__(self, root: Path, work: Path) -> None:
        self.root = root
        self.work = work
        self.tool = root / "tools/stable-result"
        self.env = dict(os.environ)
        self.env["K4_STABLE_RESULT"] = str(self.tool)
        self.passed = 0

    def command(self, skill: str, script: str) -> str:
        return str(self.root / "skills" / skill / "scripts" / script)

    def ok(self, label: str, *words: str) -> subprocess.CompletedProcess[str]:
        result = invoke(*words, cwd=self.root, env=self.env)
        if result.returncode != 0:
            raise AssertionError(f"{label}: expected success\n{result.stdout}{result.stderr}")
        self.passed += 1
        print(f"PASS {label}")
        return result

    def refuse(self, label: str, *words: str) -> None:
        result = invoke(*words, cwd=self.root, env=self.env)
        if result.returncode == 0:
            raise AssertionError(f"{label}: expected refusal\n{result.stdout}{result.stderr}")
        self.passed += 1
        print(f"PASS {label}")

    def materialize(
        self,
        label: str,
        skill: str,
        semantic: dict[str, Any],
        output: Path,
        bindings: list[tuple[str, Path | None]],
        run_log: Path | None = None,
    ) -> None:
        source = self.work / f"{label.replace(' ', '-')}-input.json"
        write_json(source, semantic)
        words = [self.command(skill, "materialize"), "--input", str(source), "--output", str(output)]
        for name, value in bindings:
            if value is None:
                words.extend(("--null-bind", name))
            else:
                words.extend(("--bind", f"{name}={value}"))
        if run_log is not None:
            words.extend(("--run-log", str(run_log)))
        self.ok(label, *words)
        validate = [
            str(self.tool),
            "--contract",
            str(self.root / "skills" / skill / "assets/protocol.cue"),
            "validate",
            "--document",
            str(output),
        ]
        for name, value in bindings:
            if value is None:
                validate.extend(("--null-bind", name))
            else:
                validate.extend(("--bind", f"{name}={value}"))
        if run_log is not None:
            validate.extend(
                (
                    "--project-log-bind",
                    f"run={run_log}",
                    "--projection-contract",
                    str(self.root / "skills" / "k4-run" / "assets" / "protocol.cue"),
                    "--projection-bind",
                    "goal",
                    "--projection-bind",
                    "plan",
                )
            )
        self.ok(f"validate {label}", *validate)

    def append(self, label: str, event: dict[str, Any], log: Path, goal: Path, plan: Path) -> None:
        source = self.work / f"{label.replace(' ', '-')}.json"
        write_json(source, event)
        self.ok(
            label,
            self.command("k4-run", "append"),
            "--input",
            str(source),
            "--log",
            str(log),
            "--bind",
            f"goal={goal}",
            "--bind",
            f"plan={plan}",
        )

    def run(self) -> None:
        observe0 = self.work / "observe0.json"
        observe_input = {
            "mode": "bootstrap",
            "subject": "isolated repository",
            "boundary": "only the isolated repository fixture",
            "cutoff": "fixture baseline",
            "source_refs": ["asset://repo"],
            "lenses": ["delivery", "structure"],
            "delta": {"summary": "initial source inspection", "evidence_refs": ["asset://repo"]},
            "items": [
                {
                    "lens": "delivery",
                    "change": "added",
                    "previous_item_id": None,
                    "change_reason": "initial observation",
                    "epistemic_kind": "fact",
                    "state": "gap",
                    "statement": "the expected result is absent",
                    "evidence_refs": ["asset://repo"],
                    "route": "goal-candidate",
                    "route_ref": None,
                },
                {
                    "lens": "structure",
                    "change": "added",
                    "previous_item_id": None,
                    "change_reason": "initial observation",
                    "epistemic_kind": "source-statement",
                    "state": "aligned",
                    "statement": "the fixture boundary is addressable",
                    "evidence_refs": ["asset://repo"],
                    "route": "retain",
                    "route_ref": None,
                },
            ],
            "retired": [],
        }
        self.materialize("Observe bootstrap", "k4-observe", observe_input, observe0, [("previous_account", None)])
        observe = read_json(observe0)["document"]
        if [entry["lens"] for entry in observe["account"]["lens_index"]] != ["delivery", "structure"]:
            raise AssertionError("Observe did not generate the declared lens index")
        self.passed += 1
        print("PASS Observe lens index")
        gap_id, structure_id = [item["item_id"] for item in observe["account"]["items"]]

        goal = self.work / "goal.json"
        goal_input = {
            "observe_item_ids": [gap_id],
            "objective": "produce and verify the expected fixture result",
            "selection_rationale": "this bounded Goal directly addresses the selected gap with available evidence and tools",
            "target": "isolated repository fixture",
            "source_refs": ["asset://repo"],
            "evidence_cutoff": {"at": "before execution", "included_refs": ["asset://repo"]},
            "baseline_refs": ["asset://repo"],
            "scope": ["fixture result only"],
            "non_goals": ["publication"],
            "execution_envelope": {
                "authorization_ref": "authorization://fixture",
                "authorization_scope": "fixture only",
                "authorization_claim_limit": "no external effect",
                "available_tools": ["tool://fixture"],
                "resources": ["resource://local"],
                "budget": "one bounded attempt",
                "maximum_side_effects": ["fixture files"],
            },
            "acceptance_points": [
                {
                    "statement": "the expected result is valid",
                    "required_evidence": ["result and validator evidence"],
                    "judge": {"kind": "script", "claim_limit": "fixture result only"},
                    "acceptance": {
                        "observable": "result and validation status",
                        "conditions": ["fixture baseline"],
                        "window": "after Run",
                        "expected": "result exists and validates",
                        "falsifier": "result is absent or invalid",
                        "comparison_method": "exact result validation",
                        "sampling_rule": "full census",
                    },
                }
            ],
            "control_contracts": [
                {
                    "statement": "writes remain inside the fixture",
                    "required_evidence": ["write trace"],
                    "judge": {"kind": "script", "claim_limit": "write paths only"},
                    "controlled_variable": "write path",
                    "allowed_domain": ["fixture"],
                    "forbidden_drift": ["outside fixture"],
                    "required_trace": ["write trace"],
                    "check_method": "compare paths with fixture boundary",
                    "check_timing": "invariant",
                },
                {
                    "statement": "terminal result remains within budget",
                    "required_evidence": ["budget trace"],
                    "judge": {"kind": "script", "claim_limit": "declared budget only"},
                    "controlled_variable": "resource use",
                    "allowed_domain": ["bounded attempt"],
                    "forbidden_drift": ["unbounded use"],
                    "required_trace": ["budget trace"],
                    "check_method": "compare actual use with budget",
                    "check_timing": "terminal",
                },
            ],
            "blockers": [],
            "unknowns": ["runtime duration is not predicted"],
        }
        self.materialize("Goal", "k4-goal", goal_input, goal, [("observe", observe0)])
        goal_doc = read_json(goal)["document"]
        if goal_doc["status"] != "frozen":
            raise AssertionError("a declared unknown incorrectly blocked Goal")
        point_id = goal_doc["acceptance_points"][0]["point_id"]
        invariant_id, terminal_id = [item["control_id"] for item in goal_doc["control_contracts"]]

        def operation(key: str, deps: list[int], targets_pass: list[int], targets_fail: list[int], satisfies: list[str]) -> dict[str, Any]:
            return {
                "operation_key": key,
                "depends_on_indices": deps,
                "satisfies": satisfies,
                "controlled_by": [invariant_id, terminal_id],
                "tool_ref": "tool://fixture",
                "responsible_ref": "agent://fixture",
                "read_refs": ["asset://repo"],
                "write_refs": [f"artifact://{key}"],
                "permission_refs": ["authorization://fixture"],
                "resource_refs": ["resource://local"],
                "maximum_side_effects": ["fixture files"],
                "pre_checks": ["operation is activated"],
                "post_checks": ["declared result is observable"],
                "idempotency": "fresh fixture output",
                "retry_limit": 0,
                "recovery": "follow the frozen fail edge",
                "on_result": {
                    "pass": {"next_operation_indices": targets_pass, "reason": "pass route"},
                    "fail": {"next_operation_indices": targets_fail, "reason": "fail route"},
                },
            }

        plan = self.work / "plan.json"
        plan_input = {
            "difference": "the accepted fixture result is absent",
            "selection_rationale": "the fork-join route exercises independent work while preserving one bounded settlement",
            "route": {"claim": "fork two checks and join their responses", "supporting_refs": ["asset://repo"], "counter_refs": []},
            "entry_operation_indices": [0],
            "operations": [
                operation("prepare", [], [1, 2], [], []),
                operation("branch-a", [], [3], [3], []),
                operation("branch-b", [], [3], [3], []),
                operation("join-result", [1, 2], [], [], [point_id]),
            ],
            "blockers": [],
            "unknowns": ["one branch may fail and use its frozen route"],
        }
        self.materialize("Plan", "k4-plan", plan_input, plan, [("goal", goal)])
        plan_doc = read_json(plan)["document"]
        if plan_doc["status"] != "executable" or len(plan_doc["topology"]["forks"]) != 1 or len(plan_doc["topology"]["joins"]) != 1:
            raise AssertionError("Plan did not materialize the fork-join topology")
        self.passed += 1
        print("PASS Plan fork-join topology")
        operations = [item["operation_id"] for item in plan_doc["operations"]]

        def invariant() -> dict[str, Any]:
            return {
                "control_id": invariant_id,
                "result": "pass",
                "actual_refs": ["actual://inside-fixture"],
                "trace_refs": ["trace://write"],
                "comparison_refs": ["comparison://boundary"],
                "evidence_refs": ["evidence://invariant"],
            }

        def result_event(index: int, result: str, *, finding: bool = False, unknown: bool = False) -> dict[str, Any]:
            return {
                "kind": "operation-result",
                "operation_id": operations[index],
                "result": result,
                "eligibility_refs": ["eligibility://plan"],
                "actual_output_refs": [f"actual://{index}"] if result == "pass" else [],
                "evidence_refs": [f"evidence://operation-{index}"],
                "trace_refs": [f"trace://operation-{index}"],
                "invariant_checks": [invariant()],
                "findings": ([{"statement": "branch failure remains relevant", "evidence_refs": ["evidence://op-finding"]}] if finding else []),
                "unknowns": ([{"statement": "branch cause remains unknown", "basis_refs": ["basis://op-unknown"]}] if unknown else []),
            }

        log = self.work / "run.jsonl"
        self.append("Run prepare", result_event(0, "pass"), log, goal, plan)
        patch_event = {
            "kind": "emergency-patch",
            "operation_id": operations[2],
            "attempt": 1,
            "application_result": "applied",
            "reason": "supply one missing fixture adapter",
            "script_ref": "script://fixture-adapter",
            "tool_refs": ["tool://fixture"],
            "read_refs": ["asset://repo"],
            "write_refs": ["artifact://adapter"],
            "maximum_side_effects": ["one fixture adapter"],
            "actual_side_effect_refs": ["actual://adapter"],
            "trace_refs": ["trace://patch"],
            "findings": [{"statement": "the Plan omitted a required adapter", "evidence_refs": ["evidence://patch-finding"]}],
            "unknowns": [{"statement": "adapter portability is unknown", "basis_refs": ["basis://patch-unknown"]}],
            "verification_scope": "mainline-resumption-only",
        }
        self.append("Run emergency patch", patch_event, log, goal, plan)
        duplicate_input = self.work / "duplicate-patch.json"
        write_json(duplicate_input, patch_event)
        before = log.read_bytes()
        self.refuse(
            "Run rejects second patch",
            self.command("k4-run", "append"),
            "--input",
            str(duplicate_input),
            "--log",
            str(log),
            "--bind",
            f"goal={goal}",
            "--bind",
            f"plan={plan}",
        )
        if log.read_bytes() != before:
            raise AssertionError("refused patch changed the Run ledger")
        self.append("Run branch A", result_event(1, "pass"), log, goal, plan)
        self.append("Run branch B", result_event(2, "fail", finding=True, unknown=True), log, goal, plan)
        self.append("Run join", result_event(3, "pass"), log, goal, plan)
        self.append(
            "Run halt",
            {
                "kind": "halt",
                "after_operation_id": operations[3],
                "next_operation_id": None,
                "trigger": "plan-complete",
                "budget_evidence_refs": ["evidence://budget"],
                "side_effect_evidence_refs": ["evidence://effects"],
                "evidence_refs": ["evidence://halt"],
                "resume_ref": None,
            },
            log,
            goal,
            plan,
        )
        projection = self.work / "run-projection.json"
        self.ok(
            "Run projection",
            self.command("k4-run", "project"),
            "--log",
            str(log),
            "--output",
            str(projection),
            "--bind",
            f"goal={goal}",
            "--bind",
            f"plan={plan}",
        )
        projected = read_json(projection)["document"]
        if projected["execution_result"] != "fail" or [item["result"] for item in projected["operations"]] != ["pass", "pass", "fail", "pass"]:
            raise AssertionError("Run projection did not preserve binary operation results")

        finish = self.work / "finish.json"
        finish_sources = [
            "asset://repo",
            "run://ledger",
            "accept://result",
            "terminal://control",
            "evidence://op-finding",
            "basis://op-unknown",
            "evidence://patch-finding",
            "basis://patch-unknown",
        ]
        finish_input = {
            "subject": observe["account"]["subject"],
            "boundary": observe["account"]["boundary"],
            "cutoff": "after Run halt",
            "source_refs": finish_sources,
            "lenses": observe["account"]["lenses"],
            "delta": {"summary": "the bounded attempt was settled", "evidence_refs": ["run://ledger"]},
            "items": [
                {
                    "lens": "delivery",
                    "change": "changed",
                    "previous_item_id": gap_id,
                    "change_reason": "Run produced acceptance evidence",
                    "epistemic_kind": "fact",
                    "state": "aligned",
                    "statement": "the expected result exists and validates",
                    "evidence_refs": ["run://ledger"],
                    "route": "none",
                    "route_ref": None,
                },
                {
                    "lens": "structure",
                    "change": "retained",
                    "previous_item_id": structure_id,
                    "change_reason": "the source statement remains current",
                    "epistemic_kind": "source-statement",
                    "state": "aligned",
                    "statement": "the fixture boundary is addressable",
                    "evidence_refs": ["asset://repo"],
                    "route": "retain",
                    "route_ref": None,
                },
            ],
            "retired": [],
            "acceptance_results": [
                {
                    "id": point_id,
                    "result": "pass",
                    "actual_refs": ["actual://result"],
                    "comparison_refs": ["comparison://validator"],
                    "evidence_refs": ["accept://result"],
                    "unknowns": [],
                }
            ],
            "terminal_control_results": [
                {
                    "id": terminal_id,
                    "result": "pass",
                    "actual_refs": ["actual://budget"],
                    "comparison_refs": ["comparison://budget"],
                    "evidence_refs": ["terminal://control"],
                    "unknowns": [],
                }
            ],
            "result_disposition": {"state": "placed", "statement": "result remains in fixture", "refs": ["actual://result"]},
            "incomplete_deliverable": None,
        }
        self.materialize(
            "Finish",
            "k4-finish",
            finish_input,
            finish,
            [("previous_account", observe0), ("goal", goal), ("plan", plan)],
            run_log=log,
        )
        closure = read_json(finish)["document"]["closure"]
        if closure["attempt_result"] != "pass" or closure["operation_summary"] != {
            "planned": 4,
            "actual": 4,
            "not_run": 0,
            "passed": 3,
            "failed": 1,
            "emergency_patches": 1,
            "findings": 2,
            "unknowns": 2,
        }:
            raise AssertionError("Finish did not derive the truthful settlement")
        self.passed += 1
        print("PASS Finish recovered-failure settlement")

        finish_account = read_json(finish)["document"]["account"]
        next_observe = self.work / "observe1.json"
        next_input = {
            "mode": "iterate",
            "subject": finish_account["subject"],
            "boundary": finish_account["boundary"],
            "cutoff": "fresh observation after Finish",
            "source_refs": ["observe://fresh", "asset://repo"],
            "lenses": finish_account["lenses"],
            "delta": {"summary": "fresh observation", "evidence_refs": ["observe://fresh"]},
            "items": [
                {
                    "lens": "delivery",
                    "change": "changed",
                    "previous_item_id": finish_account["items"][0]["item_id"],
                    "change_reason": "fresh observation confirms persistence",
                    "epistemic_kind": "fact",
                    "state": "aligned",
                    "statement": "the result remains observable",
                    "evidence_refs": ["observe://fresh"],
                    "route": "none",
                    "route_ref": None,
                },
                {
                    "lens": "structure",
                    "change": "retained",
                    "previous_item_id": finish_account["items"][1]["item_id"],
                    "change_reason": "the source statement remains current",
                    "epistemic_kind": "source-statement",
                    "state": "aligned",
                    "statement": "the fixture boundary is addressable",
                    "evidence_refs": ["asset://repo"],
                    "route": "retain",
                    "route_ref": None,
                },
            ],
            "retired": [],
        }
        self.materialize("Observe after Finish", "k4-observe", next_input, next_observe, [("previous_account", finish)])

        invalid_plan = json.loads(json.dumps(plan_input))
        invalid_plan["operations"][1]["on_result"]["pass"]["next_operation_indices"] = [0]
        invalid_source = self.work / "invalid-plan.json"
        write_json(invalid_source, invalid_plan)
        self.refuse(
            "Plan rejects a back edge",
            self.command("k4-plan", "materialize"),
            "--input",
            str(invalid_source),
            "--output",
            str(self.work / "never-plan.json"),
            "--bind",
            f"goal={goal}",
        )
        self.refuse(
            "Run rejects an unactivated operation",
            self.command("k4-run", "append"),
            "--input",
            str(self.work / "Run-branch-A.json"),
            "--log",
            str(self.work / "empty-run.jsonl"),
            "--bind",
            f"goal={goal}",
            "--bind",
            f"plan={plan}",
        )
        print(f"PASS {self.passed} checks")


def copy_extension(source: Path, target: Path) -> None:
    shutil.copytree(source, target, ignore=shutil.ignore_patterns(".git", "__pycache__", "manifest.json"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-manifest", action="store_true")
    args = parser.parse_args()
    if args.write_manifest:
        generate_manifest(ROOT)
        validate_manifest(ROOT)
        print("PASS generated manifest")
        return 0
    validate_manifest(ROOT)
    with tempfile.TemporaryDirectory(prefix="k4-work-cycle-") as directory:
        temporary = Path(directory)
        extension = temporary / "extension"
        work = temporary / "work"
        copy_extension(ROOT, extension)
        work.mkdir()
        Harness(extension, work).run()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL {error}", file=os.sys.stderr)
        raise SystemExit(1)
