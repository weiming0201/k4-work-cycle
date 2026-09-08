use ring::digest::{Context, SHA256};
use serde_json::{Map, Value, json};
use std::collections::{BTreeMap, BTreeSet};
use std::env;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

type Result<T> = std::result::Result<T, String>;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Kind {
    Align,
    Goal,
    Plan,
    Run,
}

impl Kind {
    fn schema(self) -> &'static str {
        match self {
            Self::Align => "k4-align-result/v1",
            Self::Goal => "k4-goal-result/v2",
            Self::Plan => "k4-plan-result/v2",
            Self::Run => "k4-run-result/v1",
        }
    }

    fn label(self) -> &'static str {
        match self {
            Self::Align => "Align",
            Self::Goal => "Goal",
            Self::Plan => "Plan",
            Self::Run => "Run",
        }
    }
}

#[derive(Default)]
struct Options {
    input: Option<PathBuf>,
    output: Option<PathBuf>,
    result: Option<PathBuf>,
    align: Option<PathBuf>,
    goal: Option<PathBuf>,
    plan: Option<PathBuf>,
    run: Option<PathBuf>,
}

fn usage(kind: Kind) -> String {
    let common = match kind {
        Kind::Align => {
            "generate --input <semantic.json> --output <absent.json> [--run <run.json>]\nvalidate --result <result.json> [--run <run.json>]"
        }
        Kind::Goal => {
            "generate --align <align.json> --input <semantic.json> --output <absent.json>\nvalidate --align <align.json> --result <result.json>"
        }
        Kind::Plan => {
            "generate --goal <goal.json> --input <semantic.json> --output <absent.json>\nvalidate --goal <goal.json> --result <result.json>"
        }
        Kind::Run => {
            "generate --goal <goal.json> --plan <plan.json> --input <semantic.json> --output <absent.json>\nvalidate --goal <goal.json> --plan <plan.json> --result <result.json>"
        }
    };
    format!("{}\n{}", kind.schema(), common)
}

fn parse_options(kind: Kind, args: &[String]) -> Result<Options> {
    let mut options = Options::default();
    let mut index = 0;
    while index < args.len() {
        let flag = &args[index];
        index += 1;
        if index >= args.len() {
            return Err(format!("missing value for {flag}"));
        }
        let value = PathBuf::from(&args[index]);
        index += 1;
        let slot = match flag.as_str() {
            "--input" => &mut options.input,
            "--output" => &mut options.output,
            "--result" => &mut options.result,
            "--align" => &mut options.align,
            "--goal" => &mut options.goal,
            "--plan" => &mut options.plan,
            "--run" => &mut options.run,
            _ => return Err(format!("unsupported argument for {}: {flag}", kind.label())),
        };
        if slot.replace(value).is_some() {
            return Err(format!("duplicate argument: {flag}"));
        }
    }
    Ok(options)
}

fn require<'a>(value: &'a Option<PathBuf>, flag: &str) -> Result<&'a Path> {
    value
        .as_deref()
        .ok_or_else(|| format!("required argument missing: {flag}"))
}

fn reject(value: &Option<PathBuf>, flag: &str) -> Result<()> {
    if value.is_some() {
        Err(format!("argument is not valid here: {flag}"))
    } else {
        Ok(())
    }
}

pub fn run(kind: Kind) -> i32 {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.is_empty() || args[0] == "--help" || args[0] == "-h" {
        println!("{}", usage(kind));
        return 0;
    }
    let command = args[0].as_str();
    let outcome = parse_options(kind, &args[1..]).and_then(|options| match command {
        "generate" => generate(kind, options),
        "validate" => validate_command(kind, options),
        _ => Err(format!("unknown command: {command}\n{}", usage(kind))),
    });
    match outcome {
        Ok(report) => {
            println!("{}", canonical_string(&report));
            0
        }
        Err(error) => {
            eprintln!(
                "{}",
                canonical_string(&json!({"ok": false, "error": error}))
            );
            1
        }
    }
}

fn generate(kind: Kind, options: Options) -> Result<Value> {
    reject(&options.result, "--result")?;
    let input_path = require(&options.input, "--input")?;
    let output_path = require(&options.output, "--output")?;
    let input = load_object(input_path, "semantic input")?;
    let bindings = bindings_for(kind, &options, true)?;
    let body = build_body(kind, input, &bindings, &options)?;
    validate_body(kind, &body, &bindings)?;
    let content_sha256 = sha256_value(&json!({"bindings": bindings, "body": body}));
    let result = json!({
        "schema": kind.schema(),
        "generated_unix_ms": now_unix_ms()?,
        "content_sha256": content_sha256,
        "bindings": bindings,
        "body": body,
    });
    validate_envelope(kind, &result, &options, true)?;
    write_absent(output_path, &result)?;
    let written = Value::Object(load_object(output_path, "written result")?);
    validate_envelope(kind, &written, &options, true)?;
    Ok(json!({
        "ok": true,
        "schema": kind.schema(),
        "result": output_path.to_string_lossy(),
        "content_sha256": written["content_sha256"],
        "file_sha256": sha256_file(output_path)?,
    }))
}

fn validate_command(kind: Kind, options: Options) -> Result<Value> {
    reject(&options.input, "--input")?;
    reject(&options.output, "--output")?;
    let result_path = require(&options.result, "--result")?;
    let result = Value::Object(load_object(result_path, "result")?);
    validate_envelope(kind, &result, &options, true)?;
    Ok(json!({
        "ok": true,
        "schema": kind.schema(),
        "result": result_path.to_string_lossy(),
        "content_sha256": result["content_sha256"],
        "file_sha256": sha256_file(result_path)?,
    }))
}

fn bindings_for(kind: Kind, options: &Options, compare: bool) -> Result<Value> {
    match kind {
        Kind::Align => {
            reject(&options.align, "--align")?;
            reject(&options.goal, "--goal")?;
            reject(&options.plan, "--plan")?;
            let run = match &options.run {
                Some(path) => binding_for(Kind::Run, path)?,
                None => Value::Null,
            };
            Ok(json!({"run": run}))
        }
        Kind::Goal => {
            reject(&options.goal, "--goal")?;
            reject(&options.plan, "--plan")?;
            reject(&options.run, "--run")?;
            let align = binding_for(Kind::Align, require(&options.align, "--align")?)?;
            Ok(json!({"align": align}))
        }
        Kind::Plan => {
            reject(&options.align, "--align")?;
            reject(&options.plan, "--plan")?;
            reject(&options.run, "--run")?;
            let goal_path = require(&options.goal, "--goal")?;
            let goal = load_validated_self(Kind::Goal, goal_path)?;
            if goal["body"]["status"] != "frozen" {
                return Err("Plan requires a frozen Goal".into());
            }
            Ok(json!({"goal": binding_from_loaded(Kind::Goal, goal_path, &goal)?}))
        }
        Kind::Run => {
            reject(&options.align, "--align")?;
            reject(&options.run, "--run")?;
            let goal_path = require(&options.goal, "--goal")?;
            let plan_path = require(&options.plan, "--plan")?;
            let goal = load_validated_self(Kind::Goal, goal_path)?;
            let plan = load_validated_self(Kind::Plan, plan_path)?;
            if goal["body"]["status"] != "frozen" {
                return Err("Run requires a frozen Goal".into());
            }
            if plan["body"]["status"] != "executable" {
                return Err("Run requires an executable Plan".into());
            }
            cross_validate(Kind::Plan, &plan["body"], options)?;
            let goal_binding = binding_from_loaded(Kind::Goal, goal_path, &goal)?;
            if compare && plan["bindings"]["goal"] != goal_binding {
                return Err("Plan is not bound to the supplied Goal bytes".into());
            }
            Ok(json!({
                "goal": goal_binding,
                "plan": binding_from_loaded(Kind::Plan, plan_path, &plan)?,
            }))
        }
    }
}

