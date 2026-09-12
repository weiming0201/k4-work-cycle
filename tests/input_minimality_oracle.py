#!/usr/bin/env python3
"""Check that callers provide semantics while deterministic fields are derived."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile

from conformance import Harness, ROOT, invoke, read_json, write_json


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def refuse_materialize(skill: str, value: dict, output: Path, bindings: list[tuple[str, Path]], run_log: Path | None = None) -> None:
    source = output.with_suffix(".input.json")
    write_json(source, value)
    words = [str(ROOT / "skills" / skill / "scripts" / "materialize"), "--input", str(source), "--output", str(output)]
    if run_log is not None:
        words.extend(("--run-log", str(run_log)))
    for name, path in bindings:
        words.extend(("--bind", f"{name}={path}"))
    result = invoke(*words, cwd=ROOT)
    require(result.returncode != 0 and not output.exists(), f"{skill} accepted caller-owned derived fields")


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="k4-input-oracle-") as directory:
        work = Path(directory)
        Harness(ROOT, work).run()

        observe_input = read_json(work / "Observe-bootstrap-input.json")
        observe = read_json(work / "observe0.json")
        require("evidence_refs" not in observe_input["delta"], "Observe caller still maintains delta evidence")
        require(observe["document"]["account"]["delta"]["evidence_refs"] == ["asset://repo"], "Observe did not derive delta evidence")
        require(all(name in observe["document"]["observation"] for name in ("gap_ids", "conflict_ids", "unknown_ids", "completeness")), "Observe omitted derived successor indexes or completeness")
        print("PASS Observe semantic delta and derived observation surface")

        goal_input = read_json(work / "Goal-input.json")
        goal = read_json(work / "goal.json")
        require("source_refs" not in goal_input and "source_refs" in goal["document"], "Goal source closure is not Tool-owned")
        require(all(name in goal["document"] for name in ("decision_basis", "change_surface", "boundary_feasibility")), "Goal omitted launch-decision evidence")
        bad_goal = copy.deepcopy(goal_input)
        bad_goal["source_refs"] = ["caller://source"]
        refuse_materialize("k4-goal", bad_goal, work / "never-goal.json", [("observe", work / "observe0.json")])
        print("PASS Goal semantic decision and derived source closure")

        plan_input = read_json(work / "Plan-input.json")
        plan = read_json(work / "plan.json")
        require("entry_operation_indices" not in plan_input, "Plan caller still maintains graph roots")
        require(all("phase" not in operation and "depends_on_indices" not in operation for operation in plan_input["operations"]), "Plan caller still maintains graph projections")
        require(all("local_judgment" in operation and "failure_handling" in operation for operation in plan["document"]["operations"]), "Plan stable operations omit local audit or failure handling")
        bad_plan = copy.deepcopy(plan_input)
        bad_plan["operations"][0]["phase"] = "abort"
        refuse_materialize("k4-plan", bad_plan, work / "never-plan.json", [("goal", work / "goal.json")])
        print("PASS Plan semantic policy and derived graph projections")

        run_input = read_json(work / "Run-prepare.json")
        first_event = json.loads((work / "run.jsonl").read_text().splitlines()[0])
        require("eligibility_refs" not in run_input, "Run caller still maintains eligibility")
        require("local_judgment_contract" not in run_input, "Run caller still copies the Plan judgment contract")
        require(len(first_event["event"]["eligibility_refs"]) == 2 and "local_judgment_contract" in first_event["event"], "Run did not derive eligibility and local judgment")
        bad_run = copy.deepcopy(run_input)
        bad_run["eligibility_refs"] = ["caller://eligibility"]
        source = work / "bad-run.input.json"
        log = work / "bad-run.jsonl"
        write_json(source, bad_run)
        result = invoke(
            str(ROOT / "skills/k4-run/scripts/append"), "--input", str(source), "--log", str(log),
            "--bind", f"goal={work / 'goal.json'}", "--bind", f"plan={work / 'plan.json'}", cwd=ROOT,
        )
        require(result.returncode != 0 and (not log.exists() or log.read_bytes() == b""), "Run accepted caller-owned eligibility")
        print("PASS Run actual facts and derived Plan context")

        finish_input = read_json(work / "Finish-input.json")
        finish = read_json(work / "finish.json")
        require("source_refs" not in finish_input and "items" not in finish_input, "Finish caller still maintains formatted Account closure")
        require("comparison_refs" not in finish_input["acceptance_results"][0], "Finish caller still supplies its comparison scale")
        require(finish["document"]["account"]["source_refs"] == ["run://ledger", "asset://repo"], "Finish Account source closure was not derived")
        require("accept://result" in finish["document"]["closure"]["closure_source_refs"], "Finish closure sources were not separated")
        require("comparison_contract" in finish["document"]["closure"]["acceptance_results"][0], "Finish did not project the Goal comparison contract")
        bad_finish = copy.deepcopy(finish_input)
        bad_finish["source_refs"] = ["caller://source"]
        refuse_materialize(
            "k4-finish", bad_finish, work / "never-finish.json",
            [("previous_account", work / "observe0.json"), ("goal", work / "goal.json"), ("plan", work / "plan.json")],
            work / "run.jsonl",
        )
        print("PASS Finish semantic settlement and split derived source closures")

    print("PASS input-minimality oracle")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL {error}", file=__import__("sys").stderr)
        raise SystemExit(1)
