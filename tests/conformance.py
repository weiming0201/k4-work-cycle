#!/usr/bin/env python3
"""Established K4 Work Cycle complete path and refusal cases."""

from __future__ import annotations

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


class Harness:
    def __init__(self, extension: Path, work: Path) -> None:
        self.extension = extension
        self.work = work
        self.tool = extension / "tools" / "stable-result"
        self.align_script = extension / "skills" / "k4-align" / "scripts" / "materialize"
        self.goal_script = extension / "skills" / "k4-goal" / "scripts" / "materialize"
        self.plan_script = extension / "skills" / "k4-plan" / "scripts" / "materialize"
        self.run_append = extension / "skills" / "k4-run" / "scripts" / "append"
        self.run_project = extension / "skills" / "k4-run" / "scripts" / "project"
        self.contracts = {
            name: extension / "skills" / name / "assets" / "protocol.cue"
            for name in ("k4-align", "k4-goal", "k4-plan", "k4-run")
        }
        self.environment = dict(os.environ)
        self.environment["K4_STABLE_RESULT"] = str(self.tool)
        self.passed = 0

    def invoke(self, *words: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            words,
            cwd=self.extension,
            env=self.environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def expect_ok(self, label: str, *words: str) -> None:
        result = self.invoke(*words)
        if result.returncode != 0:
            raise AssertionError(
                f"{label}: expected success\nstdout={result.stdout}\nstderr={result.stderr}"
            )

    def expect_refusal(self, label: str, *words: str) -> None:
        result = self.invoke(*words)
        if result.returncode == 0:
            raise AssertionError(
                f"{label}: expected refusal\nstdout={result.stdout}\nstderr={result.stderr}"
            )
        self.passed += 1
        print(f"PASS refusal: {label}")

    def validate_document(
        self,
        protocol: str,
        document: Path,
        *binding_words: str,
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

    def operation(
        self,
        dependencies: list[int],
        point_id: str,
        control_id: str,
        tool_ref: str,
    ) -> dict[str, Any]:
        return {
            "depends_on_indices": dependencies,
            "satisfies": [point_id],
            "controlled_by": [control_id],
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

    def operation_event(self, operation_id: str, control_id: str) -> dict[str, Any]:
        return {
            "kind": "operation-result",
            "operation_id": operation_id,
            "result": "pass",
            "eligibility_refs": ["eligibility://pass"],
            "actual_output_refs": ["actual://fixture-output"],
            "evidence_refs": ["evidence://operation-pass"],
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

    def run(self) -> None:
        align_input = self.work / "align-input.json"
        align = self.work / "align.json"
        write_json(
            align_input,
            {
                "mode": "bootstrap",
                "subject": "isolated cycle fixture",
                "boundary": "only files inside the isolated fixture",
                "cutoff": "before this test run",
                "source_refs": ["source://fixture"],
                "delta": {
                    "summary": "the expected result is absent",
                    "evidence_refs": ["source://fixture"],
                },
                "items": [
                    {
                        "change": "added",
                        "previous_item_id": None,
                        "change_reason": "initial observation",
                        "state": "gap",
                        "statement": "the expected result does not yet exist",
                        "evidence_refs": ["source://fixture"],
                        "route": "goal-candidate",
                        "route_ref": None,
                    }
                ],
                "retired": [],
            },
        )
        self.expect_ok(
            "Align0",
            str(self.align_script),
            "--input",
            str(align_input),
            "--output",
            str(align),
            "--null-bind",
            "previous_align",
        )
        self.validate_document(
            "k4-align", align, "--null-bind", "previous_align"
        )
        item_id = read_json(align)["document"]["items"][0]["item_id"]

        goal_input = self.work / "goal-input.json"
        goal = self.work / "goal.json"
        write_json(
            goal_input,
            {
                "align_item_ids": [item_id],
                "objective": "produce one valid stable result inside the fixture",
                "target": "isolated cycle fixture v1",
                "source_refs": ["source://fixture"],
                "evidence_cutoff": {
                    "at": "before observing this test attempt",
                    "included_refs": ["source://fixture"],
                },
                "baseline_refs": ["baseline://fixture-empty"],
                "scope": ["create one result inside the fixture"],
                "non_goals": ["adopt or publish the result"],
                "execution_envelope": {
                    "authorization_ref": "authorization://isolated-test",
                    "authorization_scope": "create and validate files only inside the fixture",
                    "authorization_claim_limit": "permits fixture writes but does not prove semantic correctness",
                    "available_tools": ["tool://produce", "tool://validate"],
                    "resources": ["local process"],
                    "budget": "one bounded attempt",
                    "maximum_side_effects": ["files inside the fixture"],
                    "stop_conditions": {
                        "completed": "all acceptance and control judgments pass",
                        "paused": "evidence unavailable",
                        "failed": "a judgment has a Finding",
                        "cancelled": "caller cancels",
                    },
                    "incomplete_deliverable": "failed input, output, evidence, and resume command",
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
                            "window": "after execution and before adoption",
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
                        "check_method": "compare each write target with the boundary",
                        "check_timing": "invariant",
                        "on_non_pass": "stop and retain the trace",
                    }
                ],
                "blockers": [],
                "unknowns": [],
            },
        )
        self.expect_ok(
            "Goal",
            str(self.goal_script),
            "--input",
            str(goal_input),
            "--output",
            str(goal),
            "--bind",
            f"align={align}",
        )
        self.validate_document(
            "k4-goal", goal, "--bind", f"align={align}"
        )
        goal_value = read_json(goal)
        point_id = goal_value["document"]["acceptance_points"][0]["point_id"]
        control_id = goal_value["document"]["control_contracts"][0]["control_id"]

        plan_input = self.work / "plan-input.json"
        plan = self.work / "plan.json"
        write_json(
            plan_input,
            {
                "difference": "the expected result and its evidence are absent",
                "route": {
                    "claim": "produce and then validate one bounded result",
                    "supporting_refs": ["source://fixture"],
                    "counter_refs": [],
                },
                "operations": [
                    self.operation([], point_id, control_id, "tool://produce"),
                    self.operation([0], point_id, control_id, "tool://validate"),
                ],
                "parallel_groups": [],
                "blockers": [],
                "unknowns": [],
            },
        )
        self.expect_ok(
            "Plan",
            str(self.plan_script),
            "--input",
            str(plan_input),
            "--output",
            str(plan),
            "--bind",
            f"goal={goal}",
        )
        self.validate_document(
            "k4-plan", plan, "--bind", f"goal={goal}"
        )
        operation_ids = [
            operation["operation_id"]
            for operation in read_json(plan)["document"]["operations"]
        ]

        run = self.work / "run.jsonl"
        self.append_event(
            "Run operation 0",
            self.operation_event(operation_ids[0], control_id),
            self.work / "run-operation-0.json",
            run,
            goal,
            plan,
        )
        self.append_event(
            "Run operation 1",
            self.operation_event(operation_ids[1], control_id),
            self.work / "run-operation-1.json",
            run,
            goal,
            plan,
        )
        self.append_event(
            "Run acceptance",
            {
                "kind": "acceptance-result",
                "point_id": point_id,
                "result": "pass",
                "actual_refs": ["actual://fixture"],
                "comparison_refs": ["comparison://pass"],
                "evidence_refs": ["evidence://acceptance-pass"],
            },
            self.work / "run-acceptance.json",
            run,
            goal,
            plan,
        )
        self.append_event(
            "Run stop",
            {
                "kind": "stop",
                "stop_state": "completed",
                "budget_evidence_refs": ["budget://within"],
                "side_effect_evidence_refs": ["effects://within"],
                "evidence_refs": ["evidence://completed"],
                "resume_ref": None,
            },
            self.work / "run-stop.json",
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
        if read_json(projection)["document"]["result"] != "pass":
            raise AssertionError("complete Run projection did not pass")

        align1_input = self.work / "align1-input.json"
        align1 = self.work / "align1.json"
        write_json(
            align1_input,
            {
                "mode": "iterate",
                "subject": "isolated cycle fixture",
                "boundary": "only files inside the isolated fixture",
                "cutoff": "after Run projection",
                "source_refs": ["source://run-result"],
                "delta": {
                    "summary": "the bounded Run completed",
                    "evidence_refs": ["source://run-result"],
                },
                "items": [
                    {
                        "change": "changed",
                        "previous_item_id": item_id,
                        "change_reason": "Run produced the expected result",
                        "state": "aligned",
                        "statement": "the expected result now exists and validates",
                        "evidence_refs": ["source://run-result"],
                        "route": "none",
                        "route_ref": None,
                    }
                ],
                "retired": [],
            },
        )
        self.expect_ok(
            "Align1",
            str(self.align_script),
            "--input",
            str(align1_input),
            "--output",
            str(align1),
            "--bind",
            f"previous_align={align}",
        )
        self.validate_document(
            "k4-align", align1, "--bind", f"previous_align={align}"
        )
        self.passed += 1
        print("PASS complete cycle")

        self.expect_refusal(
            "occupied output",
            str(self.align_script),
            "--input",
            str(align_input),
            "--output",
            str(align),
            "--null-bind",
            "previous_align",
        )

        invalid_goal_input = self.work / "invalid-goal-input.json"
        invalid_goal = read_json(goal_input)
        invalid_goal["align_item_ids"] = ["item-0000000000000000"]
        write_json(invalid_goal_input, invalid_goal)
        self.expect_refusal(
            "unknown Align selection",
            str(self.goal_script),
            "--input",
            str(invalid_goal_input),
            "--output",
            str(self.work / "never-goal.json"),
            "--bind",
            f"align={align}",
        )

        uncovered_plan_input = self.work / "uncovered-plan-input.json"
        uncovered_plan = read_json(plan_input)
        for operation in uncovered_plan["operations"]:
            operation["controlled_by"] = []
        write_json(uncovered_plan_input, uncovered_plan)
        self.expect_refusal(
            "missing Goal control coverage",
            str(self.plan_script),
            "--input",
            str(uncovered_plan_input),
            "--output",
            str(self.work / "never-uncovered-plan.json"),
            "--bind",
            f"goal={goal}",
        )

        parallel_plan_input = self.work / "parallel-plan-input.json"
        parallel_plan = read_json(plan_input)
        parallel_plan["parallel_groups"] = [
            {
                "operation_indices": [0, 1],
                "reason": "invalid dependent parallelism",
                "guards": ["fixture only"],
            }
        ]
        write_json(parallel_plan_input, parallel_plan)
        self.expect_refusal(
            "unsafe parallel dependency",
            str(self.plan_script),
            "--input",
            str(parallel_plan_input),
            "--output",
            str(self.work / "never-parallel-plan.json"),
            "--bind",
            f"goal={goal}",
        )

        cyclic_plan = self.work / "cyclic-plan.json"
        cyclic = read_json(plan)
        cyclic["document"]["operations"][0]["depends_on"] = [operation_ids[1]]
        refresh_document_digest(cyclic)
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

        coverageless_plan = self.work / "coverageless-plan.json"
        coverageless = read_json(plan)
        coverageless["document"]["coverage"] = {
            "acceptance": [],
            "controls": [],
        }
        refresh_document_digest(coverageless)
        write_json(coverageless_plan, coverageless)
        self.append_event(
            "corrupted Plan coverage",
            self.operation_event(operation_ids[0], control_id),
            self.work / "coverageless-event.json",
            self.work / "never-coverageless-run.jsonl",
            goal,
            coverageless_plan,
            expect_success=False,
        )

        bypass = self.operation_event(operation_ids[1], control_id)
        self.append_event(
            "dependency bypass",
            bypass,
            self.work / "bypass-event.json",
            self.work / "never-bypass-run.jsonl",
            goal,
            plan,
            expect_success=False,
        )

        premature_log = self.work / "never-premature-run.jsonl"
        self.append_event(
            "premature setup operation",
            self.operation_event(operation_ids[0], control_id),
            self.work / "premature-operation.json",
            premature_log,
            goal,
            plan,
        )
        self.append_event(
            "premature acceptance",
            {
                "kind": "acceptance-result",
                "point_id": point_id,
                "result": "pass",
                "actual_refs": ["actual://fixture"],
                "comparison_refs": ["comparison://pass"],
                "evidence_refs": ["evidence://premature"],
            },
            self.work / "premature-acceptance.json",
            premature_log,
            goal,
            plan,
            expect_success=False,
        )

        unchecked = self.operation_event(operation_ids[0], control_id)
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

        incomplete_log = self.work / "never-incomplete-run.jsonl"
        self.append_event(
            "incomplete setup operation",
            self.operation_event(operation_ids[0], control_id),
            self.work / "incomplete-operation.json",
            incomplete_log,
            goal,
            plan,
        )
        self.append_event(
            "incomplete execution coverage",
            {
                "kind": "stop",
                "stop_state": "completed",
                "budget_evidence_refs": ["budget://within"],
                "side_effect_evidence_refs": ["effects://within"],
                "evidence_refs": ["evidence://incomplete"],
                "resume_ref": None,
            },
            self.work / "incomplete-stop.json",
            incomplete_log,
            goal,
            plan,
            expect_success=False,
        )

        missing_parent = self.work / "missing-parent"
        self.expect_refusal(
            "missing output parent",
            str(self.align_script),
            "--input",
            str(align_input),
            "--output",
            str(missing_parent / "never.json"),
            "--null-bind",
            "previous_align",
        )
        if missing_parent.exists():
            raise AssertionError("missing output parent was created")

        print(f"PASS {self.passed}/12 established cases")


def copy_extension(source: Path, target: Path) -> None:
    ignored = shutil.ignore_patterns(
        ".git",
        "__pycache__",
        "manifest.json",
    )
    shutil.copytree(source, target, ignore=ignored)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="k4-work-cycle-conformance-") as directory:
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