fn binding_for(kind: Kind, path: &Path) -> Result<Value> {
    let loaded = load_validated_self(kind, path)?;
    binding_from_loaded(kind, path, &loaded)
}

fn binding_from_loaded(kind: Kind, path: &Path, value: &Value) -> Result<Value> {
    Ok(json!({
        "ref": format!("{}#sha256={}", kind.schema(), sha256_file(path)?),
        "sha256": sha256_file(path)?,
        "content_sha256": value["content_sha256"],
    }))
}

fn load_validated_self(kind: Kind, path: &Path) -> Result<Value> {
    let value = Value::Object(load_object(path, kind.label())?);
    validate_envelope(kind, &value, &Options::default(), false)?;
    Ok(value)
}

fn validate_envelope(
    kind: Kind,
    value: &Value,
    options: &Options,
    compare_bindings: bool,
) -> Result<()> {
    let object = as_object(value, kind.label())?;
    exact_keys(
        object,
        &[
            "schema",
            "generated_unix_ms",
            "content_sha256",
            "bindings",
            "body",
        ],
        kind.label(),
    )?;
    if value["schema"] != kind.schema() {
        return Err(format!("schema must be {}", kind.schema()));
    }
    value["generated_unix_ms"]
        .as_u64()
        .ok_or_else(|| "generated_unix_ms must be an unsigned integer".to_string())?;
    let digest = text(&value["content_sha256"], "content_sha256")?;
    if digest.len() != 64
        || !digest
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase())
    {
        return Err("content_sha256 must be 64 lowercase hex characters".into());
    }
    let bindings = as_object(&value["bindings"], "bindings")?;
    validate_binding_shape(kind, bindings)?;
    let body = as_object(&value["body"], "body")?;
    validate_body(kind, &Value::Object(body.clone()), &value["bindings"])?;
    let expected_digest =
        sha256_value(&json!({"bindings": value["bindings"], "body": value["body"]}));
    if digest != expected_digest {
        return Err(format!(
            "content_sha256 mismatch: expected={expected_digest} actual={digest}"
        ));
    }
    if compare_bindings {
        let expected = bindings_for(kind, options, true)?;
        if value["bindings"] != expected {
            return Err("predecessor binding does not match supplied bytes".into());
        }
        cross_validate(kind, &value["body"], options)?;
    }
    Ok(())
}

