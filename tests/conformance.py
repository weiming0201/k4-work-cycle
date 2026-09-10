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
        "extension_version": "0.6.0",
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
                "permission_refs": ["authorization://fixture"],
                "read_refs": ["asset://repo"],
                "write_refs": ["artifact://prepare", "artifact://branch-a", "artifact://branch-b", "artifact://join-result", "artifact://adapter"],
                "resources": ["resource://local"],
                "budget": "one bounded attempt",
                "maximum_side_effects": ["fixture files", "one fixture adapter"],
            },
            "acceptance_points": [
                {
                    "statement": "the expected result is valid",
                    "required_evidence": ["result and validator evidence"],
                    "judge": {"kind": "script", "ref": "tool://fixture", "claim_limit": "fixture result only"},
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
                    "judge": {"kind": "script", "ref": "tool://fixture", "claim_limit": "write paths only"},
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
                    "judge": {"kind": "script", "ref": "tool://fixture", "claim_limit": "declared budget only"},
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

        # Frozen Goals must have an acceptance surface and sourceable judges.
        empty_goal_input = json.loads(json.dumps(goal_input))
        empty_goal_input["acceptance_points"] = []
        empty_goal_source = self.work / "goal-empty-acceptance-input.json"
        write_json(empty_goal_source, empty_goal_input)
        self.refuse(
            "Goal rejects empty acceptance",
            self.command("k4-goal", "materialize"),
            "--input", str(empty_goal_source),
            "--output", str(self.work / "never-empty-goal.json"),
            "--bind", f"observe={observe0}",
        )
        bad_judge_goal_input = json.loads(json.dumps(goal_input))
        bad_judge_goal_input["acceptance_points"][0]["judge"]["ref"] = "tool://unavailable-judge"
        bad_judge_source = self.work / "goal-unavailable-judge-input.json"
        write_json(bad_judge_source, bad_judge_goal_input)
        self.refuse(
            "Goal rejects unavailable judge",
            self.command("k4-goal", "materialize"),
            "--input", str(bad_judge_source),
            "--output", str(self.work / "never-unavailable-judge-goal.json"),
            "--bind", f"observe={observe0}",
        )
        self.materialize("Goal", "k4-goal", goal_input, goal, [("observe", observe0)])
        goal_doc = read_json(goal)["document"]
        if goal_doc["status"] != "frozen":
            raise AssertionError("a declared unknown incorrectly blocked Goal")
        point_id = goal_doc["acceptance_points"][0]["point_id"]
        invariant_id, terminal_id = [item["control_id"] for item in goal_doc["control_contracts"]]

        def operation(key: str, deps: list[int], targets_pass: list[int], targets_fail: list[int], satisfies: list[str]) -> dict[str, Any]:
            return {
                "phase": "normal",
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
            "on_abort": {
                "mode": "preserve-only",
                "entry_operation_index": None,
                "reason": "preserve the sourced abort state without inventing recovery work",
            },
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

        boundary_mutations = {
            "tool": ("tool_ref", "tool://outside-goal"),
            "permission": ("permission_refs", ["authorization://outside-goal"]),
            "read": ("read_refs", ["asset://outside-goal"]),
            "write": ("write_refs", ["artifact://outside-goal"]),
            "resource": ("resource_refs", ["resource://outside-goal"]),
            "effect": ("maximum_side_effects", ["outside-goal effect"]),
        }
        for label, (field, value) in boundary_mutations.items():
            invalid_boundary_plan = json.loads(json.dumps(plan_input))
            invalid_boundary_plan["operations"][0][field] = value
            source = self.work / f"plan-outside-{label}-input.json"
            write_json(source, invalid_boundary_plan)
            self.refuse(
                f"Plan rejects outside Goal {label}",
                self.command("k4-plan", "materialize"),
                "--input", str(source),
                "--output", str(self.work / f"never-plan-outside-{label}.json"),
                "--bind", f"goal={goal}",
            )

        independent_goal_input = json.loads(json.dumps(goal_input))
        independent_goal_input["source_refs"].append("agent://fixture")
        independent_goal_input["evidence_cutoff"]["included_refs"].append("agent://fixture")
        independent_goal_input["acceptance_points"][0]["judge"] = {
            "kind": "independent-agent",
            "ref": "agent://fixture",
            "claim_limit": "fixture result only",
        }
        independent_goal = self.work / "independent-judge-goal.json"
        self.materialize(
            "Goal with independent judge",
            "k4-goal",
            independent_goal_input,
            independent_goal,
            [("observe", observe0)],
        )
        independent_point_id = read_json(independent_goal)["document"]["acceptance_points"][0]["point_id"]
        self_judged_plan_input = json.loads(json.dumps(plan_input))
        self_judged_plan_input["operations"][-1]["satisfies"] = [independent_point_id]
        self_judged_plan_input["operations"][-1]["responsible_ref"] = "agent://fixture"
        self_judged_plan_source = self.work / "plan-self-judged-input.json"
        write_json(self_judged_plan_source, self_judged_plan_input)
        self.refuse(
            "Plan rejects independent judge as executor",
            self.command("k4-plan", "materialize"),
            "--input", str(self_judged_plan_source),
            "--output", str(self.work / "never-self-judged-plan.json"),
            "--bind", f"goal={independent_goal}",
        )
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
            "permission_refs": ["authorization://fixture"],
            "read_refs": ["asset://repo"],
            "write_refs": ["artifact://adapter"],
            "resource_refs": ["resource://local"],
            "maximum_side_effects": ["one fixture adapter"],
            "actual_side_effect_refs": ["actual://adapter"],
            "trace_refs": ["trace://patch"],
            "findings": [{"statement": "the Plan omitted a required adapter", "evidence_refs": ["evidence://patch-finding"]}],
            "unknowns": [{"statement": "adapter portability is unknown", "basis_refs": ["basis://patch-unknown"]}],
            "verification_scope": "mainline-resumption-only",
        }
        patch_boundary_mutations = {
            "tool": ("tool_refs", ["tool://outside-goal"]),
            "permission": ("permission_refs", ["authorization://outside-goal"]),
            "read": ("read_refs", ["asset://outside-goal"]),
            "write": ("write_refs", ["artifact://outside-goal"]),
            "resource": ("resource_refs", ["resource://outside-goal"]),
            "effect": ("maximum_side_effects", ["outside-goal effect"]),
        }
        for label, (field, value) in patch_boundary_mutations.items():
            invalid_patch = json.loads(json.dumps(patch_event))
            invalid_patch[field] = value
            invalid_patch_source = self.work / f"patch-outside-{label}.json"
            write_json(invalid_patch_source, invalid_patch)
            before = log.read_bytes()
            self.refuse(
                f"Run rejects patch outside Goal {label}",
                self.command("k4-run", "append"),
                "--input", str(invalid_patch_source),
                "--log", str(log),
                "--bind", f"goal={goal}",
                "--bind", f"plan={plan}",
            )
            if log.read_bytes() != before:
                raise AssertionError("refused boundary patch changed the Run ledger")
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
                    "judge_ref": "tool://fixture",
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
                    "judge_ref": "tool://fixture",
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
        bad_finish_input = json.loads(json.dumps(finish_input))
        bad_finish_input["acceptance_results"][0]["judge_ref"] = "tool://other-judge"
        bad_finish_source = self.work / "finish-wrong-judge-input.json"
        write_json(bad_finish_source, bad_finish_input)
        self.refuse(
            "Finish rejects wrong actual judge",
            self.command("k4-finish", "materialize"),
            "--input", str(bad_finish_source),
            "--output", str(self.work / "never-finish-wrong-judge.json"),
            "--run-log", str(log),
            "--bind", f"previous_account={observe0}",
            "--bind", f"goal={goal}",
            "--bind", f"plan={plan}",
        )
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

        # Empty optional control and patch collections are a normal boundary case.
        zero_goal_input = json.loads(json.dumps(goal_input))
        zero_goal_input["control_contracts"] = []
        zero_goal = self.work / "zero-control-goal.json"
        self.materialize("Goal with zero controls", "k4-goal", zero_goal_input, zero_goal, [("observe", observe0)])
        zero_point_id = read_json(zero_goal)["document"]["acceptance_points"][0]["point_id"]
        zero_operation = operation("prepare", [], [], [], [zero_point_id])
        zero_operation["controlled_by"] = []
        zero_plan_input = {
            "difference": "the accepted fixture result is absent",
            "selection_rationale": "one operation is sufficient for the zero-control boundary case",
            "route": {"claim": "execute the one bounded operation", "supporting_refs": ["asset://repo"], "counter_refs": []},
            "entry_operation_indices": [0],
            "on_abort": {
                "mode": "preserve-only",
                "entry_operation_index": None,
                "reason": "preserve the sourced abort state without inventing recovery work",
            },
            "operations": [zero_operation],
            "blockers": [],
            "unknowns": [],
        }
        zero_plan = self.work / "zero-control-plan.json"
        self.materialize("Plan with zero controls", "k4-plan", zero_plan_input, zero_plan, [("goal", zero_goal)])
        zero_operation_id = read_json(zero_plan)["document"]["operations"][0]["operation_id"]
        zero_log = self.work / "zero-patch-run.jsonl"
        self.append(
            "Run with zero controls",
            {
                "kind": "operation-result",
                "operation_id": zero_operation_id,
                "result": "pass",
                "eligibility_refs": ["eligibility://plan"],
                "actual_output_refs": ["actual://zero-control-result"],
                "evidence_refs": ["evidence://zero-control-operation"],
                "trace_refs": ["trace://zero-control-operation"],
                "invariant_checks": [],
                "findings": [],
                "unknowns": [],
            },
            zero_log,
            zero_goal,
            zero_plan,
        )
        self.append(
            "Run zero-patch halt",
            {
                "kind": "halt",
                "after_operation_id": zero_operation_id,
                "trigger": "plan-complete",
                "budget_evidence_refs": [],
                "side_effect_evidence_refs": [],
                "evidence_refs": ["evidence://zero-patch-halt"],
                "resume_ref": None,
            },
            zero_log,
            zero_goal,
            zero_plan,
        )
        zero_finish_input = json.loads(json.dumps(finish_input))
        zero_finish_input["source_refs"] = ["asset://repo", "run://ledger", "accept://result"]
        zero_finish_input["acceptance_results"][0]["id"] = zero_point_id
        zero_finish_input["terminal_control_results"] = []
        zero_finish = self.work / "zero-control-finish.json"
        self.materialize(
            "Finish with zero controls and patches",
            "k4-finish",
            zero_finish_input,
            zero_finish,
            [("previous_account", observe0), ("goal", zero_goal), ("plan", zero_plan)],
            run_log=zero_log,
        )
        zero_summary = read_json(zero_finish)["document"]["closure"]["operation_summary"]
        if zero_summary["emergency_patches"] != 0 or zero_summary["planned"] != 1:
            raise AssertionError("zero-element Finish projection is not truthful")
        self.passed += 1
        print("PASS zero-control and zero-patch collections remain legal")

        # Abort is a sourced terminal state whose response is frozen by Plan.
        abort_plan_input = json.loads(json.dumps(plan_input))
        abort_operation = operation("abort-preserve", [], [], [], [])
        abort_operation["phase"] = "abort"
        abort_operation["controlled_by"] = []
        abort_operation["write_refs"] = ["artifact://adapter"]
        abort_plan_input["operations"].append(abort_operation)
        abort_plan_input["on_abort"] = {
            "mode": "route",
            "entry_operation_index": 4,
            "reason": "preserve the bounded runtime state through one declared response operation",
        }
        abort_plan = self.work / "abort-route-plan.json"
        self.materialize("Plan with abort route", "k4-plan", abort_plan_input, abort_plan, [("goal", goal)])
        abort_plan_doc = read_json(abort_plan)["document"]
        abort_operations = [item["operation_id"] for item in abort_plan_doc["operations"]]
        if abort_plan_doc["on_abort"]["entry_operation_id"] != abort_operations[4]:
            raise AssertionError("Plan did not freeze the declared abort route")
        self.passed += 1
        print("PASS Plan freezes abort response")

        cross_phase_input = json.loads(json.dumps(abort_plan_input))
        cross_phase_input["operations"][0]["on_result"]["pass"]["next_operation_indices"].append(4)
        cross_phase_source = self.work / "plan-cross-phase-input.json"
        write_json(cross_phase_source, cross_phase_input)
        self.refuse(
            "Plan rejects cross-phase edge",
            self.command("k4-plan", "materialize"),
            "--input", str(cross_phase_source),
            "--output", str(self.work / "never-cross-phase-plan.json"),
            "--bind", f"goal={goal}",
        )
        abort_acceptance_input = json.loads(json.dumps(abort_plan_input))
        abort_acceptance_input["operations"][4]["satisfies"] = [point_id]
        abort_acceptance_source = self.work / "abort-acceptance-input.json"
        write_json(abort_acceptance_source, abort_acceptance_input)
        self.refuse(
            "Plan rejects abort acceptance claim",
            self.command("k4-plan", "materialize"),
            "--input", str(abort_acceptance_source),
            "--output", str(self.work / "never-abort-acceptance-plan.json"),
            "--bind", f"goal={goal}",
        )

        def abort_result() -> dict[str, Any]:
            return {
                "kind": "operation-result",
                "operation_id": abort_operations[4],
                "result": "pass",
                "eligibility_refs": ["eligibility://abort-route"],
                "actual_output_refs": ["actual://abort-state"],
                "evidence_refs": ["evidence://abort-operation"],
                "trace_refs": ["trace://abort-operation"],
                "invariant_checks": [],
                "findings": [],
                "unknowns": [],
            }

        abort_log = self.work / "abort-run.jsonl"
        abort_prepare = result_event(0, "pass")
        abort_prepare["operation_id"] = abort_operations[0]
        self.append("Abort Run prepare", abort_prepare, abort_log, goal, abort_plan)
        unconfirmed_abort_source = self.work / "unconfirmed-abort-operation.json"
        write_json(unconfirmed_abort_source, abort_result())
        self.refuse(
            "Run rejects unconfirmed abort response",
            self.command("k4-run", "append"),
            "--input", str(unconfirmed_abort_source),
            "--log", str(abort_log),
            "--bind", f"goal={goal}",
            "--bind", f"plan={abort_plan}",
        )
        abort_patch = json.loads(json.dumps(patch_event))
        abort_patch["operation_id"] = abort_operations[4]
        abort_patch_source = self.work / "abort-route-patch.json"
        write_json(abort_patch_source, abort_patch)
        self.refuse(
            "Run rejects patch in abort response",
            self.command("k4-run", "append"),
            "--input", str(abort_patch_source),
            "--log", str(abort_log),
            "--bind", f"goal={goal}",
            "--bind", f"plan={abort_plan}",
        )
        self.append(
            "Run confirms abort",
            {
                "kind": "abort-confirmed",
                "after_operation_id": abort_operations[0],
                "source_ref": "runtime://external-cancellation",
                "reason": "the bounded attempt was externally cancelled",
                "evidence_refs": ["abort://confirmation"],
            },
            abort_log,
            goal,
            abort_plan,
        )
        open_projection = self.work / "abort-open-projection.json"
        self.ok(
            "Run keeps incomplete abort response open",
            self.command("k4-run", "project"),
            "--log", str(abort_log),
            "--output", str(open_projection),
            "--bind", f"goal={goal}",
            "--bind", f"plan={abort_plan}",
        )
        open_document = read_json(open_projection)["document"]
        if open_document["halted"] or open_document["execution_result"] is not None:
            raise AssertionError("incomplete Run was converted into a terminal state")
        self.passed += 1
        print("PASS incomplete Run remains open")
        self.append("Run abort response", abort_result(), abort_log, goal, abort_plan)
        legacy_halt_source = self.work / "legacy-blocked-halt.json"
        write_json(
            legacy_halt_source,
            {
                "kind": "halt",
                "after_operation_id": abort_operations[4],
                "trigger": "blocked",
                "budget_evidence_refs": [],
                "side_effect_evidence_refs": ["abort://residual"],
                "evidence_refs": ["abort://halt"],
                "resume_ref": None,
            },
        )
        self.refuse(
            "Run rejects legacy terminal state",
            self.command("k4-run", "append"),
            "--input", str(legacy_halt_source),
            "--log", str(abort_log),
            "--bind", f"goal={goal}",
            "--bind", f"plan={abort_plan}",
        )
        self.append(
            "Run abort halt",
            {
                "kind": "halt",
                "after_operation_id": abort_operations[4],
                "trigger": "abort",
                "budget_evidence_refs": ["abort://budget"],
                "side_effect_evidence_refs": ["abort://residual"],
                "evidence_refs": ["abort://halt"],
                "resume_ref": "resume://after-cancellation",
            },
            abort_log,
            goal,
            abort_plan,
        )
        abort_finish_input = json.loads(json.dumps(finish_input))
        abort_finish_input["cutoff"] = "after sourced abort"
        abort_finish_input["source_refs"] = [
            "asset://repo",
            "run://abort-ledger",
            "accept://abort",
            "terminal://abort",
            "abort://confirmation",
            "abort://halt",
            "abort://budget",
            "abort://residual",
        ]
        abort_finish_input["delta"] = {
            "summary": "the aborted attempt was settled without rewriting it as completion",
            "evidence_refs": ["run://abort-ledger"],
        }
        abort_finish_input["items"][0].update({
            "change_reason": "Run ended by sourced abort",
            "state": "gap",
            "statement": "the expected result remains incomplete after abort",
            "evidence_refs": ["run://abort-ledger"],
            "route": "none",
            "route_ref": None,
        })
        abort_finish_input["acceptance_results"][0].update({
            "result": "fail",
            "actual_refs": ["actual://absent-result"],
            "comparison_refs": ["comparison://abort-acceptance"],
            "evidence_refs": ["accept://abort"],
        })
        abort_finish_input["terminal_control_results"][0].update({
            "result": "pass",
            "actual_refs": ["actual://abort-budget"],
            "comparison_refs": ["comparison://abort-budget"],
            "evidence_refs": ["terminal://abort"],
        })
        abort_finish_input["result_disposition"] = {
            "state": "pending",
            "statement": "the incomplete result remains unadopted",
            "refs": ["actual://absent-result"],
        }
        abort_finish_input["incomplete_deliverable"] = {
            "statement": "the expected result was not completed",
            "refs": ["resume://after-cancellation"],
        }
        abort_finish = self.work / "abort-finish.json"
        self.materialize(
            "Finish abort settlement",
            "k4-finish",
            abort_finish_input,
            abort_finish,
            [("previous_account", observe0), ("goal", goal), ("plan", abort_plan)],
            run_log=abort_log,
        )
        abort_closure = read_json(abort_finish)["document"]["closure"]
        if (
            abort_closure["attempt_result"] != "fail"
            or abort_closure["run_halt"]["trigger"] != "abort"
            or abort_closure["run_halt"]["abort"]["response_mode"] != "route"
            or abort_closure["run_halt"]["abort"]["actual_response_operations"] != 1
        ):
            raise AssertionError("Finish did not preserve the abort and its frozen response")
        self.passed += 1
        print("PASS Finish preserves abort settlement")

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

        legacy = self.root / "tests" / "fixtures" / "0.4.1"
        migrated = self.work / "migrated-0.5.0"
        self.ok(
            "Migration rebuilds 0.4.1 chain",
            str(self.root / "tools" / "migrate-0.4.1-to-0.5.0"),
            "--observe", str(legacy / "observe0.json"),
            "--goal", str(legacy / "goal.json"),
            "--plan", str(legacy / "plan.json"),
            "--run-log", str(legacy / "run.jsonl"),
            "--finish", str(legacy / "finish.json"),
            "--policy", str(legacy / "policy.json"),
            "--output-dir", str(migrated),
        )
        report = read_json(migrated / "migration.json")
        expected_migrations = {
            "goal": ("k4-goal-document/v5", "k4-goal-document/v6"),
            "plan": ("k4-plan-document/v5", "k4-plan-document/v6"),
            "run": ("k4-run-event/v4", "k4-run-event/v5"),
            "finish": ("k4-finish-document/v2", "k4-finish-document/v3"),
        }
        for name, (source_schema, target_schema) in expected_migrations.items():
            entry = report["artifacts"][name]
            if (entry["from"], entry["to"]) != (source_schema, target_schema):
                raise AssertionError(f"migration report has wrong {name} schema transition")
            if entry["source_sha256"] == entry["target_sha256"]:
                raise AssertionError(f"migration report falsely preserved {name} file digest")
        self.passed += 1
        print("PASS Migration records explicit schema and digest transitions")

        legacy_050 = self.root / "tests" / "fixtures" / "0.5.0"
        migrated_060 = self.work / "migrated-0.6.0"
        self.ok(
            "Migration rebuilds 0.5.0 chain",
            str(self.root / "tools" / "migrate-0.5.0-to-0.6.0"),
            "--observe", str(legacy_050 / "observe0.json"),
            "--goal", str(legacy_050 / "goal.json"),
            "--plan", str(legacy_050 / "plan.json"),
            "--run-log", str(legacy_050 / "run.jsonl"),
            "--finish", str(legacy_050 / "finish.json"),
            "--policy", str(legacy_050 / "policy.json"),
            "--output-dir", str(migrated_060),
        )
        report_060 = read_json(migrated_060 / "migration.json")
        expected_060 = {
            "goal": ("k4-goal-document/v6", "k4-goal-document/v6"),
            "plan": ("k4-plan-document/v6", "k4-plan-document/v7"),
            "run": ("k4-run-event/v5", "k4-run-event/v6"),
            "finish": ("k4-finish-document/v3", "k4-finish-document/v4"),
        }
        for name, (source_schema, target_schema) in expected_060.items():
            entry = report_060["artifacts"][name]
            if (entry["from"], entry["to"]) != (source_schema, target_schema):
                raise AssertionError(f"0.6.0 migration report has wrong {name} schema transition")
            if name == "goal" and entry["source_sha256"] != entry["target_sha256"]:
                raise AssertionError("0.6.0 migration did not preserve Goal bytes")
            if name != "goal" and entry["source_sha256"] == entry["target_sha256"]:
                raise AssertionError(f"0.6.0 migration falsely preserved {name} file digest")
        self.passed += 1
        print("PASS 0.6.0 migration records exact schema and digest transitions")
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
