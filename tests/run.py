#!/usr/bin/env python3
"""Behavioral conformance tests for the K4 Goal and Plan Skills."""

from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
GOAL_TOOL = ROOT / "skills" / "k4-goal" / "scripts" / "goal_result.py"
PLAN_TOOL = ROOT / "skills" / "k4-plan" / "scripts" / "plan_result.py"
STAMP = "2026-09-08T12:00:00+08:00"


def write_json(path: Path, value: Any, *, canonical: bool = False) -> None:
    if canonical:
        data = json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    else:
        data = json.dumps(value, ensure_ascii=False) + "\n"
    path.write_text(data, encoding="utf-8")


def run(*args: object) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, *(str(arg) for arg in args)],
        check=False,
        capture_output=True,
        text=True,
    )


def expect_ok(label: str, result: subprocess.CompletedProcess[str]) -> None:
    if result.returncode != 0:
        raise AssertionError(f"{label}: expected success, got {result.stderr or result.stdout}")


def expect_fail(label: str, result: subprocess.CompletedProcess[str], fragment: str) -> None:
    if result.returncode == 0 or fragment not in result.stderr:
        raise AssertionError(
            f"{label}: expected failure containing {fragment!r}, "
            f"got rc={result.returncode} stderr={result.stderr!r} stdout={result.stdout!r}"
        )


def prediction_point() -> dict[str, Any]:
    return {
        "point_id": "result-visible",
        "mode": "prediction",
        "statement": "The requested stable result exists and passes its declared checks.",
        "required_evidence": ["actual result path", "independent check report"],
        "independence": "A checker distinct from the forming operation judges only declared checks.",
        "prediction": {
            "observable": "stable result and check outcome",
            "conditions": ["the exact frozen target is used"],
            "window": "after the target attempt and before adoption",
            "expected": "the result exists and every declared check passes",
            "falsifier": "the result is absent, differs in identity, or any declared check is non-pass",
            "result_contract_ref": "contract://goal-plan-tests/result-visible/v1",
            "comparison_method": "compare the actual result identity and checker report with this contract",
            "sampling_rule": "full census of the one result and all declared checks",
        },
        "control": None,
    }


def control_point() -> dict[str, Any]:
    return {
        "point_id": "boundary-preserved",
        "mode": "control",
        "statement": "The attempt stays inside the frozen write and publication boundary.",
        "required_evidence": ["operation trace", "exact repository diff"],
        "independence": "A deterministic diff check judges paths; authority claims remain external.",
        "prediction": None,
        "control": {
            "required_method": "write only through declared operations and compare the final diff",
            "allowed_variations": ["temporary files inside the declared temporary directory"],
            "forbidden_drift": ["write outside the declared target", "publish before validation"],
            "required_trace": ["operation invocation", "final exact diff"],
            "check_method": "mechanically compare observed paths and ordering with the frozen boundary",
            "on_non_pass": "stop, preserve trace and return an incomplete deliverable",
        },
    }


def goal_candidate() -> dict[str, Any]:
    return {
        "goal_id": "goal-plan-conformance",
        "version": "v1",
        "supersedes": None,
        "status": "frozen",
        "target": {
            "identity": "isolated goal-plan conformance fixture",
            "version_ref": "fixture-v1",
            "boundary": "temporary test directory only",
        },
        "desired_outcome": "One frozen Goal can be bound by one mechanically valid Plan.",
        "source_refs": ["source://system-theory/frozen-test-anchor"],
        "evidence_cutoff": {
            "at": "before observing this conformance attempt's actual result",
            "included_refs": ["source://system-theory/frozen-test-anchor"],
        },
        "baseline_refs": ["baseline://empty-test-directory"],
        "evidence_claims": [
            {
                "kind": "fact",
                "statement": "The test directory is isolated.",
                "source_ref": "baseline://empty-test-directory",
            }
        ],
        "scope": ["write temporary test artifacts"],
        "non_goals": ["prove semantic sufficiency mechanically"],
        "authorization": {
            "ref": "authorization://local-conformance-test",
            "scope": "temporary test directory",
            "claim_limit": "permits test writes but does not prove semantic correctness",
        },
        "control_envelope": {
            "budget": "one local test process",
            "resources": ["Python standard library"],
            "maximum_side_effects": ["files inside the temporary test directory"],
            "stop_conditions": {
                "completed": "all declared cases return their expected status",
                "paused": "a required local input becomes unavailable",
                "failed": "a case contradicts its expected status",
                "cancelled": "the caller cancels the process",
            },
            "incomplete_deliverable": "test name, tool output and temporary reproduction inputs",
        },
        "acceptance_points": [prediction_point(), control_point()],
        "unknowns": [],
    }