fn cross_validate(kind: Kind, body: &Value, options: &Options) -> Result<()> {
    match kind {
        Kind::Align => Ok(()),
        Kind::Goal => {
            let align = load_validated_self(Kind::Align, require(&options.align, "--align")?)?;
            let items = align["body"]["items"].as_array().unwrap();
            for item_id in string_list(&body["align_item_ids"], "align_item_ids", true)? {
                let item = items
                    .iter()
                    .find(|item| item["item_id"] == item_id)
                    .ok_or_else(|| {
                        format!("align_item_id is absent from bound Align: {item_id}")
                    })?;
                if item["route"] != "goal-candidate" {
                    return Err(format!(
                        "Align item is not routed as goal-candidate: {item_id}"
                    ));
                }
            }
            Ok(())
        }
        Kind::Plan => {
            let goal = load_validated_self(Kind::Goal, require(&options.goal, "--goal")?)?;
            let expected_points: Vec<String> = goal["body"]["acceptance_points"]
                .as_array()
                .unwrap()
                .iter()
                .map(|point| point["point_id"].as_str().unwrap().to_owned())
                .collect();
            let expected_controls: Vec<String> = goal["body"]["control_contracts"]
                .as_array()
                .unwrap()
                .iter()
                .map(|control| control["control_id"].as_str().unwrap().to_owned())
                .collect();
            let actual_points: Vec<String> = body["coverage"]["acceptance"]
                .as_array()
                .unwrap()
                .iter()
                .map(|entry| entry["point_id"].as_str().unwrap().to_owned())
                .collect();
            let actual_controls: Vec<String> = body["coverage"]["controls"]
                .as_array()
                .unwrap()
                .iter()
                .map(|entry| entry["control_id"].as_str().unwrap().to_owned())
                .collect();
            if actual_points != expected_points {
                return Err("Plan coverage must contain every Goal acceptance point once".into());
            }
            if actual_controls != expected_controls {
                return Err("Plan coverage must contain every Goal control once".into());
            }
            let point_set: BTreeSet<String> = expected_points.into_iter().collect();
            let control_set: BTreeSet<String> = expected_controls.into_iter().collect();
            for operation in body["operations"].as_array().unwrap() {
                if !string_list(&operation["satisfies"], "satisfies", false)?
                    .iter()
                    .all(|id| point_set.contains(id))
                {
                    return Err("Plan operation references an unknown acceptance point".into());
                }
                if !string_list(&operation["controlled_by"], "controlled_by", false)?
                    .iter()
                    .all(|id| control_set.contains(id))
                {
                    return Err("Plan operation references an unknown control".into());
                }
            }
            Ok(())
        }
        Kind::Run => {
            let goal = load_validated_self(Kind::Goal, require(&options.goal, "--goal")?)?;
            let plan = load_validated_self(Kind::Plan, require(&options.plan, "--plan")?)?;
            let expected_points: BTreeSet<String> = goal["body"]["acceptance_points"]
                .as_array()
                .unwrap()
                .iter()
                .map(|point| point["point_id"].as_str().unwrap().to_owned())
                .collect();
            let acceptance_results = body["acceptance_results"].as_array().unwrap();
            let actual_points: BTreeSet<String> = acceptance_results
                .iter()
                .map(|result| result["point_id"].as_str().unwrap().to_owned())
                .collect();
            if actual_points != expected_points || acceptance_results.len() != expected_points.len()
            {
                return Err(
                    "Run acceptance_results must cover every Goal point exactly once".into(),
                );
            }
            let expected_controls: BTreeSet<String> = goal["body"]["control_contracts"]
                .as_array()
                .unwrap()
                .iter()
                .map(|control| control["control_id"].as_str().unwrap().to_owned())
                .collect();
            let control_results = body["control_results"].as_array().unwrap();
            let actual_controls: BTreeSet<String> = control_results
                .iter()
                .map(|result| result["control_id"].as_str().unwrap().to_owned())
                .collect();
            if actual_controls != expected_controls
                || control_results.len() != expected_controls.len()
            {
                return Err(
                    "Run control_results must cover every Goal control exactly once".into(),
                );
            }
            for control_result in control_results {
                let control_id = control_result["control_id"].as_str().unwrap();
                let control = goal["body"]["control_contracts"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .find(|control| control["control_id"] == control_id)
                    .unwrap();
                if control_result["required_check_timing"] != control["check_timing"] {
                    return Err("Run control timing must be generated from Goal".into());
                }
            }
            let expected_operations: BTreeSet<String> = plan["body"]["operations"]
                .as_array()
                .unwrap()
                .iter()
                .map(|operation| operation["operation_id"].as_str().unwrap().to_owned())
                .collect();
            let operation_results = body["operation_results"].as_array().unwrap();
            let actual_operations: BTreeSet<String> = operation_results
                .iter()
                .map(|result| result["operation_id"].as_str().unwrap().to_owned())
                .collect();
            if actual_operations != expected_operations
                || operation_results.len() != expected_operations.len()
            {
                return Err(
                    "Run operation_results must cover every Plan operation exactly once".into(),
                );
            }
            let acceptance_state: BTreeMap<String, String> = acceptance_results
                .iter()
                .map(|result| {
                    (
                        result["point_id"].as_str().unwrap().to_owned(),
                        result["result"].as_str().unwrap().to_owned(),
                    )
                })
                .collect();
            let control_state: BTreeMap<String, String> = control_results
                .iter()
                .map(|result| {
                    (
                        result["control_id"].as_str().unwrap().to_owned(),
                        result["result"].as_str().unwrap().to_owned(),
                    )
                })
                .collect();
            let operation_state: BTreeMap<String, String> = operation_results
                .iter()
                .map(|result| {
                    (
                        result["operation_id"].as_str().unwrap().to_owned(),
                        result["result"].as_str().unwrap().to_owned(),
                    )
                })
                .collect();
            for operation in plan["body"]["operations"].as_array().unwrap() {
                let operation_id = operation["operation_id"].as_str().unwrap();
                if operation_state[operation_id] != "not-run" {
                    for dependency in operation["depends_on"].as_array().unwrap() {
                        let dependency_id = dependency.as_str().unwrap();
                        if operation_state[dependency_id] != "pass" {
                            return Err(
                                "Run executed an operation after a non-pass dependency".into()
                            );
                        }
                    }
                }
            }
            for entry in plan["body"]["coverage"]["acceptance"].as_array().unwrap() {
                let point_id = entry["point_id"].as_str().unwrap();
                if acceptance_state[point_id] == "pass"
                    && entry["operation_ids"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .any(|id| operation_state[id.as_str().unwrap()] != "pass")
                {
                    return Err("Run acceptance cannot pass before its operations pass".into());
                }
            }
            for entry in plan["body"]["coverage"]["controls"].as_array().unwrap() {
                let control_id = entry["control_id"].as_str().unwrap();
                let control = goal["body"]["control_contracts"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .find(|control| control["control_id"] == control_id)
                    .unwrap();
                if control["check_timing"] == "invariant"
                    && control_state[control_id] == "not-run"
                    && entry["operation_ids"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .any(|id| operation_state[id.as_str().unwrap()] != "not-run")
                {
                    return Err(
                        "Run cannot execute an invariant-controlled operation without a control result"
                            .into(),
                    );
                }
            }
            Ok(())
        }
    }
}

fn validate_binding_shape(kind: Kind, bindings: &Map<String, Value>) -> Result<()> {
    let keys = match kind {
        Kind::Align => vec!["run"],
        Kind::Goal => vec!["align"],
        Kind::Plan => vec!["goal"],
        Kind::Run => vec!["goal", "plan"],
    };
    exact_keys(bindings, &keys, "bindings")?;
    for key in keys {
        let value = &bindings[key];
        if kind == Kind::Align && value.is_null() {
            continue;
        }
        validate_binding(value, &format!("bindings.{key}"))?;
    }
    Ok(())
}

fn validate_binding(value: &Value, label: &str) -> Result<()> {
    let object = as_object(value, label)?;
    exact_keys(object, &["ref", "sha256", "content_sha256"], label)?;
    text(&value["ref"], &format!("{label}.ref"))?;
    for key in ["sha256", "content_sha256"] {
        let digest = text(&value[key], &format!("{label}.{key}"))?;
        if digest.len() != 64
            || !digest
                .bytes()
                .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase())
        {
            return Err(format!("{label}.{key} must be 64 lowercase hex characters"));
        }
    }
    Ok(())
}

fn build_body(
    kind: Kind,
    input: Map<String, Value>,
    bindings: &Value,
    options: &Options,
) -> Result<Value> {
    match kind {
        Kind::Align => build_align(input, bindings),
        Kind::Goal => build_goal(input, options),
        Kind::Plan => build_plan(input, options),
        Kind::Run => build_run(input, options),
    }
}

fn build_align(mut input: Map<String, Value>, bindings: &Value) -> Result<Value> {
    exact_keys(
        &input,
        &["subject", "boundary", "cutoff", "source_refs", "items"],
        "Align input",
    )?;
    let run_bound = !bindings["run"].is_null();
    let items = input
        .get_mut("items")
        .and_then(Value::as_array_mut)
        .ok_or_else(|| "items must be an array".to_string())?;
    let mut seen = BTreeSet::new();
    let mut has_run_use = false;
    let mut has_unknown = false;
    let mut has_open = false;
    for (index, item) in items.iter_mut().enumerate() {
        let object = as_object_mut(item, &format!("items[{index}]"))?;
        exact_keys(
            object,
            &[
                "state",
                "statement",
                "evidence_refs",
                "uses_run",
                "route",
                "route_ref",
            ],
            &format!("items[{index}]"),
        )?;
        let state = text(&object["state"], "item.state")?;
        has_unknown |= state == "unknown";
        has_open |= state == "gap" || state == "conflict";
        has_run_use |= object["uses_run"].as_bool().unwrap_or(false);
        let id = derived_id("item", &Value::Object(object.clone()));
        if !seen.insert(id.clone()) {
            return Err("Align items must be semantically distinct".into());
        }
        object.insert("item_id".into(), Value::String(id));
    }
    if has_run_use && !run_bound {
        return Err("Align item uses_run=true requires --run".into());
    }
    if run_bound && !has_run_use {
        return Err("a Run-bound Align requires at least one uses_run=true item".into());
    }
    let status = if has_unknown {
        "unknown"
    } else if has_open {
        "open"
    } else {
        "aligned"
    };
    input.insert("status".into(), Value::String(status.into()));
    Ok(Value::Object(input))
}

fn build_goal(mut input: Map<String, Value>, options: &Options) -> Result<Value> {
    exact_keys(
        &input,
        &[
            "align_item_ids",
            "objective",
            "target",
            "source_refs",
            "evidence_cutoff",
            "baseline_refs",
            "scope",
            "non_goals",
            "execution_envelope",
            "acceptance_points",
            "control_contracts",
            "blockers",
            "unknowns",
        ],
        "Goal input",
    )?;
    let align = load_validated_self(Kind::Align, require(&options.align, "--align")?)?;
    let available: BTreeSet<String> = align["body"]["items"]
        .as_array()
        .ok_or_else(|| "bound Align items are invalid".to_string())?
        .iter()
        .filter_map(|item| item["item_id"].as_str().map(str::to_owned))
        .collect();
    let selected = string_list(&input["align_item_ids"], "align_item_ids", true)?;
    if !selected.iter().all(|id| available.contains(id)) {
        return Err("align_item_ids must exist in the bound Align".into());
    }
    for id in &selected {
        let item = align["body"]["items"]
            .as_array()
            .unwrap()
            .iter()
            .find(|item| item["item_id"] == *id)
            .unwrap();
        if item["route"] != "goal-candidate" {
            return Err(format!("Align item is not routed as goal-candidate: {id}"));
        }
    }
    let points = input
        .get_mut("acceptance_points")
        .and_then(Value::as_array_mut)
        .ok_or_else(|| "acceptance_points must be an array".to_string())?;
    let mut seen = BTreeSet::new();
    for (index, point) in points.iter_mut().enumerate() {
        let object = as_object_mut(point, &format!("acceptance_points[{index}]"))?;
        let id = derived_id("point", &Value::Object(object.clone()));
        if !seen.insert(id.clone()) {
            return Err("Goal acceptance points must be semantically distinct".into());
        }
        object.insert("point_id".into(), Value::String(id));
    }
    let controls = input
        .get_mut("control_contracts")
        .and_then(Value::as_array_mut)
        .ok_or_else(|| "control_contracts must be an array".to_string())?;
    let mut seen = BTreeSet::new();
    for (index, control) in controls.iter_mut().enumerate() {
        let object = as_object_mut(control, &format!("control_contracts[{index}]"))?;
        let id = derived_id("control", &Value::Object(object.clone()));
        if !seen.insert(id.clone()) {
            return Err("Goal control contracts must be semantically distinct".into());
        }
        object.insert("control_id".into(), Value::String(id));
    }
    let status = derive_definition_status(&input, "frozen", "not-frozen")?;
    input.insert("status".into(), Value::String(status.into()));
    Ok(Value::Object(input))
}

fn build_plan(mut input: Map<String, Value>, options: &Options) -> Result<Value> {
    exact_keys(
        &input,
        &[
            "difference",
            "route",
            "operations",
            "parallel_groups",
            "blockers",
            "unknowns",
        ],
        "Plan input",
    )?;
    let goal = load_validated_self(Kind::Goal, require(&options.goal, "--goal")?)?;
    let point_ids: Vec<String> = goal["body"]["acceptance_points"]
        .as_array()
        .unwrap()
        .iter()
        .map(|point| point["point_id"].as_str().unwrap().to_owned())
        .collect();
    let point_set: BTreeSet<String> = point_ids.iter().cloned().collect();
    let control_ids: Vec<String> = goal["body"]["control_contracts"]
        .as_array()
        .unwrap()
        .iter()
        .map(|control| control["control_id"].as_str().unwrap().to_owned())
        .collect();
    let control_set: BTreeSet<String> = control_ids.iter().cloned().collect();
    let operations = input
        .get_mut("operations")
        .and_then(Value::as_array_mut)
        .ok_or_else(|| "operations must be an array".to_string())?;
    let mut ids = Vec::new();
    let mut cores = Vec::new();
    for (op_index, operation) in operations.iter().enumerate() {
        let op = as_object(operation, &format!("operations[{op_index}]"))?;
        exact_keys(
            op,
            &[
                "depends_on_indices",
                "satisfies",
                "controlled_by",
                "action_ref",
                "responsible_ref",
                "input_refs",
                "output_refs",
                "permission_refs",
                "resource_refs",
                "maximum_side_effects",
                "pre_checks",
                "post_checks",
                "idempotency",
                "retry_limit",
                "recovery",
            ],
            "operation input",
        )?;
        let satisfies = string_list(&operation["satisfies"], "satisfies", false)?;
        if !satisfies.iter().all(|id| point_set.contains(id)) {
            return Err("operation satisfies must reference bound Goal acceptance points".into());
        }
        let controlled_by = string_list(&operation["controlled_by"], "controlled_by", false)?;
        if !controlled_by.iter().all(|id| control_set.contains(id)) {
            return Err("operation controlled_by must reference bound Goal controls".into());
        }
        let mut core = op.clone();
        core.remove("depends_on_indices");
        let id = derived_id("op", &Value::Object(core.clone()));
        if ids.contains(&id) {
            return Err("Plan operations must be semantically distinct".into());
        }
        ids.push(id);
        cores.push(core);
    }
    let mut generated = Vec::new();
    for (op_index, operation) in operations.iter().enumerate() {
        let source = as_object(operation, "operation input")?;
        let indexes = integer_list(&source["depends_on_indices"], "depends_on_indices")?;
        if indexes.iter().any(|dependency| *dependency >= op_index) {
            return Err("depends_on_indices must reference earlier operations".into());
        }
        let dependencies: Vec<Value> = indexes
            .iter()
            .map(|index| Value::String(ids[*index].clone()))
            .collect();
        let mut output = cores[op_index].clone();
        output.insert("operation_id".into(), Value::String(ids[op_index].clone()));
        output.insert("depends_on".into(), Value::Array(dependencies));
        generated.push(Value::Object(output));
    }
    input.insert("operations".into(), Value::Array(generated.clone()));
    let groups = input
        .get_mut("parallel_groups")
        .and_then(Value::as_array_mut)
        .ok_or_else(|| "parallel_groups must be an array".to_string())?;
    let mut generated_groups = Vec::new();
    for group in groups.iter() {
        let object = as_object(group, "parallel_group input")?;
        exact_keys(
            object,
            &["operation_indices", "reason", "guards"],
            "parallel_group input",
        )?;
        let indexes = integer_list(&group["operation_indices"], "operation_indices")?;
        if indexes.iter().any(|index| *index >= ids.len()) {
            return Err("parallel operation index is out of range".into());
        }
        generated_groups.push(json!({
            "operation_ids": indexes.iter().map(|index| ids[*index].clone()).collect::<Vec<_>>(),
            "reason": group["reason"],
            "guards": group["guards"],
        }));
    }
    input.insert("parallel_groups".into(), Value::Array(generated_groups));
    let acceptance_coverage: Vec<Value> = point_ids
        .iter()
        .map(|point_id| {
            let operation_ids: Vec<String> = generated
                .iter()
                .filter(|operation| {
                    operation["satisfies"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .any(|value| value == point_id)
                })
                .map(|operation| operation["operation_id"].as_str().unwrap().to_owned())
                .collect();
            json!({"point_id": point_id, "operation_ids": operation_ids})
        })
        .collect();
    let control_coverage: Vec<Value> = control_ids
        .iter()
        .map(|control_id| {
            let operation_ids: Vec<String> = generated
                .iter()
                .filter(|operation| {
                    operation["controlled_by"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .any(|value| value == control_id)
                })
                .map(|operation| operation["operation_id"].as_str().unwrap().to_owned())
                .collect();
            json!({"control_id": control_id, "operation_ids": operation_ids})
        })
        .collect();
    input.insert(
        "coverage".into(),
        json!({
            "acceptance": acceptance_coverage,
            "controls": control_coverage,
        }),
    );
    let status = derive_definition_status(&input, "executable", "not-executable")?;
    input.insert("status".into(), Value::String(status.into()));
    Ok(Value::Object(input))
}

fn build_run(mut input: Map<String, Value>, options: &Options) -> Result<Value> {
    exact_keys(
        &input,
        &[
            "operation_results",
            "acceptance_results",
            "control_results",
            "budget_evidence_refs",
            "side_effect_evidence_refs",
            "stop_state",
            "resume_ref",
        ],
        "Run input",
    )?;
    let goal = load_validated_self(Kind::Goal, require(&options.goal, "--goal")?)?;
    let timing_by_control: BTreeMap<String, Value> = goal["body"]["control_contracts"]
        .as_array()
        .unwrap()
        .iter()
        .map(|control| {
            (
                control["control_id"].as_str().unwrap().to_owned(),
                control["check_timing"].clone(),
            )
        })
        .collect();
    let control_results = input
        .get_mut("control_results")
        .and_then(Value::as_array_mut)
        .ok_or_else(|| "control_results must be an array".to_string())?;
    for control_result in control_results {
        let object = as_object_mut(control_result, "control_result input")?;
        exact_keys(
            object,
            &[
                "control_id",
                "result",
                "actual_refs",
                "trace_refs",
                "comparison_refs",
                "evidence_refs",
            ],
            "control_result input",
        )?;
        let control_id = text(&object["control_id"], "control_id")?;
        let timing = timing_by_control
            .get(control_id)
            .ok_or_else(|| format!("control result is absent from supplied Goal: {control_id}"))?
            .clone();
        object.insert("required_check_timing".into(), timing);
    }
    let statuses: Vec<String> = input["operation_results"]
        .as_array()
        .into_iter()
        .flatten()
        .chain(input["acceptance_results"].as_array().into_iter().flatten())
        .chain(input["control_results"].as_array().into_iter().flatten())
        .filter_map(|result| result["result"].as_str().map(str::to_owned))
        .collect();
    let result = if statuses.iter().any(|status| status == "Finding") {
        "Finding"
    } else if statuses
        .iter()
        .any(|status| status == "unknown" || status == "not-run")
    {
        "unknown"
    } else {
        "pass"
    };
    input.insert("result".into(), Value::String(result.into()));
    Ok(Value::Object(input))
}

fn derive_definition_status(
    input: &Map<String, Value>,
    success: &'static str,
    blocked: &'static str,
) -> Result<&'static str> {
    let blockers = input["blockers"]
        .as_array()
        .ok_or_else(|| "blockers must be an array".to_string())?;
    let unknowns = input["unknowns"]
        .as_array()
        .ok_or_else(|| "unknowns must be an array".to_string())?;
    Ok(if !blockers.is_empty() {
        blocked
    } else if !unknowns.is_empty() {
        "unknown"
    } else {
        success
    })
}

fn validate_body(kind: Kind, body: &Value, bindings: &Value) -> Result<()> {
    match kind {
        Kind::Align => validate_align(body, bindings),
        Kind::Goal => validate_goal(body),
        Kind::Plan => validate_plan(body),
        Kind::Run => validate_run(body),
    }
}

fn validate_align(body: &Value, bindings: &Value) -> Result<()> {
    let object = as_object(body, "Align body")?;
    exact_keys(
        object,
        &[
            "subject",
            "boundary",
            "cutoff",
            "source_refs",
            "items",
            "status",
        ],
        "Align body",
    )?;
    for key in ["subject", "boundary", "cutoff"] {
        text(&body[key], key)?;
    }
    let sources: BTreeSet<String> = string_list(&body["source_refs"], "source_refs", true)?
        .into_iter()
        .collect();
    let items = array(&body["items"], "items", true)?;
    let mut ids = BTreeSet::new();
    let mut covered = BTreeSet::new();
    let mut has_run_use = false;
    let mut expected = "aligned";
    for (index, item) in items.iter().enumerate() {
        let label = format!("items[{index}]");
        let entry = as_object(item, &label)?;
        exact_keys(
            entry,
            &[
                "item_id",
                "state",
                "statement",
                "evidence_refs",
                "uses_run",
                "route",
                "route_ref",
            ],
            &label,
        )?;
        let id = text(&item["item_id"], "item_id")?;
        if !ids.insert(id.to_owned()) {
            return Err("item_id must be unique".into());
        }
        let mut source = entry.clone();
        source.remove("item_id");
        if id != derived_id("item", &Value::Object(source)) {
            return Err("item_id is not mechanically derived".into());
        }
        let state = choice(
            &item["state"],
            "state",
            &["aligned", "gap", "conflict", "unknown"],
        )?;
        if state == "unknown" {
            expected = "unknown";
        } else if expected != "unknown" && (state == "gap" || state == "conflict") {
            expected = "open";
        }
        text(&item["statement"], "statement")?;
        let evidence = string_list(&item["evidence_refs"], "evidence_refs", true)?;
        for reference in evidence {
            if !sources.contains(&reference) {
                return Err(format!("item evidence_ref is not declared: {reference}"));
            }
            covered.insert(reference);
        }
        let uses_run = item["uses_run"]
            .as_bool()
            .ok_or_else(|| "uses_run must be boolean".to_string())?;
        has_run_use |= uses_run;
        let route = choice(
            &item["route"],
            "route",
            &["none", "goal-candidate", "retain", "external"],
        )?;
        nullable_text(&item["route_ref"], "route_ref")?;
        if route == "external" && item["route_ref"].is_null() {
            return Err("external route requires route_ref".into());
        }
        if route != "external" && !item["route_ref"].is_null() {
            return Err("only external route accepts route_ref".into());
        }
    }
    if covered != sources {
        return Err("every declared source_ref must be used by an Align item".into());
    }
    let run_bound = !bindings["run"].is_null();
    if run_bound != has_run_use {
        return Err("Run binding and uses_run items disagree".into());
    }
    if body["status"] != expected {
        return Err("Align status is not mechanically derived".into());
    }
    Ok(())
}

fn validate_goal(body: &Value) -> Result<()> {
    let object = as_object(body, "Goal body")?;
    exact_keys(
        object,
        &[
            "align_item_ids",
            "objective",
            "target",
            "source_refs",
            "evidence_cutoff",
            "baseline_refs",
            "scope",
            "non_goals",
            "execution_envelope",
            "acceptance_points",
            "control_contracts",
            "blockers",
            "unknowns",
            "status",
        ],
        "Goal body",
    )?;
    string_list(&body["align_item_ids"], "align_item_ids", true)?;
    for key in ["objective", "target"] {
        text(&body[key], key)?;
    }
    for key in ["source_refs", "baseline_refs", "scope"] {
        string_list(&body[key], key, true)?;
    }
    let cutoff = as_object(&body["evidence_cutoff"], "evidence_cutoff")?;
    exact_keys(cutoff, &["at", "included_refs"], "evidence_cutoff")?;
    text(&body["evidence_cutoff"]["at"], "evidence_cutoff.at")?;
    string_list(
        &body["evidence_cutoff"]["included_refs"],
        "evidence_cutoff.included_refs",
        true,
    )?;
    string_list(&body["non_goals"], "non_goals", false)?;
    string_list(&body["blockers"], "blockers", false)?;
    string_list(&body["unknowns"], "unknowns", false)?;
    validate_execution_envelope(&body["execution_envelope"])?;
    let points = array(
        &body["acceptance_points"],
        "acceptance_points",
        body["status"] == "frozen",
    )?;
    let mut ids = BTreeSet::new();
    for (index, point) in points.iter().enumerate() {
        let label = format!("acceptance_points[{index}]");
        let entry = as_object(point, &label)?;
        exact_keys(
            entry,
            &[
                "point_id",
                "statement",
                "required_evidence",
                "judge",
                "acceptance",
            ],
            &label,
        )?;
        let id = text(&point["point_id"], "point_id")?;
        if !ids.insert(id.to_owned()) {
            return Err("point_id must be unique".into());
        }
        let mut source = entry.clone();
        source.remove("point_id");
        if id != derived_id("point", &Value::Object(source)) {
            return Err("point_id is not mechanically derived".into());
        }
        text(&point["statement"], "statement")?;
        string_list(&point["required_evidence"], "required_evidence", true)?;
        validate_judge(&point["judge"])?;
        validate_acceptance(&point["acceptance"])?;
    }
    let controls = array(&body["control_contracts"], "control_contracts", false)?;
    let mut ids = BTreeSet::new();
    for (index, control) in controls.iter().enumerate() {
        let label = format!("control_contracts[{index}]");
        let entry = as_object(control, &label)?;
        exact_keys(
            entry,
            &[
                "control_id",
                "statement",
                "required_evidence",
                "judge",
                "controlled_variable",
                "allowed_domain",
                "forbidden_drift",
                "required_trace",
                "check_method",
                "check_timing",
                "on_non_pass",
            ],
            &label,
        )?;
        let id = text(&control["control_id"], "control_id")?;
        if !ids.insert(id.to_owned()) {
            return Err("control_id must be unique".into());
        }
        let mut source = entry.clone();
        source.remove("control_id");
        if id != derived_id("control", &Value::Object(source)) {
            return Err("control_id is not mechanically derived".into());
        }
        for key in [
            "statement",
            "controlled_variable",
            "check_method",
            "on_non_pass",
        ] {
            text(&control[key], key)?;
        }
        string_list(&control["required_evidence"], "required_evidence", true)?;
        validate_judge(&control["judge"])?;
        string_list(&control["allowed_domain"], "allowed_domain", true)?;
        string_list(&control["forbidden_drift"], "forbidden_drift", true)?;
        string_list(&control["required_trace"], "required_trace", true)?;
        choice(
            &control["check_timing"],
            "check_timing",
            &["invariant", "terminal"],
        )?;
    }
    let expected = if !body["blockers"].as_array().unwrap().is_empty() {
        "not-frozen"
    } else if !body["unknowns"].as_array().unwrap().is_empty() {
        "unknown"
    } else {
        "frozen"
    };
    if body["status"] != expected {
        return Err("Goal status is not mechanically derived".into());
    }
    Ok(())
}

fn validate_execution_envelope(value: &Value) -> Result<()> {
    let object = as_object(value, "execution_envelope")?;
    exact_keys(
        object,
        &[
            "authorization_ref",
            "authorization_scope",
            "authorization_claim_limit",
            "resources",
            "budget",
            "maximum_side_effects",
            "stop_conditions",
            "incomplete_deliverable",
        ],
        "execution_envelope",
    )?;
    text(&value["authorization_ref"], "authorization_ref")?;
    text(&value["authorization_scope"], "authorization_scope")?;
    text(
        &value["authorization_claim_limit"],
        "authorization_claim_limit",
    )?;
    string_list(&value["resources"], "resources", true)?;
    text(&value["budget"], "budget")?;
    string_list(&value["maximum_side_effects"], "maximum_side_effects", true)?;
    let stops = as_object(&value["stop_conditions"], "stop_conditions")?;
    exact_keys(
        stops,
        &["completed", "paused", "failed", "cancelled"],
        "stop_conditions",
    )?;
    for key in ["completed", "paused", "failed", "cancelled"] {
        text(&value["stop_conditions"][key], key)?;
    }
    text(&value["incomplete_deliverable"], "incomplete_deliverable")?;
    Ok(())
}

fn validate_judge(value: &Value) -> Result<()> {
    let object = as_object(value, "judge")?;
    exact_keys(object, &["kind", "claim_limit"], "judge")?;
    choice(
        &value["kind"],
        "judge.kind",
        &["self", "independent-agent", "script", "human"],
    )?;
    text(&value["claim_limit"], "judge.claim_limit")?;
    Ok(())
}

fn validate_acceptance(value: &Value) -> Result<()> {
    let object = as_object(value, "acceptance")?;
    exact_keys(
        object,
        &[
            "observable",
            "conditions",
            "window",
            "expected",
            "falsifier",
            "comparison_method",
            "sampling_rule",
        ],
        "acceptance",
    )?;
    for key in [
        "observable",
        "window",
        "expected",
        "falsifier",
        "comparison_method",
        "sampling_rule",
    ] {
        text(&value[key], key)?;
    }
    string_list(&value["conditions"], "conditions", true)?;
    Ok(())
}

fn validate_plan(body: &Value) -> Result<()> {
    let object = as_object(body, "Plan body")?;
    exact_keys(
        object,
        &[
            "difference",
            "route",
            "operations",
            "coverage",
            "parallel_groups",
            "blockers",
            "unknowns",
            "status",
        ],
        "Plan body",
    )?;
    text(&body["difference"], "difference")?;
    let route = as_object(&body["route"], "route")?;
    exact_keys(
        route,
        &["claim", "supporting_refs", "counter_refs"],
        "route",
    )?;
    text(&body["route"]["claim"], "route.claim")?;
    string_list(
        &body["route"]["supporting_refs"],
        "route.supporting_refs",
        true,
    )?;
    string_list(&body["route"]["counter_refs"], "route.counter_refs", false)?;
    string_list(&body["blockers"], "blockers", false)?;
    string_list(&body["unknowns"], "unknowns", false)?;
    let operations = array(
        &body["operations"],
        "operations",
        body["status"] == "executable",
    )?;
    let mut operation_ids = BTreeSet::new();
    for (index, operation) in operations.iter().enumerate() {
        let label = format!("operations[{index}]");
        let entry = as_object(operation, &label)?;
        exact_keys(
            entry,
            &[
                "operation_id",
                "depends_on",
                "satisfies",
                "controlled_by",
                "action_ref",
                "responsible_ref",
                "input_refs",
                "output_refs",
                "permission_refs",
                "resource_refs",
                "maximum_side_effects",
                "pre_checks",
                "post_checks",
                "idempotency",
                "retry_limit",
                "recovery",
            ],
            &label,
        )?;
        let id = text(&operation["operation_id"], "operation_id")?.to_owned();
        if !operation_ids.insert(id.clone()) {
            return Err("operation_id must be unique".into());
        }
        let mut core = entry.clone();
        core.remove("operation_id");
        core.remove("depends_on");
        if id != derived_id("op", &Value::Object(core)) {
            return Err("operation_id is not mechanically derived".into());
        }
        string_list(&operation["depends_on"], "depends_on", false)?;
        string_list(&operation["satisfies"], "satisfies", false)?;
        string_list(&operation["controlled_by"], "controlled_by", false)?;
        for key in ["action_ref", "responsible_ref", "idempotency", "recovery"] {
            text(&operation[key], key)?;
        }
        for key in [
            "input_refs",
            "output_refs",
            "permission_refs",
            "resource_refs",
            "maximum_side_effects",
            "pre_checks",
            "post_checks",
        ] {
            string_list(&operation[key], key, true)?;
        }
        operation["retry_limit"]
            .as_u64()
            .ok_or_else(|| "retry_limit must be an unsigned integer".to_string())?;
    }
    for operation in operations {
        for dependency in string_list(&operation["depends_on"], "depends_on", false)? {
            if !operation_ids.contains(&dependency) {
                return Err("operation dependency must reference a Plan operation".into());
            }
        }
    }
    let operation_graph: BTreeMap<String, Vec<String>> = operations
        .iter()
        .map(|operation| {
            (
                operation["operation_id"].as_str().unwrap().to_owned(),
                operation["depends_on"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|dependency| dependency.as_str().unwrap().to_owned())
                    .collect(),
            )
        })
        .collect();
    let mut visiting = BTreeSet::new();
    let mut done = BTreeSet::new();
    for operation_id in &operation_ids {
        visit(
            operation_id,
            &operation_graph,
            &mut visiting,
            &mut done,
            "Plan operation graph must be acyclic",
        )?;
    }
    validate_coverage(
        &body["coverage"],
        operations,
        body["status"] == "executable",
    )?;
    validate_parallel_groups(&body["parallel_groups"], &operation_ids, &operation_graph)?;
    let expected = if !body["blockers"].as_array().unwrap().is_empty() {
        "not-executable"
    } else if !body["unknowns"].as_array().unwrap().is_empty() {
        "unknown"
    } else {
        "executable"
    };
    if body["status"] != expected {
        return Err("Plan status is not mechanically derived".into());
    }
    Ok(())
}

fn validate_coverage(value: &Value, operations: &[Value], require_complete: bool) -> Result<()> {
    let object = as_object(value, "coverage")?;
    exact_keys(object, &["acceptance", "controls"], "coverage")?;
    for (kind, id_key, operation_key) in [
        ("acceptance", "point_id", "satisfies"),
        ("controls", "control_id", "controlled_by"),
    ] {
        let entries = array(&value[kind], kind, false)?;
        let mut ids = BTreeSet::new();
        for entry in entries {
            let item = as_object(entry, kind)?;
            exact_keys(item, &[id_key, "operation_ids"], kind)?;
            let id = text(&entry[id_key], id_key)?;
            if !ids.insert(id.to_owned()) {
                return Err(format!("coverage {id_key} must be unique"));
            }
            let actual = string_list(&entry["operation_ids"], "operation_ids", require_complete)?;
            let expected: Vec<String> = operations
                .iter()
                .filter(|operation| {
                    operation[operation_key]
                        .as_array()
                        .unwrap()
                        .iter()
                        .any(|reference| reference == id)
                })
                .map(|operation| operation["operation_id"].as_str().unwrap().to_owned())
                .collect();
            if actual != expected {
                return Err(format!("coverage for {id} is not mechanically derived"));
            }
        }
    }
    Ok(())
}

fn visit(
    node: &str,
    graph: &BTreeMap<String, Vec<String>>,
    visiting: &mut BTreeSet<String>,
    done: &mut BTreeSet<String>,
    cycle_error: &str,
) -> Result<()> {
    if done.contains(node) {
        return Ok(());
    }
    if !visiting.insert(node.to_owned()) {
        return Err(cycle_error.into());
    }
    for next in graph.get(node).into_iter().flatten() {
        visit(next, graph, visiting, done, cycle_error)?;
    }
    visiting.remove(node);
    done.insert(node.to_owned());
    Ok(())
}

fn validate_parallel_groups(
    value: &Value,
    operations: &BTreeSet<String>,
    graph: &BTreeMap<String, Vec<String>>,
) -> Result<()> {
    for group in array(value, "parallel_groups", false)? {
        let object = as_object(group, "parallel_group")?;
        exact_keys(
            object,
            &["operation_ids", "reason", "guards"],
            "parallel_group",
        )?;
        let ids = string_list(&group["operation_ids"], "operation_ids", true)?;
        if ids.len() < 2 || !ids.iter().all(|id| operations.contains(id)) {
            return Err("parallel group requires at least two Plan operations".into());
        }
        for (index, left) in ids.iter().enumerate() {
            for right in ids.iter().skip(index + 1) {
                if reachable(left, right, graph) || reachable(right, left, graph) {
                    return Err("parallel operations must not have a dependency path".into());
                }
            }
        }
        text(&group["reason"], "parallel reason")?;
        string_list(&group["guards"], "parallel guards", true)?;
    }
    Ok(())
}

fn reachable(from: &str, to: &str, graph: &BTreeMap<String, Vec<String>>) -> bool {
    let mut pending = vec![from];
    let mut seen = BTreeSet::new();
    while let Some(current) = pending.pop() {
        if !seen.insert(current) {
            continue;
        }
        for next in graph.get(current).into_iter().flatten() {
            if next == to {
                return true;
            }
            pending.push(next);
        }
    }
    false
}

fn validate_run(body: &Value) -> Result<()> {
    let object = as_object(body, "Run body")?;
    exact_keys(
        object,
        &[
            "operation_results",
            "acceptance_results",
            "control_results",
            "budget_evidence_refs",
            "side_effect_evidence_refs",
            "stop_state",
            "resume_ref",
            "result",
        ],
        "Run body",
    )?;
    let operations = array(&body["operation_results"], "operation_results", true)?;
    let mut operation_ids = BTreeSet::new();
    for result in operations {
        let entry = as_object(result, "operation_result")?;
        exact_keys(
            entry,
            &[
                "operation_id",
                "result",
                "eligibility_refs",
                "actual_output_refs",
                "evidence_refs",
                "trace_refs",
            ],
            "operation_result",
        )?;
        let id = text(&result["operation_id"], "operation_id")?.to_owned();
        if !operation_ids.insert(id) {
            return Err("operation result must be unique".into());
        }
        let state = result_choice(&result["result"])?;
        string_list(
            &result["eligibility_refs"],
            "eligibility_refs",
            state != "not-run",
        )?;
        string_list(
            &result["actual_output_refs"],
            "actual_output_refs",
            state == "pass",
        )?;
        string_list(
            &result["evidence_refs"],
            "evidence_refs",
            state == "pass" || state == "Finding",
        )?;
        string_list(&result["trace_refs"], "trace_refs", state != "not-run")?;
    }
    let acceptance = array(&body["acceptance_results"], "acceptance_results", true)?;
    let mut point_ids = BTreeSet::new();
    for result in acceptance {
        let entry = as_object(result, "acceptance_result")?;
        exact_keys(
            entry,
            &[
                "point_id",
                "result",
                "actual_refs",
                "comparison_refs",
                "evidence_refs",
            ],
            "acceptance_result",
        )?;
        let id = text(&result["point_id"], "point_id")?.to_owned();
        if !point_ids.insert(id) {
            return Err("acceptance result must be unique".into());
        }
        let state = result_choice(&result["result"])?;
        string_list(&result["actual_refs"], "actual_refs", state == "pass")?;
        string_list(
            &result["comparison_refs"],
            "comparison_refs",
            state == "pass",
        )?;
        string_list(
            &result["evidence_refs"],
            "evidence_refs",
            state == "pass" || state == "Finding",
        )?;
    }
    let controls = array(&body["control_results"], "control_results", false)?;
    let mut control_ids = BTreeSet::new();
    for result in controls {
        let entry = as_object(result, "control_result")?;
        exact_keys(
            entry,
            &[
                "control_id",
                "result",
                "actual_refs",
                "trace_refs",
                "comparison_refs",
                "evidence_refs",
                "required_check_timing",
            ],
            "control_result",
        )?;
        let id = text(&result["control_id"], "control_id")?.to_owned();
        if !control_ids.insert(id) {
            return Err("control result must be unique".into());
        }
        let state = result_choice(&result["result"])?;
        choice(
            &result["required_check_timing"],
            "required_check_timing",
            &["invariant", "terminal"],
        )?;
        string_list(&result["actual_refs"], "actual_refs", state == "pass")?;
        string_list(&result["trace_refs"], "trace_refs", state != "not-run")?;
        string_list(
            &result["comparison_refs"],
            "comparison_refs",
            state == "pass",
        )?;
        string_list(
            &result["evidence_refs"],
            "evidence_refs",
            state == "pass" || state == "Finding",
        )?;
    }
    string_list(
        &body["budget_evidence_refs"],
        "budget_evidence_refs",
        body["result"] == "pass",
    )?;
    string_list(
        &body["side_effect_evidence_refs"],
        "side_effect_evidence_refs",
        body["result"] == "pass",
    )?;
    let stop = choice(
        &body["stop_state"],
        "stop_state",
        &["completed", "paused", "failed", "cancelled"],
    )?;
    nullable_text(&body["resume_ref"], "resume_ref")?;
    if stop == "completed" && !body["resume_ref"].is_null() {
        return Err("completed Run must have resume_ref=null".into());
    }
    if stop != "completed" && body["resume_ref"].is_null() {
        return Err("non-completed Run requires resume_ref".into());
    }
    let expected = aggregate_results(
        operations
            .iter()
            .chain(acceptance.iter())
            .chain(controls.iter()),
    )?;
    if body["result"] != expected {
        return Err("Run result is not mechanically derived".into());
    }
    if (expected == "pass") != (stop == "completed") {
        return Err("Run pass and completed stop_state must coincide".into());
    }
    Ok(())
}

fn aggregate_results<'a>(values: impl Iterator<Item = &'a Value>) -> Result<&'static str> {
    let mut unknown = false;
    for value in values {
        match result_choice(&value["result"])? {
            "Finding" => return Ok("Finding"),
            "unknown" | "not-run" => unknown = true,
            _ => {}
        }
    }
    Ok(if unknown { "unknown" } else { "pass" })
}

fn result_choice(value: &Value) -> Result<&str> {
    choice(value, "result", &["pass", "Finding", "unknown", "not-run"])
}

fn array<'a>(value: &'a Value, label: &str, nonempty: bool) -> Result<&'a Vec<Value>> {
    let array = value
        .as_array()
        .ok_or_else(|| format!("{label} must be an array"))?;
    if nonempty && array.is_empty() {
        return Err(format!("{label} must not be empty"));
    }
    Ok(array)
}

