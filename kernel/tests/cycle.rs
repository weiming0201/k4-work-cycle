use ring::digest::{Context, SHA256};
use serde_json::{Value, json};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use std::time::{SystemTime, UNIX_EPOCH};

fn binary(name: &str) -> PathBuf {
    let key = format!("CARGO_BIN_EXE_{}", name.replace('-', "_"));
    std::env::var_os(&key)
        .or_else(|| std::env::var_os(format!("CARGO_BIN_EXE_{name}")))
        .map(PathBuf::from)
        .unwrap_or_else(|| panic!("missing Cargo binary environment: {key}"))
}

fn write_json(path: &Path, value: &Value) {
    let mut bytes = serde_json::to_vec_pretty(value).unwrap();
    bytes.push(b'\n');
    fs::write(path, bytes).unwrap();
}

fn read_json(path: &Path) -> Value {
    serde_json::from_slice(&fs::read(path).unwrap()).unwrap()
}

fn refresh_content_sha256(value: &mut Value) {
    let payload = json!({"bindings": value["bindings"], "body": value["body"]});
    let mut bytes = serde_json::to_vec_pretty(&payload).unwrap();
    bytes.push(b'\n');
    let mut context = Context::new(&SHA256);
    context.update(&bytes);
    let digest: String = context
        .finish()
        .as_ref()
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect();
    value["content_sha256"] = Value::String(digest);
}

fn expect_ok(output: Output) {
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
}

fn expect_fail(output: Output, fragment: &str) {
    assert!(!output.status.success(), "expected failure");
    assert!(
        String::from_utf8_lossy(&output.stderr).contains(fragment),
        "expected {fragment:?}, got {}",
        String::from_utf8_lossy(&output.stderr)
    );
}

fn command(name: &str, words: &[&str]) -> Output {
    Command::new(binary(name)).args(words).output().unwrap()
}

fn operation(dependencies: Vec<usize>, point_id: &str, control_id: &str, action: &str) -> Value {
    json!({
        "depends_on_indices": dependencies,
        "satisfies": [point_id],
        "controlled_by": [control_id],
        "action_ref": action,
        "responsible_ref": "executor://isolated-test",
        "input_refs": ["input://fixture"],
        "output_refs": ["output://fixture"],
        "permission_refs": ["authorization://isolated-test"],
        "resource_refs": ["resource://local-process"],
        "maximum_side_effects": ["files inside the fixture"],
        "pre_checks": ["dependencies and boundary still pass"],
        "post_checks": ["declared output is addressable"],
        "idempotency": "every attempt uses an absent output path",
        "retry_limit": 0,
        "recovery": "retain evidence and resume at this operation"
    })
}