def operation(operation_id: str) -> dict[str, Any]:
    return {
        "operation_id": operation_id,
        "depends_on": [],
        "inputs": ["exact frozen Goal and test fixture"],
        "action": "run the bounded conformance operation",
        "outputs": ["actual result or control trace"],
        "responsible": "isolated test executor",
        "ability_refs": ["tool://python-standard-library"],
        "permission_refs": ["authorization://local-conformance-test"],
        "resources": ["temporary test directory"],
        "maximum_side_effects": ["files inside the temporary test directory"],
        "pre_checks": ["Goal digest and target identity still match"],
        "post_checks": ["declared output exists and is addressable"],
        "idempotency": "each attempt uses a new absent output path",
        "retry_limit": 0,
        "recovery": "preserve tool output and restart from the failed operation",
        "next": ["stop and deliver the point result"],
        "stop_conditions": ["operation returns success, Finding or unknown"],
    }


def plan_candidate() -> dict[str, Any]:
    return {
        "plan_id": "goal-plan-conformance-plan",
        "version": "v1",
        "supersedes": None,
        "status": "executable",
        "source_refs": ["source://system-theory/frozen-test-anchor"],
        "difference": "No frozen result or boundary trace exists in the isolated baseline.",
        "candidate_routes": [
            {
                "route_id": "bounded-local-run",
                "claim": "A bounded local run can produce both required point results.",
                "supporting_refs": ["tool://python-standard-library"],
                "counter_refs": [],
                "expected_effects": ["temporary result and trace files are created"],
                "rejected_reason": None,
            }
        ],
        "selected_route_id": "bounded-local-run",
        "nodes": [
            {
                "point_id": "boundary-preserved",
                "operations": [operation("control-run")],
                "result_destination": "state://attempt/boundary-preserved",
                "on_finding": "stop dependent work and preserve the trace",
                "on_unknown": "pause dependent work and state the missing evidence",
            },
            {
                "point_id": "result-visible",
                "operations": [operation("result-run")],
                "result_destination": "state://attempt/result-visible",
                "on_finding": "stop adoption and preserve the actual result",
                "on_unknown": "pause adoption and state the missing evidence",
            },
        ],
        "edges": [
            {
                "from_point_id": "boundary-preserved",
                "to_point_id": "result-visible",
                "reason": "The result attempt may run only after its write boundary is established.",
                "guards": ["authorization and target identity remain unchanged"],
                "on_non_pass": "do not run result-visible; deliver the control result",
            }
        ],
        "parallel_groups": [],
        "unknowns": [],
    }


def freeze_goal(work: Path, candidate: dict[str, Any], name: str = "goal") -> Path:
    source = work / f"{name}-candidate.json"
    result = work / f"{name}-result.json"
    write_json(source, candidate)
    completed = run(GOAL_TOOL, "freeze", "--candidate", source, "--output", result, "--frozen-at", STAMP)
    expect_ok(f"freeze {name}", completed)
    return result


def freeze_plan(work: Path, goal: Path, candidate: dict[str, Any], name: str = "plan") -> Path:
    source = work / f"{name}-candidate.json"
    result = work / f"{name}-result.json"
    write_json(source, candidate)
    completed = run(
        PLAN_TOOL,
        "freeze",
        "--goal",
        goal,
        "--candidate",
        source,
        "--output",
        result,
        "--frozen-at",
        STAMP,
    )
    expect_ok(f"freeze {name}", completed)
    return result


