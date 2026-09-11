#!/usr/bin/env python3
"""Oracle for minimizing caller input without changing stable stage semantics."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import tempfile

from conformance import Harness, ROOT, invoke, read_json, write_json


def stable_document(value: dict) -> dict:
    return {
        "schema": value["schema"],
        "bindings": value["bindings"],
        "document": value["document"],
    }


def run_materializer(skill: str, source: Path, output: Path, bindings: list[tuple[str, Path]], run_log: Path | None = None):
    words = [str(ROOT / "skills" / skill / "scripts" / "materialize"), "--input", str(source), "--output", str(output)]
    for name, path in bindings:
        words.extend(("--bind", f"{name}={path}"))
    if run_log is not None:
        words.extend(("--run-log", str(run_log)))
    return invoke(*words, cwd=ROOT)


def assert_refused(label: str, result) -> None:
    if result.returncode == 0:
        raise AssertionError(f"{label}: minimized input unexpectedly succeeded on the 0.7.0 baseline")
    print(f"PASS baseline refuses {label}")


def assert_rejected(label: str, result) -> None:
    if result.returncode == 0:
        raise AssertionError(f"{label}: contradictory explicit value was accepted")
    print(f"PASS rejects {label}")


def assert_rejected_paths(label: str, result, output: Path, expected_paths: set[str]) -> None:
    if result.returncode == 0 or output.exists():
        raise AssertionError(f"{label}: invalid semantic input produced stable output")
    try:
        diagnostic = json.loads(result.stderr)
    except json.JSONDecodeError as error:
        raise AssertionError(f"{label}: diagnostic is not structured JSON\n{result.stderr}") from error
    actual_paths = {entry.split(":", 1)[0] for entry in diagnostic.get("errors", [])}
    missing = expected_paths - actual_paths
    if missing:
        raise AssertionError(f"{label}: diagnostic omitted field paths {sorted(missing)}\n{result.stderr}")
    print(f"PASS rejects {label} at {sorted(expected_paths)}")


def assert_append_rejected_paths(label: str, result, log: Path, before: bytes, expected_paths: set[str]) -> None:
    if result.returncode == 0 or log.read_bytes() != before:
        raise AssertionError(f"{label}: invalid semantic input changed the stable ledger")
    try:
        diagnostic = json.loads(result.stderr)
    except json.JSONDecodeError as error:
        raise AssertionError(f"{label}: diagnostic is not structured JSON\n{result.stderr}") from error
    actual_paths = {entry.split(":", 1)[0] for entry in diagnostic.get("errors", [])}
    missing = expected_paths - actual_paths
    if missing:
        raise AssertionError(f"{label}: diagnostic omitted field paths {sorted(missing)}\n{result.stderr}")
    print(f"PASS rejects {label} at {sorted(expected_paths)}")


def assert_equivalent(label: str, result, candidate: Path, baseline: Path) -> None:
    if result.returncode != 0:
        raise AssertionError(f"{label}: minimized input failed\n{result.stdout}{result.stderr}")
    if stable_document(read_json(candidate)) != stable_document(read_json(baseline)):
        raise AssertionError(f"{label}: stable schema, bindings, or document changed")
    print(f"PASS equivalent {label}")


def stable_event(value: dict) -> dict:
    result = copy.deepcopy(value)
    for field in ("recorded_unix_ms", "event_sha256", "previous_event_sha256"):
        result.pop(field, None)
    return result


def semantic_item(item: dict) -> dict:
    value = {key: item[key] for key in ("lens", "epistemic_kind", "state", "statement", "evidence_refs", "route")}
    if item["route"] == "external":
        value["route_ref"] = item["route_ref"]
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--expect-baseline-refusal", action="store_true")
    parser.add_argument("--through", choices=("goal", "plan", "run", "finish"), default="finish")
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="k4-input-oracle-") as directory:
        work = Path(directory)
        Harness(ROOT, work).run()

        goal_full = work / "goal.json"
        goal_input = read_json(work / "Goal-input.json")
        for field in ("non_goals", "control_contracts", "blockers", "unknowns"):
            goal_input[field] = []
        goal_explicit_source = work / "goal-explicit-defaults-input.json"
        goal_oracle_full = work / "goal-explicit-defaults.json"
        write_json(goal_explicit_source, goal_input)
        goal_explicit_result = run_materializer(
            "k4-goal", goal_explicit_source, goal_oracle_full, [("observe", work / "observe0.json")]
        )
        if goal_explicit_result.returncode != 0:
            raise AssertionError(f"Goal oracle setup failed\n{goal_explicit_result.stdout}{goal_explicit_result.stderr}")
        for field in ("source_refs", "non_goals", "control_contracts", "blockers", "unknowns"):
            goal_input.pop(field)
        goal_source = work / "goal-minimal-input.json"
        goal_candidate = work / "goal-minimal.json"
        write_json(goal_source, goal_input)
        goal_result = run_materializer("k4-goal", goal_source, goal_candidate, [("observe", work / "observe0.json")])

        plan_full = work / "plan.json"
        plan_input = read_json(work / "Plan-input.json")
        plan_input["blockers"] = []
        plan_input["unknowns"] = []
        plan_explicit_source = work / "plan-explicit-defaults-input.json"
        plan_oracle_full = work / "plan-explicit-defaults.json"
        write_json(plan_explicit_source, plan_input)
        plan_explicit_result = run_materializer("k4-plan", plan_explicit_source, plan_oracle_full, [("goal", goal_full)])
        if plan_explicit_result.returncode != 0:
            raise AssertionError(f"Plan oracle setup failed\n{plan_explicit_result.stdout}{plan_explicit_result.stderr}")
        plan_input.pop("entry_operation_indices")
        plan_input.pop("blockers")
        plan_input.pop("unknowns")
        for operation in plan_input["operations"]:
            operation.pop("phase")
            operation.pop("depends_on_indices")
        plan_source = work / "plan-minimal-input.json"
        plan_candidate = work / "plan-minimal.json"
        write_json(plan_source, plan_input)
        plan_result = run_materializer("k4-plan", plan_source, plan_candidate, [("goal", goal_full)])

        run_goal = work / "zero-control-goal.json"
        run_plan = work / "zero-control-plan.json"
        run_baseline_log = work / "zero-patch-run.jsonl"
        run_log = work / "run-minimal.jsonl"
        prepare_result = invoke(
            str(ROOT / "skills" / "k4-run" / "scripts" / "append"),
            "--input", str(work / "Run-with-zero-controls.json"),
            "--log", str(run_log),
            "--bind", f"goal={run_goal}",
            "--bind", f"plan={run_plan}",
            cwd=ROOT,
        )
        if prepare_result.returncode != 0:
            raise AssertionError(f"Run oracle setup failed\n{prepare_result.stdout}{prepare_result.stderr}")
        run_event = read_json(work / "Run-zero-patch-halt.json")
        for field in ("after_operation_id", "trigger", "budget_evidence_refs", "side_effect_evidence_refs", "resume_ref"):
            run_event.pop(field)
        run_source = work / "run-minimal-halt-input.json"
        write_json(run_source, run_event)
        run_result = invoke(
            str(ROOT / "skills" / "k4-run" / "scripts" / "append"),
            "--input", str(run_source),
            "--log", str(run_log),
            "--bind", f"goal={run_goal}",
            "--bind", f"plan={run_plan}",
            cwd=ROOT,
        )

        finish_full = work / "finish.json"
        finish_input = read_json(work / "Finish-input.json")
        for item in finish_input["items"]:
            if item["change"] == "retained":
                item["change_reason"] = "Unmentioned by the closing semantic delta; prior item retained."
        finish_explicit_source = work / "finish-explicit-derived-input.json"
        finish_oracle_full = work / "finish-explicit-derived.json"
        write_json(finish_explicit_source, finish_input)
        finish_explicit_result = run_materializer(
            "k4-finish",
            finish_explicit_source,
            finish_oracle_full,
            [("previous_account", work / "observe0.json"), ("goal", goal_full), ("plan", plan_full)],
            work / "run.jsonl",
        )
        if finish_explicit_result.returncode != 0:
            raise AssertionError(f"Finish oracle setup failed\n{finish_explicit_result.stdout}{finish_explicit_result.stderr}")
        finish_minimal = {
            "cutoff": finish_input["cutoff"],
            "delta": finish_input["delta"],
            "updates": [
                {
                    "previous_item_id": item["previous_item_id"],
                    "reason": item["change_reason"],
                    "item": semantic_item(item),
                }
                for item in finish_input["items"]
                if item["change"] == "changed"
            ],
            "additions": [
                {"reason": item["change_reason"], "item": semantic_item(item)}
                for item in finish_input["items"]
                if item["change"] == "added"
            ],
            "retirements": copy.deepcopy(finish_input["retired"]),
            "acceptance_results": [
                {key: value for key, value in result.items() if key != "judge_ref"}
                for result in finish_input["acceptance_results"]
            ],
            "terminal_control_results": [
                {key: value for key, value in result.items() if key != "judge_ref"}
                for result in finish_input["terminal_control_results"]
            ],
            "result_disposition": finish_input["result_disposition"],
        }
        if finish_input["incomplete_deliverable"] is not None:
            finish_minimal["incomplete_deliverable"] = finish_input["incomplete_deliverable"]
        finish_source = work / "finish-minimal-input.json"
        finish_candidate = work / "finish-minimal.json"
        write_json(finish_source, finish_minimal)
        finish_result = run_materializer(
            "k4-finish",
            finish_source,
            finish_candidate,
            [("previous_account", work / "observe0.json"), ("goal", goal_full), ("plan", plan_full)],
            work / "run.jsonl",
        )

        cases = (
            ("Goal derived/default fields", goal_result, goal_candidate, goal_oracle_full),
            ("Plan graph-derived/default fields", plan_result, plan_candidate, plan_oracle_full),
            ("Run derived halt/default fields", run_result, run_log, run_baseline_log),
            ("Finish closing delta", finish_result, finish_candidate, finish_oracle_full),
        )
        if args.expect_baseline_refusal:
            for label, result, _, _ in cases:
                assert_refused(label, result)
            print("PASS input-minimality oracle is armed")
            return 0

        assert_equivalent("Goal derived/default fields", goal_result, goal_candidate, goal_oracle_full)
        if args.through == "goal":
            print("PASS input-minimality oracle through Goal")
            return 0
        assert_equivalent("Plan graph-derived/default fields", plan_result, plan_candidate, plan_oracle_full)
        if args.through == "plan":
            print("PASS input-minimality oracle through Plan")
            return 0
        if run_result.returncode != 0:
            raise AssertionError(f"Run derived halt/default fields: minimized input failed\n{run_result.stdout}{run_result.stderr}")
        candidate_event = json.loads(run_log.read_text().splitlines()[1])
        baseline_event = json.loads(run_baseline_log.read_text().splitlines()[1])
        for event in (candidate_event, baseline_event):
            event.pop("recorded_unix_ms", None)
            event.pop("event_sha256", None)
            event.pop("previous_event_sha256", None)
        if candidate_event != baseline_event:
            raise AssertionError("Run derived halt/default fields: stable event semantics changed")
        print("PASS equivalent Run derived halt/default fields")
        if args.through == "run":
            print("PASS input-minimality oracle through Run")
            return 0
        assert_equivalent("Finish closing delta", finish_result, finish_candidate, finish_oracle_full)

        finish_bindings = [("previous_account", work / "observe0.json"), ("goal", goal_full), ("plan", plan_full)]

        def finish_case(label: str, value: dict, output_name: str):
            source = work / f"{output_name}-input.json"
            output = work / f"{output_name}.json"
            write_json(source, value)
            result = run_materializer("k4-finish", source, output, finish_bindings, work / "run.jsonl")
            return result, output

        duplicate_update = copy.deepcopy(finish_minimal)
        duplicate_update["updates"].append(copy.deepcopy(duplicate_update["updates"][0]))
        result, output = finish_case("Finish duplicate updates", duplicate_update, "never-finish-duplicate-update")
        assert_rejected_paths(
            "Finish duplicate updates",
            result,
            output,
            {"input.updates[0].previous_item_id", "input.updates[1].previous_item_id"},
        )

        overlapping_delta = copy.deepcopy(finish_minimal)
        overlapping_delta["retirements"].append({
            "previous_item_id": overlapping_delta["updates"][0]["previous_item_id"],
            "reason": "the same predecessor cannot also be retired",
            "evidence_refs": ["run://ledger"],
        })
        result, output = finish_case("Finish update-retirement overlap", overlapping_delta, "never-finish-overlap")
        assert_rejected_paths(
            "Finish update-retirement overlap",
            result,
            output,
            {"input.updates[0].previous_item_id", "input.retirements[0].previous_item_id"},
        )

        unknown_update = copy.deepcopy(finish_minimal)
        unknown_update["updates"].append({
            "previous_item_id": "item-not-in-opening-account",
            "reason": "challenge an unknown predecessor",
            "item": copy.deepcopy(unknown_update["updates"][0]["item"]),
        })
        result, output = finish_case("Finish unknown update predecessor", unknown_update, "never-finish-unknown-update")
        assert_rejected_paths(
            "Finish unknown update predecessor",
            result,
            output,
            {"input.updates[1].previous_item_id"},
        )

        combined_delta = copy.deepcopy(overlapping_delta)
        combined_delta["updates"].append(copy.deepcopy(combined_delta["updates"][0]))
        combined_delta["updates"].append({
            "previous_item_id": "item-not-in-opening-account",
            "reason": "challenge an unknown predecessor in the combined case",
            "item": copy.deepcopy(combined_delta["updates"][0]["item"]),
        })
        result, output = finish_case("Finish combined delta errors", combined_delta, "never-finish-combined-errors")
        assert_rejected_paths(
            "Finish combined delta errors",
            result,
            output,
            {
                "input.updates[0].previous_item_id",
                "input.updates[1].previous_item_id",
                "input.updates[2].previous_item_id",
                "input.retirements[0].previous_item_id",
            },
        )

        def assert_finish_round_trip(label: str, semantic: dict, output_name: str, goal: Path, plan: Path, log: Path) -> None:
            bindings = [("previous_account", work / "observe0.json"), ("goal", goal), ("plan", plan)]
            source = work / f"{output_name}-minimal-input.json"
            candidate = work / f"{output_name}-minimal.json"
            write_json(source, semantic)
            result = run_materializer("k4-finish", source, candidate, bindings, log)
            if result.returncode != 0:
                raise AssertionError(f"{label}: valid semantic delta failed\n{result.stdout}{result.stderr}")
            document = read_json(candidate)["document"]
            full = {
                "subject": document["account"]["subject"],
                "boundary": document["account"]["boundary"],
                "cutoff": document["account"]["cutoff"],
                "source_refs": document["account"]["source_refs"],
                "lenses": document["account"]["lenses"],
                "delta": document["account"]["delta"],
                "items": [
                    {key: value for key, value in item.items() if key != "item_id"}
                    for item in document["account"]["items"]
                ],
                "retired": document["account"]["retired"],
                "acceptance_results": document["closure"]["acceptance_results"],
                "terminal_control_results": document["closure"]["terminal_control_results"],
                "result_disposition": document["closure"]["result_disposition"],
                "incomplete_deliverable": document["closure"]["incomplete_deliverable"],
            }
            full_source = work / f"{output_name}-full-input.json"
            baseline = work / f"{output_name}-full.json"
            write_json(full_source, full)
            full_result = run_materializer("k4-finish", full_source, baseline, bindings, log)
            assert_equivalent(label, full_result, baseline, candidate)

        valid_addition = copy.deepcopy(finish_minimal)
        valid_addition["additions"] = [{
            "reason": "record one new bounded observation",
            "item": {
                "lens": "delivery",
                "epistemic_kind": "fact",
                "state": "aligned",
                "statement": "one new observation was preserved",
                "evidence_refs": ["run://ledger"],
                "route": "none",
            },
        }]
        assert_finish_round_trip("Finish valid addition", valid_addition, "finish-valid-addition", goal_full, plan_full, work / "run.jsonl")

        valid_retirement = copy.deepcopy(finish_minimal)
        valid_retirement["retirements"] = [{
            "previous_item_id": read_json(work / "observe0.json")["document"]["account"]["items"][1]["item_id"],
            "reason": "retire the untouched structure observation",
            "evidence_refs": ["run://ledger"],
        }]
        valid_retirement["additions"] = [{
            "reason": "replace the retired structure observation",
            "item": {
                "lens": "structure",
                "epistemic_kind": "source-statement",
                "state": "aligned",
                "statement": "the replacement structure observation is addressable",
                "evidence_refs": ["run://ledger"],
                "route": "retain",
            },
        }]
        assert_finish_round_trip("Finish valid retirement", valid_retirement, "finish-valid-retirement", goal_full, plan_full, work / "run.jsonl")

        zero_finish_full = read_json(work / "Finish-with-zero-controls-and-patches-input.json")
        zero_finish_minimal = {
            "cutoff": zero_finish_full["cutoff"],
            "delta": zero_finish_full["delta"],
            "updates": [
                {
                    "previous_item_id": item["previous_item_id"],
                    "reason": item["change_reason"],
                    "item": semantic_item(item),
                }
                for item in zero_finish_full["items"]
                if item["change"] == "changed"
            ],
            "additions": [],
            "retirements": copy.deepcopy(zero_finish_full["retired"]),
            "acceptance_results": [
                {key: value for key, value in result.items() if key != "judge_ref"}
                for result in zero_finish_full["acceptance_results"]
            ],
            "result_disposition": zero_finish_full["result_disposition"],
        }
        zero_omitted = work / "finish-zero-controls-omitted.json"
        zero_source = work / "finish-zero-controls-omitted-input.json"
        write_json(zero_source, zero_finish_minimal)
        zero_explicit_input = copy.deepcopy(zero_finish_minimal)
        zero_explicit_input["terminal_control_results"] = []
        zero_explicit_source = work / "finish-zero-controls-explicit-input.json"
        zero_explicit = work / "finish-zero-controls-explicit.json"
        write_json(zero_explicit_source, zero_explicit_input)
        zero_explicit_result = run_materializer(
            "k4-finish",
            zero_explicit_source,
            zero_explicit,
            [("previous_account", work / "observe0.json"), ("goal", work / "zero-control-goal.json"), ("plan", work / "zero-control-plan.json")],
            work / "zero-patch-run.jsonl",
        )
        if zero_explicit_result.returncode != 0:
            raise AssertionError(f"Finish explicit zero controls setup failed\n{zero_explicit_result.stdout}{zero_explicit_result.stderr}")
        zero_result = run_materializer(
            "k4-finish",
            zero_source,
            zero_omitted,
            [("previous_account", work / "observe0.json"), ("goal", work / "zero-control-goal.json"), ("plan", work / "zero-control-plan.json")],
            work / "zero-patch-run.jsonl",
        )
        assert_equivalent("Finish omitted zero terminal controls", zero_result, zero_omitted, zero_explicit)

        missing_required_controls = copy.deepcopy(finish_minimal)
        missing_required_controls.pop("terminal_control_results")
        result, output = finish_case("Finish omitted required terminal controls", missing_required_controls, "never-finish-missing-controls")
        assert_rejected_paths(
            "Finish omitted required terminal controls",
            result,
            output,
            {"input.terminal_control_results"},
        )

        patch_full = read_json(work / "Run-emergency-patch.json")
        patch_baseline = json.loads((work / "run.jsonl").read_text().splitlines()[1])

        def patch_case(label: str, value: dict, suffix: str):
            log = work / f"patch-{suffix}.jsonl"
            prepare = invoke(
                str(ROOT / "skills" / "k4-run" / "scripts" / "append"),
                "--input", str(work / "Run-prepare.json"),
                "--log", str(log),
                "--bind", f"goal={goal_full}",
                "--bind", f"plan={plan_full}",
                cwd=ROOT,
            )
            if prepare.returncode != 0:
                raise AssertionError(f"{label}: patch setup failed\n{prepare.stdout}{prepare.stderr}")
            source = work / f"patch-{suffix}-input.json"
            write_json(source, value)
            before = log.read_bytes()
            result = invoke(
                str(ROOT / "skills" / "k4-run" / "scripts" / "append"),
                "--input", str(source),
                "--log", str(log),
                "--bind", f"goal={goal_full}",
                "--bind", f"plan={plan_full}",
                cwd=ROOT,
            )
            return result, log, before

        patch_without_findings = copy.deepcopy(patch_full)
        patch_without_findings.pop("findings")
        result, log, before = patch_case("Run patch omitted Findings", patch_without_findings, "omitted-findings")
        assert_append_rejected_paths("Run patch omitted Findings", result, log, before, {"input.findings"})

        patch_empty_findings = copy.deepcopy(patch_full)
        patch_empty_findings["findings"] = []
        result, log, before = patch_case("Run patch empty Findings", patch_empty_findings, "empty-findings")
        assert_append_rejected_paths("Run patch empty Findings", result, log, before, {"input.findings"})

        patch_valid = copy.deepcopy(patch_full)
        for field in ("attempt", "verification_scope"):
            patch_valid.pop(field)
        result, log, _ = patch_case("Run valid patch", patch_valid, "valid")
        if result.returncode != 0:
            raise AssertionError(f"Run valid patch failed\n{result.stdout}{result.stderr}")
        if stable_event(json.loads(log.read_text().splitlines()[1])) != stable_event(patch_baseline):
            raise AssertionError("Run valid patch stable event semantics changed")
        print("PASS equivalent Run valid patch")

        finish_help = invoke(str(ROOT / "skills" / "k4-finish" / "scripts" / "materialize"), "--help", cwd=ROOT)
        required_help_fragments = (
            "updates[]: {previous_item_id, reason, item}",
            "additions[]: {reason, item}",
            "retirements[]: {previous_item_id, reason, evidence_refs}",
            "item: {lens, epistemic_kind, state, statement, evidence_refs, route, route_ref?}",
            "route_ref is required only when route is external",
            "goal-candidate is not valid in a closing Finish Account",
        )
        missing_help = [fragment for fragment in required_help_fragments if fragment not in finish_help.stdout]
        if finish_help.returncode != 0 or missing_help:
            raise AssertionError(f"Finish help omitted semantic boundary {missing_help}")
        print("PASS Finish help exposes item and routing boundary")

        valid_external = copy.deepcopy(finish_minimal)
        valid_external["additions"] = [{
            "reason": "record one external follow-up",
            "item": {
                "lens": "delivery",
                "epistemic_kind": "fact",
                "state": "unknown",
                "statement": "one external follow-up remains",
                "evidence_refs": ["run://ledger"],
                "route": "external",
                "route_ref": "external://follow-up",
            },
        }]
        assert_finish_round_trip("Finish valid external addition", valid_external, "finish-valid-external", goal_full, plan_full, work / "run.jsonl")

        valid_external_update = copy.deepcopy(finish_minimal)
        valid_external_update["updates"][0]["item"]["route"] = "external"
        valid_external_update["updates"][0]["item"]["route_ref"] = "external://follow-up"
        assert_finish_round_trip("Finish valid external update", valid_external_update, "finish-valid-external-update", goal_full, plan_full, work / "run.jsonl")

        invalid_routes = []
        non_external_ref = copy.deepcopy(finish_minimal)
        non_external_ref["additions"] = copy.deepcopy(valid_addition["additions"])
        non_external_ref["additions"][0]["item"]["route_ref"] = "external://forbidden"
        invalid_routes.append(("Finish non-external route_ref", non_external_ref, "never-finish-nonexternal-ref", {"input.additions[0].item.route_ref"}))
        missing_external_ref = copy.deepcopy(valid_external)
        missing_external_ref["additions"][0]["item"].pop("route_ref")
        invalid_routes.append(("Finish missing external route_ref", missing_external_ref, "never-finish-missing-external-ref", {"input.additions[0].item.route_ref"}))
        goal_candidate = copy.deepcopy(valid_addition)
        goal_candidate["additions"][0]["item"]["route"] = "goal-candidate"
        invalid_routes.append(("Finish goal-candidate route", goal_candidate, "never-finish-goal-candidate", {"input.additions[0].item.route"}))
        goal_candidate_update = copy.deepcopy(finish_minimal)
        goal_candidate_update["updates"][0]["item"]["route"] = "goal-candidate"
        invalid_routes.append(("Finish goal-candidate update route", goal_candidate_update, "never-finish-goal-candidate-update", {"input.updates[0].item.route"}))
        for label, value, output_name, paths in invalid_routes:
            result, output = finish_case(label, value, output_name)
            assert_rejected_paths(label, result, output, paths)

        bad_goal = copy.deepcopy(goal_input)
        bad_goal["source_refs"] = ["source://contradiction"]
        bad_goal_source = work / "goal-contradictory-derived-input.json"
        write_json(bad_goal_source, bad_goal)
        assert_rejected(
            "Goal contradictory source closure",
            run_materializer("k4-goal", bad_goal_source, work / "never-bad-goal.json", [("observe", work / "observe0.json")]),
        )

        bad_plan = copy.deepcopy(plan_input)
        bad_plan["operations"][0]["phase"] = "abort"
        bad_plan_source = work / "plan-contradictory-phase-input.json"
        write_json(bad_plan_source, bad_plan)
        assert_rejected(
            "Plan contradictory derived phase",
            run_materializer("k4-plan", bad_plan_source, work / "never-bad-plan.json", [("goal", goal_full)]),
        )

        bad_run_log = work / "run-contradictory.jsonl"
        bad_run_setup = invoke(
            str(ROOT / "skills" / "k4-run" / "scripts" / "append"),
            "--input", str(work / "Run-with-zero-controls.json"),
            "--log", str(bad_run_log),
            "--bind", f"goal={run_goal}",
            "--bind", f"plan={run_plan}",
            cwd=ROOT,
        )
        if bad_run_setup.returncode != 0:
            raise AssertionError(f"Run contradiction setup failed\n{bad_run_setup.stdout}{bad_run_setup.stderr}")
        bad_run = read_json(work / "Run-zero-patch-halt.json")
        bad_run["trigger"] = "abort"
        bad_run_source = work / "run-contradictory-trigger-input.json"
        write_json(bad_run_source, bad_run)
        assert_rejected(
            "Run contradictory derived trigger",
            invoke(
                str(ROOT / "skills" / "k4-run" / "scripts" / "append"),
                "--input", str(bad_run_source),
                "--log", str(bad_run_log),
                "--bind", f"goal={run_goal}",
                "--bind", f"plan={run_plan}",
                cwd=ROOT,
            ),
        )

        bad_finish = copy.deepcopy(finish_minimal)
        bad_finish["acceptance_results"][0]["judge_ref"] = "tool://contradictory-judge"
        bad_finish_source = work / "finish-contradictory-judge-input.json"
        write_json(bad_finish_source, bad_finish)
        assert_rejected(
            "Finish contradictory derived judge",
            run_materializer(
                "k4-finish",
                bad_finish_source,
                work / "never-bad-finish.json",
                [("previous_account", work / "observe0.json"), ("goal", goal_full), ("plan", plan_full)],
                work / "run.jsonl",
            ),
        )
        print("PASS input-minimality oracle")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL {error}", file=__import__("sys").stderr)
        raise SystemExit(1)