fn string_list(value: &Value, label: &str, nonempty: bool) -> Result<Vec<String>> {
    let array = array(value, label, nonempty)?;
    let mut result = Vec::new();
    let mut seen = BTreeSet::new();
    for item in array {
        let item = text(item, label)?.to_owned();
        if !seen.insert(item.clone()) {
            return Err(format!("{label} must not contain duplicates"));
        }
        result.push(item);
    }
    Ok(result)
}

fn integer_list(value: &Value, label: &str) -> Result<Vec<usize>> {
    let array = array(value, label, false)?;
    let mut result = Vec::new();
    let mut seen = BTreeSet::new();
    for item in array {
        let number = item
            .as_u64()
            .ok_or_else(|| format!("{label} must contain unsigned integers"))?
            as usize;
        if !seen.insert(number) {
            return Err(format!("{label} must not contain duplicates"));
        }
        result.push(number);
    }
    Ok(result)
}

fn text<'a>(value: &'a Value, label: &str) -> Result<&'a str> {
    let value = value
        .as_str()
        .ok_or_else(|| format!("{label} must be a string"))?;
    if value.trim().is_empty() {
        Err(format!("{label} must not be empty"))
    } else {
        Ok(value)
    }
}

fn nullable_text(value: &Value, label: &str) -> Result<()> {
    if value.is_null() {
        Ok(())
    } else {
        text(value, label).map(|_| ())
    }
}