#[test]
fn complete_cycle_and_refusals() {
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let work = std::env::temp_dir().join(format!("k4-work-cycle-{}-{nonce}", std::process::id()));
    fs::create_dir(&work).unwrap();

    let align_input = work.join("align-input.json");
    let align = work.join("align.json");
    write_json(
        &align_input,
        &json!({
            "subject": "isolated cycle fixture",
            "boundary": "only files inside the isolated fixture",
            "cutoff": "before this test run",
            "source_refs": ["source://fixture"],
            "items": [{
                "state": "gap",
                "statement": "the expected result does not yet exist",
                "evidence_refs": ["source://fixture"],
                "uses_run": false,
                "route": "goal-candidate",
                "route_ref": null
            }]
        }),
    );
    expect_ok(command(
        "k4-align-result",
        &[
            "generate",
            "--input",
            align_input.to_str().unwrap(),
            "--output",
            align.to_str().unwrap(),
        ],
    ));
    expect_ok(command(
        "k4-align-result",
        &["validate", "--result", align.to_str().unwrap()],
    ));
    let item_id = read_json(&align)["body"]["items"][0]["item_id"]
        .as_str()
        .unwrap()
        .to_owned();

    let goal_input = work.join("goal-input.json");
    let goal = work.join("goal.json");
    write_json(
        &goal_input,
        &json!({
            "align_item_ids": [item_id],
            "objective": "produce one valid stable result inside the fixture",
            "target": "isolated cycle fixture v1",
            "source_refs": ["source://fixture"],
            "evidence_cutoff": {
                "at": "before observing this test attempt",
                "included_refs": ["source://fixture"]
            },
            "baseline_refs": ["baseline://fixture-empty"],
            "scope": ["create one result inside the fixture"],
            "non_goals": ["adopt or publish the result"],
            "execution_envelope": {
                "authorization_ref": "authorization://isolated-test",
                "authorization_scope": "create and validate files only inside the fixture",
                "authorization_claim_limit": "permits fixture writes but does not prove semantic correctness",
                "resources": ["local process"],
                "budget": "one bounded attempt",
                "maximum_side_effects": ["files inside the fixture"],
                "stop_conditions": {
                    "completed": "all acceptance and control judgments pass",
                    "paused": "evidence unavailable",
                    "failed": "a judgment has a Finding",
                    "cancelled": "caller cancels"
                },
                "incomplete_deliverable": "failed input, output, evidence, and resume command"
            },
            "acceptance_points": [{
                "statement": "the expected stable result exists",
                "required_evidence": ["actual result and checker output"],
                "judge": {"kind": "script", "claim_limit": "declared file checks only"},
                "acceptance": {
                    "observable": "result path and validator status",
                    "conditions": ["the frozen fixture is used"],
                    "window": "after execution and before adoption",
                    "expected": "the result exists and validates",
                    "falsifier": "the result is absent or invalid",
                    "comparison_method": "compare exact path and validator output",
                    "sampling_rule": "full census"
                }
            }],
            "control_contracts": [{
                "statement": "writes remain inside the fixture",
                "required_evidence": ["operation trace and path check"],
                "judge": {"kind": "script", "claim_limit": "declared paths only"},
                "controlled_variable": "write target",
                "allowed_domain": ["the isolated fixture"],
                "forbidden_drift": ["write outside the fixture"],
                "required_trace": ["invocation trace"],
                "check_method": "compare each write target with the boundary",
                "check_timing": "invariant",
                "on_non_pass": "stop and retain the trace"
            }],
            "blockers": [],
            "unknowns": []
        }),
    );
    expect_ok(command(
        "k4-goal-result",
        &[
            "generate",
            "--align",
            align.to_str().unwrap(),
            "--input",
            goal_input.to_str().unwrap(),
            "--output",
            goal.to_str().unwrap(),
        ],
    ));
    expect_ok(command(
        "k4-goal-result",
        &[
            "validate",
            "--align",
            align.to_str().unwrap(),
            "--result",
            goal.to_str().unwrap(),
        ],
    ));
    let goal_value = read_json(&goal);
    let point_id = goal_value["body"]["acceptance_points"][0]["point_id"]
        .as_str()
        .unwrap()
        .to_owned();
    let control_id = goal_value["body"]["control_contracts"][0]["control_id"]
        .as_str()
        .unwrap()
        .to_owned();

    let plan_input = work.join("plan-input.json");
    let plan = work.join("plan.json");
    write_json(
        &plan_input,
        &json!({
            "difference": "the expected result and its validation evidence are absent",
            "route": {
                "claim": "produce and then validate one bounded result",
                "supporting_refs": ["source://fixture"],
                "counter_refs": []
            },
            "operations": [
                operation(vec![], &point_id, &control_id, "tool://produce"),
                operation(vec![0], &point_id, &control_id, "tool://validate")
            ],
            "parallel_groups": [],
            "blockers": [],
            "unknowns": []
        }),
    );
    expect_ok(command(
        "k4-plan-result",
        &[
            "generate",
            "--goal",
            goal.to_str().unwrap(),
            "--input",
            plan_input.to_str().unwrap(),
            "--output",
            plan.to_str().unwrap(),
        ],
    ));
    expect_ok(command(
        "k4-plan-result",
        &[
            "validate",
            "--goal",
            goal.to_str().unwrap(),
            "--result",
            plan.to_str().unwrap(),
        ],
    ));
    let plan_value = read_json(&plan);
    let operation_ids: Vec<String> = plan_value["body"]["operations"]
        .as_array()
        .unwrap()
        .iter()
        .map(|operation| operation["operation_id"].as_str().unwrap().to_owned())
        .collect();

    let run_input = work.join("run-input.json");
    let run = work.join("run.json");
    write_json(
        &run_input,
        &json!({
            "operation_results": operation_ids.iter().map(|operation_id| json!({
                "operation_id": operation_id,
                "result": "pass",
                "eligibility_refs": ["eligibility://pass"],
                "actual_output_refs": ["actual://fixture-output"],
                "evidence_refs": ["evidence://operation-pass"],
                "trace_refs": ["trace://operation"]
            })).collect::<Vec<_>>(),
            "acceptance_results": [{
                "point_id": point_id,
                "result": "pass",
                "actual_refs": ["actual://fixture"],
                "comparison_refs": ["comparison://pass"],
                "evidence_refs": ["evidence://acceptance-pass"]
            }],
            "control_results": [{
                "control_id": control_id,
                "result": "pass",
                "actual_refs": ["actual://write-targets"],
                "trace_refs": ["trace://operation"],
                "comparison_refs": ["comparison://inside-boundary"],
                "evidence_refs": ["evidence://control-pass"]
            }],
            "budget_evidence_refs": ["budget://within"],
            "side_effect_evidence_refs": ["effects://within"],
            "stop_state": "completed",
            "resume_ref": null
        }),
    );
    expect_ok(command(
        "k4-run-result",
        &[
            "generate",
            "--goal",
            goal.to_str().unwrap(),
            "--plan",
            plan.to_str().unwrap(),
            "--input",
            run_input.to_str().unwrap(),
            "--output",
            run.to_str().unwrap(),
        ],
    ));
    expect_ok(command(
        "k4-run-result",
        &[
            "validate",
            "--goal",
            goal.to_str().unwrap(),
            "--plan",
            plan.to_str().unwrap(),
            "--result",
            run.to_str().unwrap(),
        ],
    ));

    let post_input = work.join("post-align-input.json");
    let post = work.join("post-align.json");
    write_json(
        &post_input,
        &json!({
            "subject": "completed isolated cycle fixture",
            "boundary": "the exact Run result",
            "cutoff": "after Run validation",
            "source_refs": ["source://run-result"],
            "items": [{
                "state": "aligned",
                "statement": "the Run completed with all declared judgments passing",
                "evidence_refs": ["source://run-result"],
                "uses_run": true,
                "route": "none",
                "route_ref": null
            }]
        }),
    );
    expect_ok(command(
        "k4-align-result",
        &[
            "generate",
            "--input",
            post_input.to_str().unwrap(),
            "--output",
            post.to_str().unwrap(),
            "--run",
            run.to_str().unwrap(),
        ],
    ));

    expect_fail(
        command(
            "k4-align-result",
            &[
                "generate",
                "--input",
                align_input.to_str().unwrap(),
                "--output",
                align.to_str().unwrap(),
            ],
        ),
        "output must be absent",
    );

    let invalid_goal_input = work.join("invalid-goal-input.json");
    let mut invalid_goal = read_json(&goal_input);
    invalid_goal["align_item_ids"] = json!(["item-not-present"]);
    write_json(&invalid_goal_input, &invalid_goal);
    expect_fail(
        command(
            "k4-goal-result",
            &[
                "generate",
                "--align",
                align.to_str().unwrap(),
                "--input",
                invalid_goal_input.to_str().unwrap(),
                "--output",
                work.join("never-goal.json").to_str().unwrap(),
            ],
        ),
        "align_item_ids must exist",
    );

    let uncovered_plan_input = work.join("uncovered-plan-input.json");
    let mut uncovered_plan = read_json(&plan_input);
    uncovered_plan["operations"][0]["controlled_by"] = json!([]);
    uncovered_plan["operations"][1]["controlled_by"] = json!([]);
    write_json(&uncovered_plan_input, &uncovered_plan);
    expect_fail(
        command(
            "k4-plan-result",
            &[
                "generate",
                "--goal",
                goal.to_str().unwrap(),
                "--input",
                uncovered_plan_input.to_str().unwrap(),
                "--output",
                work.join("never-uncovered-plan.json").to_str().unwrap(),
            ],
        ),
        "operation_ids must not be empty",
    );

    let parallel_plan_input = work.join("parallel-plan-input.json");
    let mut parallel_plan = read_json(&plan_input);
    parallel_plan["parallel_groups"] = json!([{
        "operation_indices": [0, 1],
        "reason": "invalid attempt to parallelize dependent operations",
        "guards": ["fixture only"]
    }]);
    write_json(&parallel_plan_input, &parallel_plan);
    expect_fail(
        command(
            "k4-plan-result",
            &[
                "generate",
                "--goal",
                goal.to_str().unwrap(),
                "--input",
                parallel_plan_input.to_str().unwrap(),
                "--output",
                work.join("never-parallel-plan.json").to_str().unwrap(),
            ],
        ),
        "parallel operations must not have a dependency path",
    );

    let cyclic_plan = work.join("cyclic-plan.json");
    let mut cyclic_plan_value = read_json(&plan);
    cyclic_plan_value["body"]["operations"][0]["depends_on"] = json!([operation_ids[1]]);
    refresh_content_sha256(&mut cyclic_plan_value);
    write_json(&cyclic_plan, &cyclic_plan_value);
    expect_fail(
        command(
            "k4-plan-result",
            &[
                "validate",
                "--goal",
                goal.to_str().unwrap(),
                "--result",
                cyclic_plan.to_str().unwrap(),
            ],
        ),
        "Plan operation graph must be acyclic",
    );

    let coverageless_plan = work.join("coverageless-plan.json");
    let mut coverageless_plan_value = read_json(&plan);
    coverageless_plan_value["body"]["coverage"]["acceptance"] = json!([]);
    coverageless_plan_value["body"]["coverage"]["controls"] = json!([]);
    refresh_content_sha256(&mut coverageless_plan_value);
    write_json(&coverageless_plan, &coverageless_plan_value);
    expect_fail(
        command(
            "k4-run-result",
            &[
                "generate",
                "--goal",
                goal.to_str().unwrap(),
                "--plan",
                coverageless_plan.to_str().unwrap(),
                "--input",
                run_input.to_str().unwrap(),
                "--output",
                work.join("never-coverageless-run.json").to_str().unwrap(),
            ],
        ),
        "Plan coverage must contain every Goal acceptance point once",
    );

    let bypass_input = work.join("bypass-run-input.json");
    let mut bypass = read_json(&run_input);
    bypass["operation_results"][0]["result"] = json!("Finding");
    bypass["acceptance_results"][0]["result"] = json!("Finding");
    bypass["stop_state"] = json!("failed");
    bypass["resume_ref"] = json!("resume://dependency-finding");
    write_json(&bypass_input, &bypass);
    expect_fail(
        command(
            "k4-run-result",
            &[
                "generate",
                "--goal",
                goal.to_str().unwrap(),
                "--plan",
                plan.to_str().unwrap(),
                "--input",
                bypass_input.to_str().unwrap(),
                "--output",
                work.join("never-bypass-run.json").to_str().unwrap(),
            ],
        ),
        "after a non-pass dependency",
    );

    let premature_input = work.join("premature-run-input.json");
    let mut premature = read_json(&run_input);
    premature["operation_results"][1]["result"] = json!("Finding");
    premature["stop_state"] = json!("failed");
    premature["resume_ref"] = json!("resume://validation-finding");
    write_json(&premature_input, &premature);
    expect_fail(
        command(
            "k4-run-result",
            &[
                "generate",
                "--goal",
                goal.to_str().unwrap(),
                "--plan",
                plan.to_str().unwrap(),
                "--input",
                premature_input.to_str().unwrap(),
                "--output",
                work.join("never-premature-run.json").to_str().unwrap(),
            ],
        ),
        "acceptance cannot pass before its operations pass",
    );

    let unchecked_input = work.join("unchecked-invariant-input.json");
    let mut unchecked = read_json(&run_input);
    unchecked["control_results"][0]["result"] = json!("not-run");
    unchecked["control_results"][0]["actual_refs"] = json!([]);
    unchecked["control_results"][0]["trace_refs"] = json!([]);
    unchecked["control_results"][0]["comparison_refs"] = json!([]);
    unchecked["control_results"][0]["evidence_refs"] = json!([]);
    unchecked["stop_state"] = json!("paused");
    unchecked["resume_ref"] = json!("resume://run-invariant-check");
    write_json(&unchecked_input, &unchecked);
    expect_fail(
        command(
            "k4-run-result",
            &[
                "generate",
                "--goal",
                goal.to_str().unwrap(),
                "--plan",
                plan.to_str().unwrap(),
                "--input",
                unchecked_input.to_str().unwrap(),
                "--output",
                work.join("never-unchecked-run.json").to_str().unwrap(),
            ],
        ),
        "invariant-controlled operation without a control result",
    );

    let incomplete_input = work.join("incomplete-run-input.json");
    let mut incomplete = read_json(&run_input);
    incomplete["operation_results"]
        .as_array_mut()
        .unwrap()
        .pop();
    incomplete["acceptance_results"][0]["result"] = json!("unknown");
    incomplete["acceptance_results"][0]["actual_refs"] = json!([]);
    incomplete["acceptance_results"][0]["comparison_refs"] = json!([]);
    incomplete["acceptance_results"][0]["evidence_refs"] = json!([]);
    incomplete["stop_state"] = json!("paused");
    incomplete["resume_ref"] = json!("resume://missing-operation-result");
    write_json(&incomplete_input, &incomplete);
    expect_fail(
        command(
            "k4-run-result",
            &[
                "generate",
                "--goal",
                goal.to_str().unwrap(),
                "--plan",
                plan.to_str().unwrap(),
                "--input",
                incomplete_input.to_str().unwrap(),
                "--output",
                work.join("never-incomplete-run.json").to_str().unwrap(),
            ],
        ),
        "cover every Plan operation exactly once",
    );

    let missing_parent = work.join("missing-parent");
    expect_fail(
        command(
            "k4-align-result",
            &[
                "generate",
                "--input",
                align_input.to_str().unwrap(),
                "--output",
                missing_parent.join("never.json").to_str().unwrap(),
            ],
        ),
        "output parent must already exist",
    );
    assert!(!missing_parent.exists());

    fs::remove_dir_all(&work).unwrap();
}
