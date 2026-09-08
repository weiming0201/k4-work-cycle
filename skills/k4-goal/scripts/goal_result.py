#!/usr/bin/env python3
"""Freeze and validate canonical K4 Goal results using only the standard library."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

SCHEMA = "k4-goal-result/v1"
KINDS = {"fact", "source-statement", "inference", "preference", "unknown"}
STATUSES = {"frozen", "not-frozen", "unknown"}
POINT_MODES = {"prediction", "control"}
ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
RFC3339_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$")


class ContractError(ValueError):
    pass


def fail(message: str) -> None:
    raise ContractError(message)


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()


def digest(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def load_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"{label} is not readable JSON: {exc}")
    if not isinstance(value, dict):
        fail(f"{label} must be an object")
    return value


def exact_keys(value: dict[str, Any], required: set[str], label: str) -> None:
    missing = sorted(required - value.keys())
    extra = sorted(value.keys() - required)
    if missing or extra:
        fail(f"{label} keys differ: missing={missing} extra={extra}")


def text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        fail(f"{label} must be a nonempty string")
    return value


def nullable_text(value: Any, label: str) -> None:
    if value is not None:
        text(value, label)


def text_list(value: Any, label: str, *, nonempty: bool = False) -> list[str]:
    if not isinstance(value, list) or (nonempty and not value):
        fail(f"{label} must be {'a nonempty ' if nonempty else 'a '}list")
    for index, item in enumerate(value):
        text(item, f"{label}[{index}]")
    if len(value) != len(set(value)):
        fail(f"{label} must not contain duplicates")
    return value


def validate_content(content: dict[str, Any]) -> None:
    required = {
        "goal_id", "version", "supersedes", "status", "target",
        "desired_outcome", "source_refs", "evidence_cutoff", "baseline_refs",
        "evidence_claims", "scope", "non_goals", "authorization",
        "control_envelope", "acceptance_points", "unknowns",
    }
    exact_keys(content, required, "Goal content")
    goal_id = text(content["goal_id"], "goal_id")
    if not ID_RE.fullmatch(goal_id):
        fail("goal_id must be ref-safe")
    text(content["version"], "version")
    nullable_text(content["supersedes"], "supersedes")
    if content["status"] not in STATUSES:
        fail(f"status must be one of {sorted(STATUSES)}")

    target = content["target"]
    if not isinstance(target, dict):
        fail("target must be an object")
    exact_keys(target, {"identity", "version_ref", "boundary"}, "target")
    for key in target:
        text(target[key], f"target.{key}")
    text(content["desired_outcome"], "desired_outcome")
    text_list(content["source_refs"], "source_refs", nonempty=True)
    text_list(content["baseline_refs"], "baseline_refs", nonempty=True)
    text_list(content["scope"], "scope", nonempty=True)
    text_list(content["non_goals"], "non_goals")
    text_list(content["unknowns"], "unknowns")

    cutoff = content["evidence_cutoff"]
    if not isinstance(cutoff, dict):
        fail("evidence_cutoff must be an object")
    exact_keys(cutoff, {"at", "included_refs"}, "evidence_cutoff")
    text(cutoff["at"], "evidence_cutoff.at")
    text_list(cutoff["included_refs"], "evidence_cutoff.included_refs", nonempty=True)

    claims = content["evidence_claims"]
    if not isinstance(claims, list):
        fail("evidence_claims must be a list")
    for index, claim in enumerate(claims):
        if not isinstance(claim, dict):
            fail(f"evidence_claims[{index}] must be an object")
        exact_keys(claim, {"kind", "statement", "source_ref"}, f"evidence_claims[{index}]")
        if claim["kind"] not in KINDS:
            fail(f"evidence_claims[{index}].kind is invalid")
        text(claim["statement"], f"evidence_claims[{index}].statement")
        nullable_text(claim["source_ref"], f"evidence_claims[{index}].source_ref")

    authorization = content["authorization"]
    if not isinstance(authorization, dict):
        fail("authorization must be an object")
    exact_keys(authorization, {"ref", "scope", "claim_limit"}, "authorization")
    for key in authorization:
        text(authorization[key], f"authorization.{key}")

    envelope = content["control_envelope"]
    if not isinstance(envelope, dict):
        fail("control_envelope must be an object")
    exact_keys(
        envelope,
        {"budget", "resources", "maximum_side_effects", "stop_conditions", "incomplete_deliverable"},
        "control_envelope",
    )
    text(envelope["budget"], "control_envelope.budget")
    text_list(envelope["resources"], "control_envelope.resources", nonempty=True)
    text_list(envelope["maximum_side_effects"], "control_envelope.maximum_side_effects", nonempty=True)
    stops = envelope["stop_conditions"]
    if not isinstance(stops, dict):
        fail("control_envelope.stop_conditions must be an object")
    exact_keys(stops, {"completed", "paused", "failed", "cancelled"}, "stop_conditions")
    for key in stops:
        text(stops[key], f"stop_conditions.{key}")
    text(envelope["incomplete_deliverable"], "control_envelope.incomplete_deliverable")

    points = content["acceptance_points"]
    if not isinstance(points, list):
        fail("acceptance_points must be a list")
    if content["status"] == "frozen" and not points:
        fail("a frozen Goal must contain acceptance points")
    observed: set[str] = set()
    point_keys = {
        "point_id", "mode", "statement", "required_evidence", "independence",
        "prediction", "control",
    }
    prediction_keys = {
        "observable", "conditions", "window", "expected", "falsifier",
        "result_contract_ref", "comparison_method", "sampling_rule",
    }
    control_keys = {
        "required_method", "allowed_variations", "forbidden_drift",
        "required_trace", "check_method", "on_non_pass",
    }
    for index, point in enumerate(points):
        label = f"acceptance_points[{index}]"
        if not isinstance(point, dict):
            fail(f"{label} must be an object")
        exact_keys(point, point_keys, label)
        point_id = text(point["point_id"], f"{label}.point_id")
        if not ID_RE.fullmatch(point_id) or point_id in observed:
            fail(f"{label}.point_id must be unique and ref-safe")
        observed.add(point_id)
        mode = point["mode"]
        if mode not in POINT_MODES:
            fail(f"{label}.mode must be one of {sorted(POINT_MODES)}")
        text(point["statement"], f"{label}.statement")
        text_list(point["required_evidence"], f"{label}.required_evidence", nonempty=True)
        text(point["independence"], f"{label}.independence")
        if mode == "prediction":
            if point["control"] is not None or not isinstance(point["prediction"], dict):
                fail(f"{label} must contain prediction only")
            contract = point["prediction"]
            exact_keys(contract, prediction_keys, f"{label}.prediction")
            for key in prediction_keys - {"conditions"}:
                text(contract[key], f"{label}.prediction.{key}")
            text_list(contract["conditions"], f"{label}.prediction.conditions", nonempty=True)
        else:
            if point["prediction"] is not None or not isinstance(point["control"], dict):
                fail(f"{label} must contain control only")
            contract = point["control"]
            exact_keys(contract, control_keys, f"{label}.control")
            for key in control_keys - {"allowed_variations", "forbidden_drift", "required_trace"}:
                text(contract[key], f"{label}.control.{key}")
            text_list(contract["allowed_variations"], f"{label}.control.allowed_variations")
            text_list(contract["forbidden_drift"], f"{label}.control.forbidden_drift", nonempty=True)
            text_list(contract["required_trace"], f"{label}.control.required_trace", nonempty=True)


def validate_result(result: dict[str, Any]) -> None:
    exact_keys(result, {"schema", "frozen_at", "content_sha256", "content"}, "Goal result")
    if result["schema"] != SCHEMA:
        fail(f"schema must be {SCHEMA}")
    if not isinstance(result["frozen_at"], str) or not RFC3339_RE.fullmatch(result["frozen_at"]):
        fail("frozen_at must be RFC3339")
    if not isinstance(result["content"], dict):
        fail("content must be an object")
    validate_content(result["content"])
    actual = digest(result["content"])
    if result["content_sha256"] != actual:
        fail(f"content_sha256 mismatch: expected={actual} actual={result['content_sha256']}")


def freeze(candidate_path: Path, output_path: Path, frozen_at: str) -> dict[str, Any]:
    if output_path.exists():
        fail(f"output must be absent: {output_path}")
    if not RFC3339_RE.fullmatch(frozen_at):
        fail("--frozen-at must be RFC3339")
    content = load_object(candidate_path, "Goal Candidate")
    validate_content(content)
    result = {
        "schema": SCHEMA,
        "frozen_at": frozen_at,
        "content_sha256": digest(content),
        "content": content,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(canonical_bytes(result))
    return {"ok": True, "result": str(output_path), "content_sha256": result["content_sha256"]}


def main() -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    freeze_parser = commands.add_parser("freeze")
    freeze_parser.add_argument("--candidate", required=True, type=Path)
    freeze_parser.add_argument("--output", required=True, type=Path)
    freeze_parser.add_argument("--frozen-at", required=True)
    validate_parser = commands.add_parser("validate")
    validate_parser.add_argument("--result", required=True, type=Path)
    args = parser.parse_args()
    try:
        if args.command == "freeze":
            report = freeze(args.candidate, args.output, args.frozen_at)
        else:
            result = load_object(args.result, "Goal result")
            validate_result(result)
            report = {"ok": True, "result": str(args.result), "content_sha256": result["content_sha256"]}
        print(json.dumps(report, ensure_ascii=False, sort_keys=True))
        return 0
    except ContractError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False, sort_keys=True), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