fn choice<'a>(value: &'a Value, label: &str, allowed: &[&str]) -> Result<&'a str> {
    let value = text(value, label)?;
    if allowed.contains(&value) {
        Ok(value)
    } else {
        Err(format!("{label} must be one of {allowed:?}"))
    }
}

fn as_object<'a>(value: &'a Value, label: &str) -> Result<&'a Map<String, Value>> {
    value
        .as_object()
        .ok_or_else(|| format!("{label} must be an object"))
}

fn as_object_mut<'a>(value: &'a mut Value, label: &str) -> Result<&'a mut Map<String, Value>> {
    value
        .as_object_mut()
        .ok_or_else(|| format!("{label} must be an object"))
}

fn exact_keys(object: &Map<String, Value>, required: &[&str], label: &str) -> Result<()> {
    let actual: BTreeSet<&str> = object.keys().map(String::as_str).collect();
    let expected: BTreeSet<&str> = required.iter().copied().collect();
    if actual == expected {
        Ok(())
    } else {
        Err(format!(
            "{label} keys differ: expected={expected:?} actual={actual:?}"
        ))
    }
}

fn derived_id(prefix: &str, value: &Value) -> String {
    format!("{prefix}-{}", &sha256_value(value)[..16])
}

fn now_unix_ms() -> Result<u64> {
    let duration = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|error| format!("system clock is before UNIX epoch: {error}"))?;
    u64::try_from(duration.as_millis())
        .map_err(|_| "system time does not fit u64 milliseconds".into())
}

