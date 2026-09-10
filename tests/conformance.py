#!/usr/bin/env python3
"""Frozen K4 Work Cycle lifecycle and refusal meanings."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SKILL_NAMES = ("k4-observe", "k4-goal", "k4-plan", "k4-run", "k4-finish")


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")


def write_json(path: Path, value: Any) -> None:
    path.write_bytes(canonical_bytes(value))


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_bytes())


def refresh_document_digest(value: dict[str, Any]) -> None:
    value["content_sha256"] = hashlib.sha256(
        canonical_bytes(
            {"bindings": value["bindings"], "document": value["document"]}
        )
    ).hexdigest()


def published_files(root: Path) -> list[Path]:
    ignored_parts = {".git", "__pycache__"}
    files = []
    for path in root.rglob("*"):
        relative = path.relative_to(root)
        if not path.is_file() or any(part in ignored_parts for part in relative.parts):
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
        "k4-run": [
            "skills/k4-run/scripts/append",
            "skills/k4-run/scripts/project",
        ],
        "k4-finish": ["skills/k4-finish/scripts/materialize"],
    }
    return {
        "extension_id": "k4-work-cycle",
        "extension_version": "0.3.0",
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


def generate_manifest(root: Path) -> None:
    tool = root / "tools" / "stable-result"
    contract = root / "manifest.cue"
    with tempfile.TemporaryDirectory(
        prefix="k4-work-cycle-manifest-", dir=root.parent
    ) as directory:
        temporary = Path(directory)
        semantic_input = temporary / "manifest-input.json"
        candidate = temporary / "manifest.json"
        write_json(semantic_input, manifest_input(root))
        process = subprocess.run(
            [
                str(tool),
                "--contract",
                str(contract),
                "materialize",
                "--input",
                str(semantic_input),
                "--output",
                str(candidate),
            ],
            cwd=root,
            capture_output=True,
            text=True,
            check=False,
        )
        if process.returncode != 0:
            raise AssertionError(
                f"manifest generation failed\nstdout={process.stdout}\nstderr={process.stderr}"
            )
        os.replace(candidate, root / "manifest.json")


def validate_manifest(root: Path) -> None:
    value = read_json(root / "manifest.json")
    expected = manifest_input(root)
    if value["document"] != expected:
        raise AssertionError("manifest document does not match current published source")
    process = subprocess.run(
        [
            str(root / "tools" / "stable-result"),
            "--contract",
            str(root / "manifest.cue"),
            "validate",
            "--document",
            str(root / "manifest.json"),
        ],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    if process.returncode != 0:
        raise AssertionError(
            f"manifest validation failed\nstdout={process.stdout}\nstderr={process.stderr}"
        )


class Harness:
    def __init__(self, extension: Path, work: Path) -> None:
        self.extension = extension
        self.work = work
        self.tool = extension / "tools" / "stable-result"
        self.observe = extension / "skills" / "k4-observe" / "scripts" / "materialize"
        self.goal = extension / "skills" / "k4-goal" / "scripts" / "materialize"
        self.plan = extension / "skills" / "k4-plan" / "scripts" / "materialize"
        self.run_append = extension / "skills" / "k4-run" / "scripts" / "append"
        self.run_project = extension / "skills" / "k4-run" / "scripts" / "project"
        self.finish = extension / "skills" / "k4-finish" / "scripts" / "materialize"
        self.contracts = {
            name: extension / "skills" / name / "assets" / "protocol.cue"
            for name in SKILL_NAMES
        }
        self.environment = dict(os.environ)
        self.environment["K4_STABLE_RESULT"] = str(self.tool)
        self.passed: list[str] = []

    def invoke(self, *words: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            words,
            cwd=self.extension,
            env=self.environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def expect_ok(self, label: str, *words: str) -> subprocess.CompletedProcess[str]:
        result = self.invoke(*words)
        if result.returncode != 0:
            raise AssertionError(
                f"{label}: expected success\nstdout={result.stdout}\nstderr={result.stderr}"
            )
        return result

    def expect_refusal(
        self, label: str, *words: str, contains: tuple[str, ...] = ()
    ) -> None:
        result = self.invoke(*words)
        if result.returncode == 0:
            raise AssertionError(
                f"{label}: expected refusal\nstdout={result.stdout}\nstderr={result.stderr}"
            )
        combined = result.stdout + result.stderr
        missing = [needle for needle in contains if needle not in combined]
        if missing:
            raise AssertionError(
                f"{label}: refusal missing {missing!r}\nstdout={result.stdout}\nstderr={result.stderr}"
            )
        self.record(label)

    def record(self, label: str) -> None:
        self.passed.append(label)
        print(f"PASS {label}")

    def validate_document(
        self, protocol: str, document: Path, *binding_words: str
    ) -> None:
        self.expect_ok(
            f"validate {protocol}",
            str(self.tool),
            "--contract",
            str(self.contracts[protocol]),
            "validate",
            "--document",
            str(document),
            *binding_words,
        )

    def observe_input(
        self,
        *,
        mode: str,
        subject: str,
        boundary: str,
        source: str,
        statement: str,
        state: str,
        route: str,
        change: str,
        previous_item_id: str | None,
    ) -> dict[str, Any]:
        return {
            "mode": mode,
            "subject": subject,
            "boundary": boundary,
            "cutoff": f"cutoff for {source}",
            "source_refs": [source],
            "delta": {"summary": f"delta from {source}", "evidence_refs": [source]},
            "items": [
                {
                    "change": change,
                    "previous_item_id": previous_item_id,
                    "change_reason": f"{change} from {source}",
                    "epistemic_kind": "fact",
                    "state": state,
                    "statement": statement,
                    "evidence_refs": [source],
                    "route": route,
                    "route_ref": None,
                }
            ],
            "retired": [],
        }

    def materialize_observe(
        self,
        label: str,
        semantic: dict[str, Any],
        input_path: Path,
        output: Path,
        previous: Path | None = None,
    ) -> None:
        write_json(input_path, semantic)
        binding = (
            ("--null-bind", "previous_account")
            if previous is None
            else ("--bind", f"previous_account={previous}")
        )
        self.expect_ok(
            label,
            str(self.observe),
            "--input",
            str(input_path),
            "--output",
            str(output),
            *binding,
        )
        self.validate_document("k4-observe", output, *binding)

    def operation(
        self,
        dependencies: list[int],
        point_id: str,
        control_ids: list[str],
        tool_ref: str,
    ) -> dict[str, Any]:
        return {
            "depends_on_indices": dependencies,
            "satisfies": [point_id],
            "controlled_by": control_ids,
            "tool_ref": tool_ref,
            "responsible_ref": "executor://isolated-test",
            "read_refs": ["input://fixture"],
            "write_refs": ["output://fixture"],
            "permission_refs": ["authorization://isolated-test"],
            "resource_refs": ["resource://local-process"],
            "maximum_side_effects": ["files inside the fixture"],
            "pre_checks": ["dependencies and boundary still pass"],
            "post_checks": ["declared output is addressable"],
            "idempotency": "every attempt uses an absent output path",
            "retry_limit": 0,
            "recovery": "retain evidence and resume at this operation",
        }

    def invariant_check(self, control_id: str) -> dict[str, Any]:
        return {
            "control_id": control_id,
            "result": "pass",
            "actual_refs": ["actual://write-targets"],
            "trace_refs": ["trace://operation"],
            "comparison_refs": ["comparison://inside-boundary"],
            "evidence_refs": ["evidence://control-pass"],
        }

    def operation_event(
        self, operation_id: str, control_id: str, result: str = "pass"
    ) -> dict[str, Any]:
        return {
            "kind": "operation-result",
            "operation_id": operation_id,
            "result": result,
            "eligibility_refs": ["eligibility://checked"],
            "actual_output_refs": (
                ["actual://fixture-output"] if result == "pass" else []
            ),
            "evidence_refs": [f"evidence://operation-{result}"],
            "trace_refs": ["trace://operation"],
            "invariant_checks": [self.invariant_check(control_id)],
            "deferred_issues": [],
        }

    def append_event(
        self,
        label: str,
        event: dict[str, Any],
        input_path: Path,
        log: Path,
        goal: Path,
        plan: Path,
        expect_success: bool = True,
    ) -> None:
        write_json(input_path, event)
        command = (
            str(self.run_append),
            "--input",
            str(input_path),
            "--log",
            str(log),
            "--bind",
            f"goal={goal}",
            "--bind",
            f"plan={plan}",
        )
        if expect_success:
            self.expect_ok(label, *command)
        else:
            self.expect_refusal(label, *command)

    def materialize_finish(
        self,
        label: str,
        semantic: dict[str, Any],
        input_path: Path,
        output: Path,
        previous: Path,
        goal: Path,
        plan: Path,
        run_projection: Path,
        expect_success: bool = True,
    ) -> None:
        write_json(input_path, semantic)
        command = (
            str(self.finish),
            "--input",
            str(input_path),
            "--output",
            str(output),
            "--bind",
            f"previous_account={previous}",
            "--bind",
            f"goal={goal}",
            "--bind",
            f"plan={plan}",
            "--bind",
            f"run={run_projection}",
        )
        if expect_success:
            self.expect_ok(label, *command)
            self.validate_document(
                "k4-finish",
                output,
                "--bind",
                f"previous_account={previous}",
                "--bind",
                f"goal={goal}",
                "--bind",
                f"plan={plan}",
                "--bind",
                f"run={run_projection}",
            )
        else:
            self.expect_refusal(label, *command)

    def finish_input(
        self,
        *,
        item_id: str,
        point_id: str,
        terminal_control_id: str,
        run_projection: Path,
        terminal_state: str,
        acceptance_result: str,
        terminal_result: str,
    ) -> dict[str, Any]:
        completed = terminal_state == "completed"
        projection = read_json(run_projection)["document"]
        sources = [
            "evidence://run",
            "evidence://acceptance",
            "evidence://terminal-control",
        ]
        return {
            "subject": "isolated cycle fixture",
            "boundary": "only files inside the isolated fixture",
            "cutoff": "after halted Run",
            "source_refs": sources,
            "delta": {
                "summary": "the bounded attempt halted and was judged",
                "evidence_refs": ["evidence://run"],
            },
            "items": [
                {
                    "change": "changed",
                    "previous_item_id": item_id,
                    "change_reason": "the attempted route produced terminal evidence",
                    "epistemic_kind": "fact",
                    "state": "aligned" if completed else "gap",
                    "statement": (
                        "the expected result exists and validates"
                        if completed
                        else "the expected result remains incomplete"
                    ),
                    "evidence_refs": ["evidence://run"],
                    "route": "none",
                    "route_ref": None,
                }
            ],
            "retired": [],
            "acceptance_results": [
                {
                    "id": point_id,
                    "result": acceptance_result,
                    "actual_refs": ["actual://acceptance"],
                    "comparison_refs": ["comparison://acceptance"],
                    "evidence_refs": ["evidence://acceptance"],
                }
            ],
            "terminal_control_results": [
                {
                    "id": terminal_control_id,
                    "result": terminal_result,
                    "actual_refs": ["actual://terminal-control"],
                    "comparison_refs": ["comparison://terminal-control"],
                    "evidence_refs": ["evidence://terminal-control"],
                }
            ],
            "terminal_state": terminal_state,
            "result_disposition": {
                "state": "placed" if completed else "pending",
                "statement": (
                    "result remains inside the fixture"
                    if completed
                    else "partial result remains inside the fixture"
                ),
                "refs": ["actual://fixture-output"],
            },
            "incomplete_deliverable": (
                None
                if completed
                else {
                    "statement": "retain partial result and failed operation evidence",
                    "refs": ["actual://fixture-output", "evidence://run"],
                }
            ),
            "resume_ref": None if completed else "resume://failed-operation",
            "run_log_ref": "run://fixture-ledger",
            "run_head_event_sha256": projection["ledger_head_event_sha256"],
        }

    def run(self) -> None:
        subject = "isolated cycle fixture"
        boundary = "only files inside the isolated fixture"
        observe_input = self.work / "observe-input.json"
        observe0 = self.work / "observe0.json"
        initial = self.observe_input(
            mode="bootstrap",
            subject=subject,
            boundary=boundary,
            source="source://fixture",
            statement="the expected result does not yet exist",
            state="gap",
            route="goal-candidate",
            change="added",
            previous_item_id=None,
        )
        self.materialize_observe(
            "Observe0", initial, observe_input, observe0
        )
        item_id = read_json(observe0)["document"]["account"]["items"][0]["item_id"]

        observe_same_input = self.work / "observe-same-input.json"
        observe_same = self.work / "observe-same.json"
        same = self.observe_input(
            mode="iterate",
            subject=subject,
            boundary=boundary,
            source="source://same-boundary",
            statement="the expected result is still absent",
            state="gap",
            route="goal-candidate",
            change="changed",
            previous_item_id=item_id,
        )
        self.materialize_observe(
            "Observe same subject",
            same,
            observe_same_input,
            observe_same,
            observe0,
        )
        self.record("same-subject Observe iteration")

        goal_input = self.work / "goal-input.json"
        goal = self.work / "goal.json"
        write_json(
            goal_input,
            {
                "observe_item_ids": [item_id],
                "objective": "produce one valid stable result inside the fixture",
                "target": "isolated cycle fixture v1",
                "source_refs": ["source://fixture"],
                "evidence_cutoff": {
                    "at": "before observing this attempt",
                    "included_refs": ["source://fixture"],
                },
                "baseline_refs": ["baseline://fixture-empty"],
                "scope": ["create one result inside the fixture"],
                "non_goals": ["adopt or publish by implication"],
                "execution_envelope": {
                    "authorization_ref": "authorization://isolated-test",
                    "authorization_scope": "fixture files only",
                    "authorization_claim_limit": "no semantic correctness claim",
                    "available_tools": ["tool://produce", "tool://validate"],
                    "resources": ["local process"],
                    "budget": "one bounded attempt",
                    "maximum_side_effects": ["files inside the fixture"],
                    "stop_conditions": {
                        "completed": "Finish finds all criteria passed",
                        "paused": "evidence unavailable",
                        "failed": "a criterion has a Finding",
                        "cancelled": "caller cancels",
                    },
                    "incomplete_deliverable": "partial output, evidence, and resume point",
                },
                "acceptance_points": [
                    {
                        "statement": "the expected stable result exists",
                        "required_evidence": ["actual result and checker output"],
                        "judge": {
                            "kind": "script",
                            "claim_limit": "declared file checks only",
                        },
                        "acceptance": {
                            "observable": "result path and validator status",
                            "conditions": ["the frozen fixture is used"],
                            "window": "after Run halt and before adoption",
                            "expected": "the result exists and validates",
                            "falsifier": "the result is absent or invalid",
                            "comparison_method": "compare exact path and validator output",
                            "sampling_rule": "full census",
                        },
                    }
                ],
                "control_contracts": [
                    {
                        "statement": "writes remain inside the fixture",
                        "required_evidence": ["operation trace and path check"],
                        "judge": {
                            "kind": "script",
                            "claim_limit": "declared paths only",
                        },
                        "controlled_variable": "write target",
                        "allowed_domain": ["the isolated fixture"],
                        "forbidden_drift": ["write outside the fixture"],
                        "required_trace": ["invocation trace"],
                        "check_method": "compare every write with the boundary",
                        "check_timing": "invariant",
                        "on_non_pass": "halt and retain the trace",
                    },
                    {
                        "statement": "terminal resource use remains within budget",
                        "required_evidence": ["terminal budget comparison"],
                        "judge": {
                            "kind": "script",
                            "claim_limit": "declared budget only",
                        },
                        "controlled_variable": "terminal resource use",
                        "allowed_domain": ["the frozen bounded attempt"],
                        "forbidden_drift": ["unbounded resource use"],
                        "required_trace": ["terminal resource trace"],
                        "check_method": "compare actual use with the frozen budget",
                        "check_timing": "terminal",
                        "on_non_pass": "Finish as non-completed",
                    },
                ],
                "blockers": [],
                "unknowns": [],
            },
        )
        self.expect_ok(
            "Goal",
            str(self.goal),
            "--input",
            str(goal_input),
            "--output",
            str(goal),
            "--bind",
            f"observe={observe0}",
        )
        self.validate_document(
            "k4-goal", goal, "--bind", f"observe={observe0}"
        )
        goal_value = read_json(goal)["document"]
        point_id = goal_value["acceptance_points"][0]["point_id"]
        invariant_id = goal_value["control_contracts"][0]["control_id"]
        terminal_id = goal_value["control_contracts"][1]["control_id"]

        plan_input = self.work / "plan-input.json"
        plan = self.work / "plan.json"
        write_json(
            plan_input,
            {
                "difference": "the result and evidence are absent",
                "route": {
                    "claim": "produce then validate one bounded result",
                    "supporting_refs": ["source://fixture"],
                    "counter_refs": [],
                },
                "operations": [
                    self.operation(
                        [], point_id, [invariant_id, terminal_id], "tool://produce"
                    ),
                    self.operation(
                        [0], point_id, [invariant_id, terminal_id], "tool://validate"
                    ),
                ],
                "parallel_groups": [],
                "blockers": [],
                "unknowns": [],
            },
        )
        self.expect_ok(
            "Plan",
            str(self.plan),
            "--input",
            str(plan_input),
            "--output",
            str(plan),
            "--bind",
            f"goal={goal}",
        )
        self.validate_document("k4-plan", plan, "--bind", f"goal={goal}")
        operation_ids = [
            item["operation_id"] for item in read_json(plan)["document"]["operations"]
        ]

        run = self.work / "run.jsonl"
        for index, operation_id in enumerate(operation_ids):
            self.append_event(
                f"Run operation {index}",
                self.operation_event(operation_id, invariant_id),
                self.work / f"run-operation-{index}.json",
                run,
                goal,
                plan,
            )
        self.append_event(
            "Run halt",
            {
                "kind": "halt",
                "after_operation_id": operation_ids[-1],
                "next_operation_id": None,
                "trigger": "route-exhausted",
                "budget_evidence_refs": ["budget://observed"],
                "side_effect_evidence_refs": ["effects://observed"],
                "evidence_refs": ["evidence://halt"],
                "resume_ref": None,
            },
            self.work / "run-halt.json",
            run,
            goal,
            plan,
        )
        projection = self.work / "run-projection.json"
        self.expect_ok(
            "Run projection",
            str(self.run_project),
            "--log",
            str(run),
            "--output",
            str(projection),
            "--bind",
            f"goal={goal}",
            "--bind",
            f"plan={plan}",
        )
        projection_document = read_json(projection)["document"]
        if (
            projection_document["execution_result"] != "pass"
            or not projection_document["halted"]
            or "acceptance_results" in projection_document
            or "control_results" in projection_document
        ):
            raise AssertionError("Run projection is not execution-only")

        finish_input = self.work / "finish-input.json"
        finish = self.work / "finish.json"
        completed = self.finish_input(
            item_id=item_id,
            point_id=point_id,
            terminal_control_id=terminal_id,
            run_projection=projection,
            terminal_state="completed",
            acceptance_result="pass",
            terminal_result="pass",
        )
        self.materialize_finish(
            "Finish completed",
            completed,
            finish_input,
            finish,
            observe0,
            goal,
            plan,
            projection,
        )
        self.record("complete Observe-Goal-Plan-Run-Finish cycle")

        finish_item_id = read_json(finish)["document"]["account"]["items"][0]["item_id"]
        post_finish_input = self.work / "post-finish-observe-input.json"
        post_finish = self.work / "post-finish-observe.json"
        post = self.observe_input(
            mode="iterate",
            subject=subject,
            boundary=boundary,
            source="source://post-finish",
            statement="the finished result remains observable",
            state="aligned",
            route="goal-candidate",
            change="changed",
            previous_item_id=finish_item_id,
        )
        self.materialize_observe(
            "Observe after Finish",
            post,
            post_finish_input,
            post_finish,
            finish,
        )
        self.record("Finish-to-Observe continuation")

        early_run = self.work / "early-run.jsonl"
        self.append_event(
            "early non-pass operation",
            self.operation_event(operation_ids[0], invariant_id, "Finding"),
            self.work / "early-operation.json",
            early_run,
            goal,
            plan,
        )
        self.append_event(
            "early halt",
            {
                "kind": "halt",
                "after_operation_id": operation_ids[0],
                "next_operation_id": operation_ids[0],
                "trigger": "operation-non-pass",
                "budget_evidence_refs": ["budget://observed"],
                "side_effect_evidence_refs": ["effects://observed"],
                "evidence_refs": ["evidence://early-halt"],
                "resume_ref": "resume://failed-operation",
            },
            self.work / "early-halt.json",
            early_run,
            goal,
            plan,
        )
        early_projection = self.work / "early-projection.json"
        self.expect_ok(
            "early Run projection",
            str(self.run_project),
            "--log",
            str(early_run),
            "--output",
            str(early_projection),
            "--bind",
            f"goal={goal}",
            "--bind",
            f"plan={plan}",
        )
        early_finish_input = self.finish_input(
            item_id=item_id,
            point_id=point_id,
            terminal_control_id=terminal_id,
            run_projection=early_projection,
            terminal_state="failed",
            acceptance_result="unknown",
            terminal_result="unknown",
        )
        early_finish = self.work / "early-finish.json"
        self.materialize_finish(
            "Finish early non-pass",
            early_finish_input,
            self.work / "early-finish-input.json",
            early_finish,
            observe0,
            goal,
            plan,
            early_projection,
        )
        self.record("truthful early/non-pass Finish")

        self.expect_refusal(
            "occupied output",
            str(self.observe),
            "--input",
            str(observe_input),
            "--output",
            str(observe0),
            "--null-bind",
            "previous_account",
        )

        invalid_goal = json.loads(json.dumps(read_json(goal_input)))
        invalid_goal["observe_item_ids"] = ["item-0000000000000000"]
        invalid_goal_input = self.work / "invalid-goal-input.json"
        write_json(invalid_goal_input, invalid_goal)
        self.expect_refusal(
            "unknown Observe selection",
            str(self.goal),
            "--input",
            str(invalid_goal_input),
            "--output",
            str(self.work / "never-goal.json"),
            "--bind",
            f"observe={observe0}",
        )

        uncovered = json.loads(json.dumps(read_json(plan_input)))
        for operation in uncovered["operations"]:
            operation["controlled_by"] = [invariant_id]
        uncovered_input = self.work / "uncovered-plan-input.json"
        write_json(uncovered_input, uncovered)
        self.expect_refusal(
            "missing Goal control coverage",
            str(self.plan),
            "--input",
            str(uncovered_input),
            "--output",
            str(self.work / "never-uncovered-plan.json"),
            "--bind",
            f"goal={goal}",
        )

        parallel = json.loads(json.dumps(read_json(plan_input)))
        parallel["parallel_groups"] = [
            {
                "operation_indices": [0, 1],
                "reason": "invalid dependent parallelism",
                "guards": ["fixture only"],
            }
        ]
        parallel_input = self.work / "parallel-plan-input.json"
        write_json(parallel_input, parallel)
        self.expect_refusal(
            "unsafe parallel dependency",
            str(self.plan),
            "--input",
            str(parallel_input),
            "--output",
            str(self.work / "never-parallel-plan.json"),
            "--bind",
            f"goal={goal}",
        )

        cyclic = read_json(plan)
        cyclic["document"]["operations"][0]["depends_on"] = [operation_ids[1]]
        refresh_document_digest(cyclic)
        cyclic_plan = self.work / "cyclic-plan.json"
        write_json(cyclic_plan, cyclic)
        self.expect_refusal(
            "cyclic Plan",
            str(self.tool),
            "--contract",
            str(self.contracts["k4-plan"]),
            "validate",
            "--document",
            str(cyclic_plan),
            "--bind",
            f"goal={goal}",
        )

        coverageless = read_json(plan)
        coverageless["document"]["coverage"]["controls"] = []
        refresh_document_digest(coverageless)
        coverageless_plan = self.work / "coverageless-plan.json"
        write_json(coverageless_plan, coverageless)
        self.append_event(
            "corrupted Plan coverage",
            self.operation_event(operation_ids[0], invariant_id),
            self.work / "coverageless-event.json",
            self.work / "never-coverageless-run.jsonl",
            goal,
            coverageless_plan,
            expect_success=False,
        )

        self.append_event(
            "dependency bypass",
            self.operation_event(operation_ids[1], invariant_id),
            self.work / "bypass-event.json",
            self.work / "never-bypass-run.jsonl",
            goal,
            plan,
            expect_success=False,
        )

        unchecked = self.operation_event(operation_ids[0], invariant_id)
        unchecked["invariant_checks"] = []
        self.append_event(
            "unchecked invariant",
            unchecked,
            self.work / "unchecked-event.json",
            self.work / "never-unchecked-run.jsonl",
            goal,
            plan,
            expect_success=False,
        )

        subject_drift = json.loads(json.dumps(same))
        subject_drift["subject"] = "different subject"
        subject_drift_input = self.work / "subject-drift-input.json"
        write_json(subject_drift_input, subject_drift)
        self.expect_refusal(
            "actionable subject drift",
            str(self.observe),
            "--input",
            str(subject_drift_input),
            "--output",
            str(self.work / "never-subject-drift.json"),
            "--bind",
            f"previous_account={observe0}",
            contains=("subject", "previous Account", "bootstrap"),
        )

        boundary_drift = json.loads(json.dumps(same))
        boundary_drift["boundary"] = "different boundary"
        boundary_drift_input = self.work / "boundary-drift-input.json"
        write_json(boundary_drift_input, boundary_drift)
        self.expect_refusal(
            "actionable boundary drift",
            str(self.observe),
            "--input",
            str(boundary_drift_input),
            "--output",
            str(self.work / "never-boundary-drift.json"),
            "--bind",
            f"previous_account={observe0}",
            contains=("boundary", "previous Account", "bootstrap"),
        )

        premature = self.finish_input(
            item_id=item_id,
            point_id=point_id,
            terminal_control_id=terminal_id,
            run_projection=early_projection,
            terminal_state="completed",
            acceptance_result="pass",
            terminal_result="pass",
        )
        self.materialize_finish(
            "premature acceptance",
            premature,
            self.work / "premature-finish-input.json",
            self.work / "never-premature-finish.json",
            observe0,
            goal,
            plan,
            early_projection,
            expect_success=False,
        )

        incomplete = json.loads(json.dumps(premature))
        incomplete["acceptance_results"][0]["result"] = "unknown"
        self.materialize_finish(
            "incomplete execution coverage",
            incomplete,
            self.work / "incomplete-finish-input.json",
            self.work / "never-incomplete-finish.json",
            observe0,
            goal,
            plan,
            early_projection,
            expect_success=False,
        )

        missing_parent = self.work / "missing-parent"
        self.expect_refusal(
            "missing output parent",
            str(self.observe),
            "--input",
            str(observe_input),
            "--output",
            str(missing_parent / "never.json"),
            "--null-bind",
            "previous_account",
        )
        if missing_parent.exists():
            raise AssertionError("missing output parent was created")

        print(f"PASS {len(self.passed)}/17 frozen cases")


def copy_extension(source: Path, target: Path) -> None:
    ignored = shutil.ignore_patterns(".git", "__pycache__", "manifest.json")
    shutil.copytree(source, target, ignore=ignored)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--write-manifest",
        action="store_true",
        help="mechanically regenerate manifest.json from current published files",
    )
    args = parser.parse_args()
    if args.write_manifest:
        generate_manifest(ROOT)
        validate_manifest(ROOT)
        print("PASS generated manifest")
        return 0

    validate_manifest(ROOT)
    with tempfile.TemporaryDirectory(
        prefix="k4-work-cycle-conformance-"
    ) as directory:
        root = Path(directory)
        extension = root / "extension"
        work = root / "work"
        copy_extension(ROOT, extension)
        work.mkdir()
        Harness(extension, work).run()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL {error}", file=sys.stderr)
        raise SystemExit(1)