def main() -> int:
    cases = 0
    with tempfile.TemporaryDirectory(prefix="k4-goal-plan-test-") as raw:
        work = Path(raw)

        goal = freeze_goal(work, goal_candidate())
        expect_ok("validate Goal", run(GOAL_TOOL, "validate", "--result", goal))
        cases += 1

        invalid = goal_candidate()
        invalid["acceptance_points"][0]["control"] = control_point()["control"]
        source = work / "goal-both-contracts.json"
        write_json(source, invalid)
        expect_fail(
            "Goal rejects both contracts",
            run(GOAL_TOOL, "freeze", "--candidate", source, "--output", work / "never-1.json", "--frozen-at", STAMP),
            "must contain prediction only",
        )
        cases += 1

        for field in ("falsifier", "sampling_rule"):
            invalid = goal_candidate()
            invalid["acceptance_points"][0]["prediction"][field] = ""
            source = work / f"goal-missing-{field}.json"
            write_json(source, invalid)
            expect_fail(
                f"Goal requires prediction {field}",
                run(GOAL_TOOL, "freeze", "--candidate", source, "--output", work / f"never-{field}.json", "--frozen-at", STAMP),
                f"prediction.{field} must be a nonempty string",
            )
            cases += 1

        invalid = goal_candidate()
        invalid["acceptance_points"][1]["control"]["required_trace"] = []
        source = work / "goal-missing-trace.json"
        write_json(source, invalid)
        expect_fail(
            "Goal requires control trace",
            run(GOAL_TOOL, "freeze", "--candidate", source, "--output", work / "never-trace.json", "--frozen-at", STAMP),
            "required_trace must be a nonempty list",
        )
        cases += 1

        plan = freeze_plan(work, goal, plan_candidate())
        expect_ok("validate Plan", run(PLAN_TOOL, "validate", "--goal", goal, "--result", plan))
        cases += 1

        for label, mutation, fragment in (
            (
                "missing Goal point",
                lambda value: value["nodes"].pop(),
                "Plan point coverage differs",
            ),
            (
                "extra Goal point",
                lambda value: value["nodes"].append({**copy.deepcopy(value["nodes"][0]), "point_id": "extra"}),
                "Plan point coverage differs",
            ),
        ):
            invalid = plan_candidate()
            mutation(invalid)
            source = work / f"plan-{label.replace(' ', '-')}.json"
            write_json(source, invalid)
            expect_fail(
                f"Plan rejects {label}",
                run(PLAN_TOOL, "freeze", "--goal", goal, "--candidate", source, "--output", work / f"never-{cases}.json", "--frozen-at", STAMP),
                fragment,
            )
            cases += 1

        invalid = plan_candidate()
        invalid["edges"].append(
            {
                "from_point_id": "result-visible",
                "to_point_id": "boundary-preserved",
                "reason": "invalid reverse dependency",
                "guards": ["invalid cycle guard"],
                "on_non_pass": "stop",
            }
        )
        source = work / "plan-point-cycle.json"
        write_json(source, invalid)
        expect_fail(
            "Plan rejects point cycle",
            run(PLAN_TOOL, "freeze", "--goal", goal, "--candidate", source, "--output", work / "never-cycle.json", "--frozen-at", STAMP),
            "acceptance-point graph must be acyclic",
        )
        cases += 1

        invalid = plan_candidate()
        first = invalid["nodes"][0]["operations"][0]
        second = operation("control-check")
        first["depends_on"] = ["control-check"]
        second["depends_on"] = ["control-run"]
        invalid["nodes"][0]["operations"].append(second)
        source = work / "plan-operation-cycle.json"
        write_json(source, invalid)
        expect_fail(
            "Plan rejects operation cycle",
            run(PLAN_TOOL, "freeze", "--goal", goal, "--candidate", source, "--output", work / "never-op-cycle.json", "--frozen-at", STAMP),
            "operation graph must be acyclic",
        )
        cases += 1

        invalid = plan_candidate()
        invalid["goal_ref"] = "caller-authored"
        source = work / "plan-authored-binding.json"
        write_json(source, invalid)
        expect_fail(
            "Plan Candidate cannot author Goal binding",
            run(PLAN_TOOL, "freeze", "--goal", goal, "--candidate", source, "--output", work / "never-binding.json", "--frozen-at", STAMP),
            "must not author generated Goal binding fields",
        )
        cases += 1

        drifted_goal = work / "goal-result-drifted-bytes.json"
        parsed_goal = json.loads(goal.read_text(encoding="utf-8"))
        write_json(drifted_goal, parsed_goal, canonical=False)
        expect_fail(
            "Plan binding detects Goal byte drift",
            run(PLAN_TOOL, "validate", "--goal", drifted_goal, "--result", plan),
            "does not bind the supplied Goal exactly",
        )
        cases += 1

        fake_content = {
            "goal_id": "fake",
            "version": "v1",
            "status": "frozen",
            "acceptance_points": [{"point_id": "result-visible"}],
        }
        fake_goal = {
            "schema": "k4-goal-result/v1",
            "frozen_at": STAMP,
            "content_sha256": hashlib.sha256(
                (json.dumps(fake_content, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()
            ).hexdigest(),
            "content": fake_content,
        }
        fake_goal_path = work / "fake-goal.json"
        write_json(fake_goal_path, fake_goal, canonical=True)
        source = work / "plan-for-fake-goal.json"
        write_json(source, plan_candidate())
        expect_fail(
            "Plan requires Goal to pass its own validator",
            run(PLAN_TOOL, "freeze", "--goal", fake_goal_path, "--candidate", source, "--output", work / "never-fake.json", "--frozen-at", STAMP),
            "Goal failed its own validator",
        )
        cases += 1

    print(json.dumps({"ok": True, "cases": cases}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