fn load_object(path: &Path, label: &str) -> Result<Map<String, Value>> {
    let bytes = fs::read(path)
        .map_err(|error| format!("cannot read {label} {}: {error}", path.display()))?;
    let value: Value = serde_json::from_slice(&bytes)
        .map_err(|error| format!("{label} is not valid JSON: {error}"))?;
    value
        .as_object()
        .cloned()
        .ok_or_else(|| format!("{label} must be an object"))
}

fn write_absent(path: &Path, value: &Value) -> Result<()> {
    let parent = path
        .parent()
        .ok_or_else(|| "output must have an existing parent directory".to_string())?;
    if !parent.is_dir() {
        return Err(format!(
            "output parent must already exist: {}",
            parent.display()
        ));
    }
    if path.exists() {
        return Err(format!("output must be absent: {}", path.display()));
    }
    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| "output file name must be valid UTF-8".to_string())?;
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|error| format!("system clock is before UNIX epoch: {error}"))?
        .as_nanos();
    let temporary = parent.join(format!(
        ".{file_name}.k4-{}-{nonce}.tmp",
        std::process::id()
    ));
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&temporary)
        .map_err(|error| format!("cannot create temporary output: {error}"))?;
    let write_result = file
        .write_all(canonical_bytes(value).as_slice())
        .and_then(|_| file.sync_all())
        .map_err(|error| format!("cannot write temporary output: {error}"));
    drop(file);
    if let Err(error) = write_result {
        let _ = fs::remove_file(&temporary);
        return Err(error);
    }
    if let Err(error) = fs::hard_link(&temporary, path) {
        let _ = fs::remove_file(&temporary);
        return Err(format!(
            "cannot atomically create absent output {}: {error}",
            path.display()
        ));
    }
    fs::remove_file(&temporary)
        .map_err(|error| format!("output created but temporary link cleanup failed: {error}"))
}

fn canonical_string(value: &Value) -> String {
    serde_json::to_string(value).expect("JSON Value serialization cannot fail")
}

fn canonical_bytes(value: &Value) -> Vec<u8> {
    let mut bytes = serde_json::to_vec_pretty(value).expect("JSON Value serialization cannot fail");
    bytes.push(b'\n');
    bytes
}

fn sha256_value(value: &Value) -> String {
    sha256_bytes(&canonical_bytes(value))
}

fn sha256_file(path: &Path) -> Result<String> {
    fs::read(path)
        .map(|bytes| sha256_bytes(&bytes))
        .map_err(|error| format!("cannot hash {}: {error}", path.display()))
}

fn sha256_bytes(bytes: &[u8]) -> String {
    let mut context = Context::new(&SHA256);
    context.update(bytes);
    context
        .finish()
        .as_ref()
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}
