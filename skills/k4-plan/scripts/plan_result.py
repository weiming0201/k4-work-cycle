#!/usr/bin/env python3
"""Freeze and validate K4 Plans against one exact frozen Goal."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path
from typing import Any

SCHEMA = "k4-plan-result/v1"
GOAL_SCHEMA = "k4-goal-result/v1"
STATUSES = {"executable", "not-executable", "unknown"}
ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
RFC3339_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$")


class ContractError(ValueError):
    pass


def fail(message: str) -> None:
    raise ContractError(message)


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()


def digest_value(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def digest_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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


def load_goal_validator(path: Path) -> Any:
    if not path.is_file():
        fail(f"Goal validator is not a file: {path}")
    spec = importlib.util.spec_from_file_location("k4_goal_result_validator", path)
    if spec is None or spec.loader is None:
        fail(f"Goal validator cannot be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if not hasattr(module, "validate_result") or not hasattr(module, "ContractError"):
        fail(f"Goal validator lacks the required interface: {path}")
    return module


def validate_goal(goal: dict[str, Any], validator_path: Path) -> tuple[dict[str, Any], set[str]]:
    validator = load_goal_validator(validator_path)
    try:
        validator.validate_result(goal)
    except validator.ContractError as exc:
        fail(f"Goal failed its own validator: {exc}")
    exact_keys(goal, {"schema", "frozen_at", "content_sha256", "content"}, "Goal result")
    if goal["schema"] != GOAL_SCHEMA:
        fail(f"Goal schema must be {GOAL_SCHEMA}")
    if not isinstance(goal["content"], dict):
        fail("Goal content must be an object")
    if goal["content_sha256"] != digest_value(goal["content"]):
        fail("Goal content_sha256 mismatch")
    content = goal["content"]
    if content.get("status") != "frozen":
        fail("Plan requires a frozen Goal")
    goal_id = text(content.get("goal_id"), "Goal goal_id")
    version = text(content.get("version"), "Goal version")
    points = content.get("acceptance_points")
    if not isinstance(points, list) or not points:
        fail("Goal acceptance_points must be nonempty")
    point_ids: set[str] = set()
    for index, point in enumerate(points):
        if not isinstance(point, dict):
            fail(f"Goal acceptance_points[{index}] must be an object")
        point_id = text(point.get("point_id"), f"Goal acceptance_points[{index}].point_id")
        if point_id in point_ids:
            fail(f"duplicate Goal point_id: {point_id}")
        point_ids.add(point_id)
    return content, point_ids


def acyclic(nodes: set[str], edges: list[tuple[str, str]], label: str) -> None:
    outgoing = {node: [] for node in nodes}
    indegree = {node: 0 for node in nodes}
    for source, target in edges:
        outgoing[source].append(target)
        indegree[target] += 1
    ready = [node for node, degree in indegree.items() if degree == 0]
    visited = 0
    while ready:
        node = ready.pop()
        visited += 1
        for target in outgoing[node]:
            indegree[target] -= 1
            if indegree[target] == 0:
                ready.append(target)
    if visited != len(nodes):
        fail(f"{label} must be acyclic")


def dependency_path(edges: list[tuple[str, str]], source: str, target: str) -> bool:
    outgoing: dict[str, list[str]] = {}
    for left, right in edges:
        outgoing.setdefault(left, []).append(right)
    pending = [source]
    seen: set[str] = set()
    while pending:
        current = pending.pop()
        if current == target:
            return True
        if current in seen:
            continue
        seen.add(current)
        pending.extend(outgoing.get(current, []))
    return False


def validate_content(content: dict[str, Any], goal_ref: str, goal_sha256: str, point_ids: set[str]) -> None:
    required = {
        "plan_id", "version", "supersedes", "status", "goal_ref", "goal_sha256",
        "source_refs", "difference", "candidate_routes", "selected_route_id",
        "nodes", "edges", "parallel_groups", "unknowns",
    }
    exact_keys(content, required, "Plan content")
    plan_id = text(content["plan_id"], "plan_id")
    if not ID_RE.fullmatch(plan_id):
        fail("plan_id must be ref-safe")
    text(content["version"], "version")
    nullable_text(content["supersedes"], "supersedes")
    if content["status"] not in STATUSES:
        fail(f"status must be one of {sorted(STATUSES)}")
    if content["goal_ref"] != goal_ref or content["goal_sha256"] != goal_sha256:
        fail("Plan does not bind the supplied Goal exactly")
    text_list(content["source_refs"], "source_refs", nonempty=True)
    text(content["difference"], "difference")
    text_list(content["unknowns"], "unknowns")

    routes = content["candidate_routes"]
    if not isinstance(routes, list) or not routes:
        fail("candidate_routes must be a nonempty list")
    route_ids: set[str] = set()
    route_keys = {
        "route_id", "claim", "supporting_refs", "counter_refs",
        "expected_effects", "rejected_reason",
    }
    for index, route in enumerate(routes):
        label = f"candidate_routes[{index}]"
        if not isinstance(route, dict):
            fail(f"{label} must be an object")
        exact_keys(route, route_keys, label)
        route_id = text(route["route_id"], f"{label}.route_id")
        if not ID_RE.fullmatch(route_id) or route_id in route_ids:
            fail(f"{label}.route_id must be unique and ref-safe")
        route_ids.add(route_id)
        text(route["claim"], f"{label}.claim")
        text_list(route["supporting_refs"], f"{label}.supporting_refs")
        text_list(route["counter_refs"], f"{label}.counter_refs")
        text_list(route["expected_effects"], f"{label}.expected_effects", nonempty=True)
        nullable_text(route["rejected_reason"], f"{label}.rejected_reason")
    selected = content["selected_route_id"]
    if selected is not None and selected not in route_ids:
        fail("selected_route_id must name a candidate route")
    if content["status"] == "executable" and selected is None:
        fail("an executable Plan must select a route")

    nodes = content["nodes"]
    if not isinstance(nodes, list):
        fail("nodes must be a list")
    observed_points: set[str] = set()
    node_keys = {"point_id", "operations", "result_destination", "on_finding", "on_unknown"}
    operation_keys = {
        "operation_id", "depends_on", "inputs", "action", "outputs", "responsible",
        "ability_refs", "permission_refs", "resources", "maximum_side_effects",
        "pre_checks", "post_checks", "idempotency", "retry_limit", "recovery",
        "next", "stop_conditions",
    }
    for index, node in enumerate(nodes):
        label = f"nodes[{index}]"
        if not isinstance(node, dict):
            fail(f"{label} must be an object")
        exact_keys(node, node_keys, label)
        point_id = text(node["point_id"], f"{label}.point_id")
        if point_id in observed_points:
            fail(f"duplicate Plan point_id: {point_id}")
        observed_points.add(point_id)
        for key in ["result_destination", "on_finding", "on_unknown"]:
            text(node[key], f"{label}.{key}")
        operations = node["operations"]
        if not isinstance(operations, list) or (content["status"] == "executable" and not operations):
            fail(f"{label}.operations must be nonempty for an executable Plan")
        operation_ids: set[str] = set()
        operation_edges: list[tuple[str, str]] = []
        for op_index, operation in enumerate(operations):
            op_label = f"{label}.operations[{op_index}]"
            if not isinstance(operation, dict):
                fail(f"{op_label} must be an object")
            exact_keys(operation, operation_keys, op_label)
            operation_id = text(operation["operation_id"], f"{op_label}.operation_id")
            if not ID_RE.fullmatch(operation_id) or operation_id in operation_ids:
                fail(f"{op_label}.operation_id must be unique and ref-safe")
            operation_ids.add(operation_id)
            for key in ["action", "responsible", "idempotency", "recovery"]:
                text(operation[key], f"{op_label}.{key}")
            for key in [
                "inputs", "outputs", "ability_refs", "permission_refs", "resources",
                "maximum_side_effects", "pre_checks", "post_checks", "next", "stop_conditions",
            ]:
                text_list(operation[key], f"{op_label}.{key}", nonempty=True)
            if not isinstance(operation["retry_limit"], int) or operation["retry_limit"] < 0:
                fail(f"{op_label}.retry_limit must be a nonnegative integer")
        for operation in operations:
            for dependency in text_list(operation["depends_on"], f"operation {operation['operation_id']}.depends_on"):
                if dependency not in operation_ids or dependency == operation["operation_id"]:
                    fail(f"operation dependency is invalid: {dependency}")
                operation_edges.append((dependency, operation["operation_id"]))
        if operation_ids:
            acyclic(operation_ids, operation_edges, f"{label} operation graph")
    if observed_points != point_ids:
        fail(f"Plan point coverage differs: missing={sorted(point_ids-observed_points)} extra={sorted(observed_points-point_ids)}")

    edges = content["edges"]
    if not isinstance(edges, list):
        fail("edges must be a list")
    edge_keys = {"from_point_id", "to_point_id", "reason", "guards", "on_non_pass"}
    point_edges: list[tuple[str, str]] = []
    edge_ids: set[tuple[str, str]] = set()
    for index, edge in enumerate(edges):
        label = f"edges[{index}]"
        if not isinstance(edge, dict):
            fail(f"{label} must be an object")
        exact_keys(edge, edge_keys, label)
        source = text(edge["from_point_id"], f"{label}.from_point_id")
        target = text(edge["to_point_id"], f"{label}.to_point_id")
        if source not in point_ids or target not in point_ids or source == target:
            fail(f"{label} endpoints are invalid")
        if (source, target) in edge_ids:
            fail(f"duplicate edge: {source}->{target}")
        edge_ids.add((source, target))
        point_edges.append((source, target))
        text(edge["reason"], f"{label}.reason")
        text_list(edge["guards"], f"{label}.guards", nonempty=True)
        text(edge["on_non_pass"], f"{label}.on_non_pass")
    acyclic(point_ids, point_edges, "acceptance-point graph")

    groups = content["parallel_groups"]
    if not isinstance(groups, list):
        fail("parallel_groups must be a list")
    group_keys = {"point_ids", "reason", "guards"}
    for index, group in enumerate(groups):
        label = f"parallel_groups[{index}]"
        if not isinstance(group, dict):
            fail(f"{label} must be an object")
        exact_keys(group, group_keys, label)
        members = text_list(group["point_ids"], f"{label}.point_ids", nonempty=True)
        if len(members) < 2 or not set(members).issubset(point_ids):
            fail(f"{label}.point_ids must contain at least two Goal points")
        for left in members:
            for right in members:
                if left != right and dependency_path(point_edges, left, right):
                    fail(f"{label} contains dependent points: {left}, {right}")
        text(group["reason"], f"{label}.reason")
        text_list(group["guards"], f"{label}.guards", nonempty=True)

    if content["status"] == "executable" and content["unknowns"]:
        fail("an executable Plan cannot retain blocking unknowns")


def goal_binding(goal_path: Path, validator_path: Path) -> tuple[str, str, set[str]]:
    goal = load_object(goal_path, "Goal result")
    content, point_ids = validate_goal(goal, validator_path)
    goal_sha256 = digest_file(goal_path)
    goal_ref = f"{content['goal_id']}@{content['version']}#sha256={goal_sha256}"
    return goal_ref, goal_sha256, point_ids


def validate_result(result: dict[str, Any], goal_path: Path, validator_path: Path) -> None:
    exact_keys(result, {"schema", "frozen_at", "content_sha256", "content"}, "Plan result")
    if result["schema"] != SCHEMA:
        fail(f"schema must be {SCHEMA}")
    if not isinstance(result["frozen_at"], str) or not RFC3339_RE.fullmatch(result["frozen_at"]):
        fail("frozen_at must be RFC3339")
    if not isinstance(result["content"], dict):
        fail("content must be an object")
    goal_ref, goal_sha256, point_ids = goal_binding(goal_path, validator_path)
    validate_content(result["content"], goal_ref, goal_sha256, point_ids)
    actual = digest_value(result["content"])
    if result["content_sha256"] != actual:
        fail(f"content_sha256 mismatch: expected={actual} actual={result['content_sha256']}")


def freeze(
    goal_path: Path,
    candidate_path: Path,
    output_path: Path,
    frozen_at: str,
    validator_path: Path,
) -> dict[str, Any]:
    if output_path.exists():
        fail(f"output must be absent: {output_path}")
    if not RFC3339_RE.fullmatch(frozen_at):
        fail("--frozen-at must be RFC3339")
    content = load_object(candidate_path, "Plan Candidate")
    forbidden = {"goal_ref", "goal_sha256"}.intersection(content)
    if forbidden:
        fail(f"Plan Candidate must not author generated Goal binding fields: {sorted(forbidden)}")
    goal_ref, goal_sha256, point_ids = goal_binding(goal_path, validator_path)
    content = {**content, "goal_ref": goal_ref, "goal_sha256": goal_sha256}
    validate_content(content, goal_ref, goal_sha256, point_ids)
    result = {
        "schema": SCHEMA,
        "frozen_at": frozen_at,
        "content_sha256": digest_value(content),
        "content": content,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(canonical_bytes(result))
    return {"ok": True, "result": str(output_path), "content_sha256": result["content_sha256"], "goal_ref": goal_ref}


def main() -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    freeze_parser = commands.add_parser("freeze")
    freeze_parser.add_argument("--goal", required=True, type=Path)
    freeze_parser.add_argument("--candidate", required=True, type=Path)
    freeze_parser.add_argument("--output", required=True, type=Path)
    freeze_parser.add_argument("--frozen-at", required=True)
    default_goal_validator = Path(__file__).resolve().parents[2] / "k4-goal" / "scripts" / "goal_result.py"
    freeze_parser.add_argument("--goal-validator", type=Path, default=default_goal_validator)
    validate_parser = commands.add_parser("validate")
    validate_parser.add_argument("--goal", required=True, type=Path)
    validate_parser.add_argument("--result", required=True, type=Path)
    validate_parser.add_argument("--goal-validator", type=Path, default=default_goal_validator)
    args = parser.parse_args()
    try:
        if args.command == "freeze":
            report = freeze(args.goal, args.candidate, args.output, args.frozen_at, args.goal_validator)
        else:
            result = load_object(args.result, "Plan result")
            validate_result(result, args.goal, args.goal_validator)
            report = {"ok": True, "result": str(args.result), "content_sha256": result["content_sha256"]}
        print(json.dumps(report, ensure_ascii=False, sort_keys=True))
        return 0
    except ContractError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False, sort_keys=True), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
