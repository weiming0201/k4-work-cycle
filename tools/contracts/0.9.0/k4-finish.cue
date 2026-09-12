package k4_finish

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"list"
	"strings"
)

context: _

#Text:        string & !=""
#Digest:      string & =~"^[0-9a-f]{64}$"
#ItemID:      string & =~"^item-[0-9a-f]{16}$"
#OperationID: string & =~"^op-[0-9a-f]{16}$"
#Result:      "pass" | "fail"
#Strings: [...#Text] & list.UniqueItems()
#NonEmptyStrings: [#Text, ...#Text] & list.UniqueItems()
#Binding: close({
	ref:            #Text
	sha256:         #Digest
	content_sha256: #Digest
})
#Finding: close({
	statement:     #Text
	evidence_refs: #NonEmptyStrings
})
#Unknown: close({
	statement:  #Text
	basis_refs: #NonEmptyStrings
})
#ItemCore: close({
	lens:           #Text
	epistemic_kind: "fact" | "source-statement" | "inference" | "preference" | "unknown"
	state:          "aligned" | "gap" | "conflict" | "unknown"
	statement:      #Text
	evidence_refs:  #NonEmptyStrings
	route:          "none" | "goal-candidate" | "retain" | "external"
	route_ref:      null | #Text
})
#ItemInput: close({
	lens:             #ItemCore.lens
	change:           "retained" | "changed" | "added"
	previous_item_id: null | #ItemID
	change_reason:    #Text
	epistemic_kind:   #ItemCore.epistemic_kind
	state:            #ItemCore.state
	statement:        #ItemCore.statement
	evidence_refs:    #ItemCore.evidence_refs
	route:            #ItemCore.route
	route_ref:        #ItemCore.route_ref
})
#Item: close({
	item_id:          #ItemID
	lens:             #ItemCore.lens
	change:           "retained" | "changed" | "added"
	previous_item_id: null | #ItemID
	change_reason:    #Text
	epistemic_kind:   #ItemCore.epistemic_kind
	state:            #ItemCore.state
	statement:        #ItemCore.statement
	evidence_refs:    #ItemCore.evidence_refs
	route:            #ItemCore.route
	route_ref:        #ItemCore.route_ref
})
#Retired: close({
	previous_item_id: #ItemID
	reason:           #Text
	evidence_refs:    #NonEmptyStrings
})
#Delta: close({
	summary:       #Text
	evidence_refs: #NonEmptyStrings
})
#DeltaInput: close({summary: #Text})
#LensIndex: close({
	lens: #Text
	item_ids: [#ItemID, ...#ItemID] & list.UniqueItems()
})
#Account: close({
	revision:    uint
	subject:     #Text
	boundary:    #Text
	cutoff:      #Text
	source_refs: #NonEmptyStrings
	lenses:      #NonEmptyStrings
	lens_index: [...#LensIndex]
	delta: #Delta
	items: [#Item, ...#Item]
	retired: [...#Retired]
})
#Judge: close({
	kind:        "self" | "independent-agent" | "script" | "human"
	ref:         #Text
	claim_limit: #Text
})
#JudgmentInput: close({
	id:            #Text
	result:        #Result
	actual_refs:   #NonEmptyStrings
	evidence_refs: #NonEmptyStrings
	unknowns: [...#Unknown]
})
#Judgment: close({
	id:                  #Text
	judge:               #Judge
	comparison_contract: _
	result:              #Result
	actual_refs:         #NonEmptyStrings
	evidence_refs:       #NonEmptyStrings
	unknowns: [...#Unknown]
})
#Disposition: close({
	state:     "placed" | "pending" | "none"
	statement: #Text
	refs:      #Strings
})
#Incomplete: close({
	statement: #Text
	refs:      #NonEmptyStrings
})
#ClosureAction: close({
	action_key:         #Text
	kind:               "verify" | "cleanup" | "release" | "rollback" | "compensate" | "package"
	authorized_by:      #NonEmptyStrings
	result:             #Result
	actual_refs:        #Strings
	evidence_refs:      #NonEmptyStrings
	actual_effect_refs: #Strings
	findings: [...#Finding]
	unknowns: [...#Unknown]
})
#Attribution: close({
	stage:         "observe" | "goal" | "plan" | "run" | "finish"
	statement:     #Text
	evidence_refs: #NonEmptyStrings
	claim_limit:   #Text
})
#ResidualEffect: close({
	statement:       #Text
	state:           #Text
	refs:            #NonEmptyStrings
	responsible_ref: #Text
})
#ClosureFinding: close({
	origin:        "operation" | "emergency-patch"
	origin_ref:    #Text
	statement:     #Text
	evidence_refs: #NonEmptyStrings
})
#ClosureUnknown: close({
	origin:     "operation" | "emergency-patch" | "acceptance" | "terminal-control"
	origin_ref: #Text
	statement:  #Text
	basis_refs: #NonEmptyStrings
})
#OperationSummary: close({
	planned:           uint
	actual:            uint
	not_run:           uint
	passed:            uint
	failed:            uint
	emergency_patches: uint
	findings:          uint
	unknowns:          uint
})
#AbortSummary: close({
	source_ref:                  #Text
	reason:                      #Text
	evidence_refs:               #NonEmptyStrings
	response_mode:               "preserve-only" | "route"
	planned_response_operations: uint
	actual_response_operations:  uint
	passed_response_operations:  uint
	failed_response_operations:  uint
	residual_effect_refs:        #NonEmptyStrings
})
#Closure: close({
	acceptance_results: [#Judgment, ...#Judgment]
	terminal_control_results: [...#Judgment]
	closure_source_refs: #Strings
	closure_actions: [...#ClosureAction]
	attributions: [...#Attribution]
	residual_effects: [...#ResidualEffect]
	attempt_result:    #Result
	operation_summary: #OperationSummary
	findings: [...#ClosureFinding]
	unknowns: [...#ClosureUnknown]
	run_halt: close({
		trigger:    "plan-complete" | "abort"
		resume_ref: null | #Text
		abort:      null | #AbortSummary
	})
	result_disposition:     #Disposition
	incomplete_deliverable: null | #Incomplete
	run_log_ref:            #Text
	run_head_event_sha256:  #Digest
})
#Document: close({
	account: #Account
	closure: #Closure
})
#Envelope: close({
	schema:            "k4-finish-document/v5"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: close({
		previous_account: #Binding
		goal:             #Binding
		plan:             #Binding
		run:              #Binding
	})
	document: #Document
})
#AccountEnvelope: {
	schema:            "k4-observe-document/v3"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {...}
	document: {account: #Account, ...}
}
#GoalEnvelope: {
	schema:            "k4-goal-document/v7"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {observe: #Binding, ...}
	document: {
		status: "frozen"
		execution_envelope: {
			authorization_ref:    #Text
			permission_refs:      #NonEmptyStrings
			maximum_side_effects: #NonEmptyStrings
			...
		}
		acceptance_points: [{point_id: #Text, judge: #Judge, acceptance: _, ...}, ...]
		control_contracts: [...{control_id: #Text, check_timing: "invariant" | "terminal", judge: #Judge, ...}]
		...
	}
}
#PlanEnvelope: {
	schema:            "k4-plan-document/v8"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {goal: #Binding, ...}
	document: {
		status: "executable"
		on_abort: {mode: "preserve-only" | "route", ...}
		operations: [{operation_id: #OperationID, phase: "normal" | "abort", ...}, ...]
		...
	}
}
#RunEnvelope: {
	schema:            "k4-run-projection/v7"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {goal: #Binding, plan: #Binding, ...}
	document: {
		halted:                   true
		event_count:              uint & >0
		ledger_head_event_sha256: #Digest
		topology_status:          "plan-complete" | "abort"
		abort_confirmation: null | close({source_ref: #Text, reason: #Text, evidence_refs: #NonEmptyStrings, ...})
		halt: close({
			trigger:                   "plan-complete" | "abort"
			side_effect_evidence_refs: #Strings
			resume_ref:                null | #Text
			...
		})
		operations: [{operation_id: #OperationID, local_result: #Result | "not-run", ...}, ...]
		operation_results: [...{operation_id: #OperationID, local_result: #Result, findings: [...#Finding], unknowns: [...#Unknown], ...}]
		emergency_patches: [...{operation_id: #OperationID, findings: [...#Finding], unknowns: [...#Unknown], ...}]
		invariant_control_results: [...{control_id: #Text, result: #Result, ...}]
		...
	}
}
#Bound: close({
	binding: #Binding
	value:   _
})
#Input: close({
	cutoff: #Text
	delta:  #DeltaInput
	items: [#ItemInput, ...#ItemInput]
	retired: [...#Retired]
	acceptance_results: [#JudgmentInput, ...#JudgmentInput]
	terminal_control_results: [...#JudgmentInput]
	closure_actions: *[] | [...#ClosureAction]
	attributions: *[] | [...#Attribution]
	residual_effects: *[] | [...#ResidualEffect]
	result_disposition:     #Disposition
	incomplete_deliverable: null | #Incomplete
})

_input: #Input & context.input
_previous: #Bound & context.bindings.previous_account & {value: #AccountEnvelope}
_goal: #Bound & context.bindings.goal & {value: #GoalEnvelope}
_plan: #Bound & context.bindings.plan & {value: #PlanEnvelope}
_run: #Bound & context.bindings.run & {value: #RunEnvelope}
_bindings: close({
	previous_account: _previous.binding
	goal:             _goal.binding
	plan:             _plan.binding
	run:              _run.binding
})

_generatedItems: [for item in _input.items {
	_core: close({
		lens:           item.lens
		epistemic_kind: item.epistemic_kind
		state:          item.state
		statement:      item.statement
		evidence_refs:  item.evidence_refs
		route:          item.route
		route_ref:      item.route_ref
	})
	close({
		item_id:          "item-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(_core))), 0, 16))"
		lens:             item.lens
		change:           item.change
		previous_item_id: item.previous_item_id
		change_reason:    item.change_reason
		epistemic_kind:   item.epistemic_kind
		state:            item.state
		statement:        item.statement
		evidence_refs:    item.evidence_refs
		route:            item.route
		route_ref:        item.route_ref
	})
}]
_itemIDs: [for item in _generatedItems {item.item_id}]
_previousIDs: [for item in _previous.value.document.account.items {item.item_id}]
_usedPrevious: list.Concat([
	[for item in _generatedItems if item.previous_item_id != null {item.previous_item_id}],
	[for item in _input.retired {item.previous_item_id}],
])
_lensIndex: [for lensName in _previous.value.document.account.lenses {close({
	lens: lensName
	item_ids: [for item in _generatedItems if item.lens == lensName {item.item_id}]
})
}]
_goalPointIDs: [for point in _goal.value.document.acceptance_points {point.point_id}]
_goalPointByID: {for point in _goal.value.document.acceptance_points {(point.point_id): point}}
_inputPointIDs: [for result in _input.acceptance_results {result.id}]
_terminalControlIDs: [for control in _goal.value.document.control_contracts if control.check_timing == "terminal" {control.control_id}]
_terminalControlByID: {for control in _goal.value.document.control_contracts if control.check_timing == "terminal" {(control.control_id): control}}
_inputTerminalIDs: [for result in _input.terminal_control_results {result.id}]
_planOperationIDs: [for operation in _plan.value.document.operations {operation.operation_id}]
_runOperationIDs: [for operation in _run.value.document.operations {operation.operation_id}]

_acceptanceResults: [for judgment in _input.acceptance_results {close({
	id:                  judgment.id
	judge:               _goalPointByID[judgment.id].judge
	comparison_contract: _goalPointByID[judgment.id].acceptance
	result:              judgment.result
	actual_refs:         judgment.actual_refs
	evidence_refs:       judgment.evidence_refs
	unknowns:            judgment.unknowns
})
}]
_terminalControlResults: [for judgment in _input.terminal_control_results {
	_control: _terminalControlByID[judgment.id]
	close({
		id:    judgment.id
		judge: _control.judge
		comparison_contract: close({
			controlled_variable: _control.controlled_variable
			allowed_domain:      _control.allowed_domain
			forbidden_drift:     _control.forbidden_drift
			required_trace:      _control.required_trace
			check_method:        _control.check_method
			check_timing:        _control.check_timing
		})
		result:        judgment.result
		actual_refs:   judgment.actual_refs
		evidence_refs: judgment.evidence_refs
		unknowns:      judgment.unknowns
	})
}]

_operationFindings: list.Concat([for result in _run.value.document.operation_results {
	[for finding in result.findings {close({
		origin:        "operation"
		origin_ref:    result.operation_id
		statement:     finding.statement
		evidence_refs: finding.evidence_refs
	})
	}]
}])
_patchFindings: list.Concat([for patch in _run.value.document.emergency_patches {
	[for finding in patch.findings {close({
		origin:        "emergency-patch"
		origin_ref:    patch.operation_id
		statement:     finding.statement
		evidence_refs: finding.evidence_refs
	})
	}]
}])
_findings: list.Concat([_operationFindings, _patchFindings])
_operationUnknowns: list.Concat([for result in _run.value.document.operation_results {
	[for unknown in result.unknowns {close({
		origin:     "operation"
		origin_ref: result.operation_id
		statement:  unknown.statement
		basis_refs: unknown.basis_refs
	})
	}]
}])
_patchUnknowns: list.Concat([for patch in _run.value.document.emergency_patches {
	[for unknown in patch.unknowns {close({
		origin:     "emergency-patch"
		origin_ref: patch.operation_id
		statement:  unknown.statement
		basis_refs: unknown.basis_refs
	})
	}]
}])
_acceptanceUnknowns: list.Concat([for result in _input.acceptance_results {
	[for unknown in result.unknowns {close({
		origin:     "acceptance"
		origin_ref: result.id
		statement:  unknown.statement
		basis_refs: unknown.basis_refs
	})
	}]
}])
_terminalUnknowns: list.Concat([for result in _input.terminal_control_results {
	[for unknown in result.unknowns {close({
		origin:     "terminal-control"
		origin_ref: result.id
		statement:  unknown.statement
		basis_refs: unknown.basis_refs
	})
	}]
}])
_unknowns: list.Concat([_operationUnknowns, _patchUnknowns, _acceptanceUnknowns, _terminalUnknowns])

_actualOperations: [for operation in _run.value.document.operations if operation.local_result != "not-run" {operation}]
_notRunOperations: [for operation in _run.value.document.operations if operation.local_result == "not-run" {operation}]
_passedOperations: [for operation in _run.value.document.operations if operation.local_result == "pass" {operation}]
_failedOperations: [for operation in _run.value.document.operations if operation.local_result == "fail" {operation}]
_abortOperations: [for operation in _run.value.document.operations if operation.phase == "abort" {operation}]
_actualAbortOperations: [for operation in _abortOperations if operation.local_result != "not-run" {operation}]
_passedAbortOperations: [for operation in _abortOperations if operation.local_result == "pass" {operation}]
_failedAbortOperations: [for operation in _abortOperations if operation.local_result == "fail" {operation}]
_abortSummary: null | #AbortSummary
_abortEvidenceRefs: [...#Text]
if _run.value.document.halt.trigger == "plan-complete" {
	_abortSummary: null
	_abortEvidenceRefs: []
}
if _run.value.document.halt.trigger == "abort" {
	_abortEvidenceRefs: list.Concat([
		_run.value.document.abort_confirmation.evidence_refs,
		_run.value.document.halt.evidence_refs,
		_run.value.document.halt.budget_evidence_refs,
		_run.value.document.halt.side_effect_evidence_refs,
	])
	_abortSummary: close({
		source_ref:                  _run.value.document.abort_confirmation.source_ref
		reason:                      _run.value.document.abort_confirmation.reason
		evidence_refs:               _run.value.document.abort_confirmation.evidence_refs
		response_mode:               _plan.value.document.on_abort.mode
		planned_response_operations: len(_abortOperations)
		actual_response_operations:  len(_actualAbortOperations)
		passed_response_operations:  len(_passedAbortOperations)
		failed_response_operations:  len(_failedAbortOperations)
		residual_effect_refs:        _run.value.document.halt.side_effect_evidence_refs
	})
}
_allAcceptancePass: len([for result in _acceptanceResults if result.result == "fail" {result}]) == 0
_allTerminalPass: len([for result in _terminalControlResults if result.result == "fail" {result}]) == 0
_allInvariantPass: len([for result in _run.value.document.invariant_control_results if result.result == "fail" {result}]) == 0
_attemptResult: *"fail" | "pass"
if _run.value.document.halt.trigger == "plan-complete" && _allAcceptancePass && _allTerminalPass && _allInvariantPass {
	_attemptResult: "pass"
}

_accountEvidenceRaw: list.Concat(list.Concat([
	[for item in _generatedItems {item.evidence_refs}],
	[for item in _input.retired {item.evidence_refs}],
]))
_accountSourceRefs: [for index, ref in _accountEvidenceRaw if len([for priorIndex, priorRef in _accountEvidenceRaw if priorIndex < index && priorRef == ref {priorRef}]) == 0 {ref}]
_closureEvidenceRaw: list.Concat(list.Concat([
	[for result in _acceptanceResults {result.evidence_refs}],
	[for result in _terminalControlResults {result.evidence_refs}],
	[for finding in _findings {finding.evidence_refs}],
	[for unknown in _unknowns {unknown.basis_refs}],
	[for action in _input.closure_actions {action.authorized_by}],
	[for action in _input.closure_actions {action.actual_refs}],
	[for action in _input.closure_actions {action.evidence_refs}],
	[for action in _input.closure_actions {action.actual_effect_refs}],
	[for action in _input.closure_actions {list.Concat([for finding in action.findings {finding.evidence_refs}])}],
	[for action in _input.closure_actions {list.Concat([for unknown in action.unknowns {unknown.basis_refs}])}],
	[for attribution in _input.attributions {attribution.evidence_refs}],
	[for effect in _input.residual_effects {effect.refs}],
	[_abortEvidenceRefs],
]))
_closureSourceRefs: [for index, ref in _closureEvidenceRaw if len([for priorIndex, priorRef in _closureEvidenceRaw if priorIndex < index && priorRef == ref {priorRef}]) == 0 {ref}]
_changeEvidence: list.Concat(list.Concat([
	[for item in _generatedItems if item.change != "retained" {item.evidence_refs}],
	[for item in _input.retired {item.evidence_refs}],
]))
_deltaEvidence: [for index, ref in _changeEvidence if len([for priorIndex, priorRef in _changeEvidence if priorIndex < index && priorRef == ref {priorRef}]) == 0 {ref}]
_delta: #Delta & {summary: _input.delta.summary, evidence_refs: _deltaEvidence}

_generateChecks: {
	_itemIDsUnique:  list.UniqueItems(_itemIDs) & true
	_usedUnique:     list.UniqueItems(_usedPrevious) & true
	_pointsUnique:   list.UniqueItems(_inputPointIDs) & true
	_terminalUnique: list.UniqueItems(_inputTerminalIDs) & true
	if _goal.value.bindings.observe != _previous.binding {_invalid: error("contract relation rejected: _goal.value.bindings.observe != _previous.binding")}
	if _plan.value.bindings.goal != _goal.binding {_invalid: error("contract relation rejected: _plan.value.bindings.goal != _goal.binding")}
	if _run.value.bindings.goal != _goal.binding {_invalid: error("contract relation rejected: _run.value.bindings.goal != _goal.binding")}
	if _run.value.bindings.plan != _plan.binding {_invalid: error("contract relation rejected: _run.value.bindings.plan != _plan.binding")}
	if _runOperationIDs != _planOperationIDs {_invalid: error("contract relation rejected: _runOperationIDs != _planOperationIDs")}
	if len(_usedPrevious) != len(_previousIDs) {_invalid: error("contract relation rejected: len(_usedPrevious) != len(_previousIDs)")}
	for previousID in _previousIDs {
		if !list.Contains(_usedPrevious, previousID) {_invalid: error("contract relation rejected: !list.Contains(_usedPrevious, previousID)")}
	}
	for item in _generatedItems {
		if !list.Contains(_previous.value.document.account.lenses, item.lens) {_invalid: error("closing item lens must already exist in the opening Account")}
		if item.route == "goal-candidate" {_invalid: error("contract relation rejected: item.route == \"goal-candidate\"")}
		if item.route == "external" && item.route_ref == null {_invalid: error("contract relation rejected: item.route == \"external\" && item.route_ref == null")}
		if item.route != "external" && item.route_ref != null {_invalid: error("contract relation rejected: item.route != \"external\" && item.route_ref != null")}
		if item.change == "added" && item.previous_item_id != null {_invalid: error("contract relation rejected: item.change == \"added\" && item.previous_item_id != null")}
		if item.change != "added" && item.previous_item_id == null {_invalid: error("contract relation rejected: item.change != \"added\" && item.previous_item_id == null")}
		if item.previous_item_id != null {
			if !list.Contains(_previousIDs, item.previous_item_id) {_invalid: error("contract relation rejected: !list.Contains(_previousIDs, item.previous_item_id)")}
			if item.change == "retained" && item.item_id != item.previous_item_id {_invalid: error("contract relation rejected: item.change == \"retained\" && item.item_id != item.previous_item_id")}
			if item.change == "changed" && item.item_id == item.previous_item_id {_invalid: error("contract relation rejected: item.change == \"changed\" && item.item_id == item.previous_item_id")}
		}
		for ref in item.evidence_refs {
			if !list.Contains(_accountSourceRefs, ref) {_invalid: error("item evidence must be present in derived Account sources")}
		}
		if item.change != "retained" {
			if len([for ref in item.evidence_refs if list.Contains(_deltaEvidence, ref) {ref}]) == 0 {_invalid: error("changed item evidence must be present in the derived Account delta")}
		}
	}
	for lens in _previous.value.document.account.lenses {
		if len([for item in _generatedItems if item.lens == lens {item}]) == 0 {_invalid: error("contract relation rejected: len([for item in _generatedItems if item.lens == lens {item}]) == 0")}
	}
	for retired in _input.retired {
		if !list.Contains(_previousIDs, retired.previous_item_id) {_invalid: error("contract relation rejected: !list.Contains(_previousIDs, retired.previous_item_id)")}
		for ref in retired.evidence_refs {
			if !list.Contains(_accountSourceRefs, ref) {_invalid: error("retirement evidence must be present in derived Account sources")}
			if !list.Contains(_deltaEvidence, ref) {_invalid: error("retirement evidence must be present in the derived Account delta")}
		}
	}
	for result in list.Concat([_input.acceptance_results, _input.terminal_control_results]) {
		for ref in result.evidence_refs {
			if !list.Contains(_closureSourceRefs, ref) {_invalid: error("judgment evidence must be present in derived closure sources")}
		}
		for unknown in result.unknowns {
			for ref in unknown.basis_refs {
				if !list.Contains(_closureSourceRefs, ref) {_invalid: error("judgment unknown evidence must be present in derived closure sources")}
			}
		}
	}
	for finding in _findings {
		for ref in finding.evidence_refs {
			if !list.Contains(_closureSourceRefs, ref) {_invalid: error("Run finding evidence must be present in derived closure sources")}
		}
	}
	for unknown in list.Concat([_operationUnknowns, _patchUnknowns]) {
		for ref in unknown.basis_refs {
			if !list.Contains(_closureSourceRefs, ref) {_invalid: error("Run unknown evidence must be present in derived closure sources")}
		}
	}
	for ref in _abortEvidenceRefs {
		if !list.Contains(_closureSourceRefs, ref) {_invalid: error("abort evidence must be present in derived closure sources")}
	}
	for action in _input.closure_actions {
		for ref in action.authorized_by {
			if ref != _goal.value.document.execution_envelope.authorization_ref && !list.Contains(_goal.value.document.execution_envelope.permission_refs, ref) {_invalid: error("closure action authority must be present in the Goal execution envelope")}
		}
		for ref in action.actual_effect_refs {
			if !list.Contains(_goal.value.document.execution_envelope.maximum_side_effects, ref) {_invalid: error("closure action effect must be present in the Goal maximum side effects")}
		}
	}
	if len(_inputPointIDs) != len(_goalPointIDs) {_invalid: error("contract relation rejected: len(_inputPointIDs) != len(_goalPointIDs)")}
	for id in _goalPointIDs {
		if !list.Contains(_inputPointIDs, id) {_invalid: error("contract relation rejected: !list.Contains(_inputPointIDs, id)")}
	}
	if len(_inputTerminalIDs) != len(_terminalControlIDs) {_invalid: error("contract relation rejected: len(_inputTerminalIDs) != len(_terminalControlIDs)")}
	for id in _terminalControlIDs {
		if !list.Contains(_inputTerminalIDs, id) {_invalid: error("contract relation rejected: !list.Contains(_inputTerminalIDs, id)")}
	}
	if _attemptResult == "pass" && _input.incomplete_deliverable != null {_invalid: error("contract relation rejected: _attemptResult == \"pass\" && _input.incomplete_deliverable != null")}
	if _attemptResult == "fail" && _input.incomplete_deliverable == null {_invalid: error("contract relation rejected: _attemptResult == \"fail\" && _input.incomplete_deliverable == null")}
}

_document: #Document & {
	account: {
		revision:    _previous.value.document.account.revision + 1
		subject:     _previous.value.document.account.subject
		boundary:    _previous.value.document.account.boundary
		cutoff:      _input.cutoff
		source_refs: _accountSourceRefs
		lenses:      _previous.value.document.account.lenses
		lens_index:  _lensIndex
		delta:       _delta
		items:       _generatedItems
		retired:     _input.retired
	}
	closure: {
		acceptance_results:       _acceptanceResults
		terminal_control_results: _terminalControlResults
		closure_source_refs:      _closureSourceRefs
		closure_actions:          _input.closure_actions
		attributions:             _input.attributions
		residual_effects:         _input.residual_effects
		attempt_result:           _attemptResult
		operation_summary: {
			planned:           len(_planOperationIDs)
			actual:            len(_actualOperations)
			not_run:           len(_notRunOperations)
			passed:            len(_passedOperations)
			failed:            len(_failedOperations)
			emergency_patches: len(_run.value.document.emergency_patches)
			findings:          len(_findings)
			unknowns:          len(_unknowns)
		}
		findings: _findings
		unknowns: _unknowns
		run_halt: {
			trigger:    _run.value.document.halt.trigger
			resume_ref: _run.value.document.halt.resume_ref
			abort:      _abortSummary
		}
		result_disposition:     _input.result_disposition
		incomplete_deliverable: _input.incomplete_deliverable
		run_log_ref:            _run.binding.ref
		run_head_event_sha256:  _run.value.document.ledger_head_event_sha256
	}
}

generate: _generateChecks & close({
	schema:   "k4-finish-document/v5"
	bindings: _bindings
	document: _document
})

_existing: #Envelope & context.existing & {bindings: _bindings}
_existingItems: _existing.document.account.items
_existingItemIDs: [for item in _existingItems {item.item_id}]
_expectedExistingItemIDs: [for item in _existingItems {
	"item-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(close({
		lens:           item.lens
		epistemic_kind: item.epistemic_kind
		state:          item.state
		statement:      item.statement
		evidence_refs:  item.evidence_refs
		route:          item.route
		route_ref:      item.route_ref
	})))), 0, 16))"
}]
_existingPreviousIDs: [for item in _previous.value.document.account.items {item.item_id}]
_existingUsedPrevious: list.Concat([
	[for item in _existingItems if item.previous_item_id != null {item.previous_item_id}],
	[for item in _existing.document.account.retired {item.previous_item_id}],
])
_expectedExistingLensIndex: [for lensName in _existing.document.account.lenses {close({
	lens: lensName
	item_ids: [for item in _existingItems if item.lens == lensName {item.item_id}]
})
}]
_existingPointIDs: [for result in _existing.document.closure.acceptance_results {result.id}]
_existingTerminalIDs: [for result in _existing.document.closure.terminal_control_results {result.id}]
_existingAcceptanceUnknowns: list.Concat([for result in _existing.document.closure.acceptance_results {
	[for unknown in result.unknowns {close({
		origin:     "acceptance"
		origin_ref: result.id
		statement:  unknown.statement
		basis_refs: unknown.basis_refs
	})
	}]
}])
_existingTerminalUnknowns: list.Concat([for result in _existing.document.closure.terminal_control_results {
	[for unknown in result.unknowns {close({
		origin:     "terminal-control"
		origin_ref: result.id
		statement:  unknown.statement
		basis_refs: unknown.basis_refs
	})
	}]
}])
_expectedExistingUnknowns: list.Concat([_operationUnknowns, _patchUnknowns, _existingAcceptanceUnknowns, _existingTerminalUnknowns])
_existingAccountEvidenceRaw: list.Concat(list.Concat([
	[for item in _existingItems {item.evidence_refs}],
	[for item in _existing.document.account.retired {item.evidence_refs}],
]))
_expectedExistingAccountSources: [for index, ref in _existingAccountEvidenceRaw if len([for priorIndex, priorRef in _existingAccountEvidenceRaw if priorIndex < index && priorRef == ref {priorRef}]) == 0 {ref}]
_existingClosureEvidenceRaw: list.Concat(list.Concat([
	[for result in _existing.document.closure.acceptance_results {result.evidence_refs}],
	[for result in _existing.document.closure.terminal_control_results {result.evidence_refs}],
	[for finding in _existing.document.closure.findings {finding.evidence_refs}],
	[for unknown in _existing.document.closure.unknowns {unknown.basis_refs}],
	[for action in _existing.document.closure.closure_actions {action.authorized_by}],
	[for action in _existing.document.closure.closure_actions {action.actual_refs}],
	[for action in _existing.document.closure.closure_actions {action.evidence_refs}],
	[for action in _existing.document.closure.closure_actions {action.actual_effect_refs}],
	[for action in _existing.document.closure.closure_actions {list.Concat([for finding in action.findings {finding.evidence_refs}])}],
	[for action in _existing.document.closure.closure_actions {list.Concat([for unknown in action.unknowns {unknown.basis_refs}])}],
	[for attribution in _existing.document.closure.attributions {attribution.evidence_refs}],
	[for effect in _existing.document.closure.residual_effects {effect.refs}],
	[_abortEvidenceRefs],
]))
_expectedExistingClosureSources: [for index, ref in _existingClosureEvidenceRaw if len([for priorIndex, priorRef in _existingClosureEvidenceRaw if priorIndex < index && priorRef == ref {priorRef}]) == 0 {ref}]
_existingChangeEvidence: list.Concat(list.Concat([
	[for item in _existingItems if item.change != "retained" {item.evidence_refs}],
	[for item in _existing.document.account.retired {item.evidence_refs}],
]))
_existingAllAcceptancePass: len([for result in _existing.document.closure.acceptance_results if result.result == "fail" {result}]) == 0
_existingAllTerminalPass: len([for result in _existing.document.closure.terminal_control_results if result.result == "fail" {result}]) == 0
_expectedExistingAttemptResult: *"fail" | "pass"
if _run.value.document.halt.trigger == "plan-complete" && _existingAllAcceptancePass && _existingAllTerminalPass && _allInvariantPass {
	_expectedExistingAttemptResult: "pass"
}
_expectedOperationSummary: close({
	planned:           len(_planOperationIDs)
	actual:            len(_actualOperations)
	not_run:           len(_notRunOperations)
	passed:            len(_passedOperations)
	failed:            len(_failedOperations)
	emergency_patches: len(_run.value.document.emergency_patches)
	findings:          len(_findings)
	unknowns:          len(_expectedExistingUnknowns)
})

_validateChecks: {
	_itemIDsUnique:  list.UniqueItems(_existingItemIDs) & true
	_usedUnique:     list.UniqueItems(_existingUsedPrevious) & true
	_pointsUnique:   list.UniqueItems(_existingPointIDs) & true
	_terminalUnique: list.UniqueItems(_existingTerminalIDs) & true
	if _goal.value.bindings.observe != _previous.binding {_invalid: error("contract relation rejected: _goal.value.bindings.observe != _previous.binding")}
	if _plan.value.bindings.goal != _goal.binding {_invalid: error("contract relation rejected: _plan.value.bindings.goal != _goal.binding")}
	if _run.value.bindings.goal != _goal.binding {_invalid: error("contract relation rejected: _run.value.bindings.goal != _goal.binding")}
	if _run.value.bindings.plan != _plan.binding {_invalid: error("contract relation rejected: _run.value.bindings.plan != _plan.binding")}
	if _existing.document.account.revision != _previous.value.document.account.revision+1 {_invalid: error("contract relation rejected: _existing.document.account.revision != _previous.value.document.account.revision+1")}
	if _existing.document.account.subject != _previous.value.document.account.subject {_invalid: error("contract relation rejected: _existing.document.account.subject != _previous.value.document.account.subject")}
	if _existing.document.account.boundary != _previous.value.document.account.boundary {_invalid: error("contract relation rejected: _existing.document.account.boundary != _previous.value.document.account.boundary")}
	if _existing.document.account.lenses != _previous.value.document.account.lenses {_invalid: error("contract relation rejected: _existing.document.account.lenses != _previous.value.document.account.lenses")}
	if _existing.document.account.lens_index != _expectedExistingLensIndex {_invalid: error("contract relation rejected: _existing.document.account.lens_index != _expectedExistingLensIndex")}
	if _runOperationIDs != _planOperationIDs {_invalid: error("contract relation rejected: _runOperationIDs != _planOperationIDs")}
	if len(_existingUsedPrevious) != len(_existingPreviousIDs) {_invalid: error("contract relation rejected: len(_existingUsedPrevious) != len(_existingPreviousIDs)")}
	for previousID in _existingPreviousIDs {
		if !list.Contains(_existingUsedPrevious, previousID) {_invalid: error("contract relation rejected: !list.Contains(_existingUsedPrevious, previousID)")}
	}
	for index, item in _existingItems {
		if item.item_id != _expectedExistingItemIDs[index] {_invalid: error("contract relation rejected: item.item_id != _expectedExistingItemIDs[index]")}
		if !list.Contains(_existing.document.account.lenses, item.lens) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.lenses, item.lens)")}
		if item.route == "goal-candidate" {_invalid: error("contract relation rejected: item.route == \"goal-candidate\"")}
		if item.route == "external" && item.route_ref == null {_invalid: error("contract relation rejected: item.route == \"external\" && item.route_ref == null")}
		if item.route != "external" && item.route_ref != null {_invalid: error("contract relation rejected: item.route != \"external\" && item.route_ref != null")}
		if item.change == "added" && item.previous_item_id != null {_invalid: error("contract relation rejected: item.change == \"added\" && item.previous_item_id != null")}
		if item.change != "added" && item.previous_item_id == null {_invalid: error("contract relation rejected: item.change != \"added\" && item.previous_item_id == null")}
		if item.previous_item_id != null {
			if !list.Contains(_existingPreviousIDs, item.previous_item_id) {_invalid: error("contract relation rejected: !list.Contains(_existingPreviousIDs, item.previous_item_id)")}
			if item.change == "retained" && item.item_id != item.previous_item_id {_invalid: error("contract relation rejected: item.change == \"retained\" && item.item_id != item.previous_item_id")}
			if item.change == "changed" && item.item_id == item.previous_item_id {_invalid: error("contract relation rejected: item.change == \"changed\" && item.item_id == item.previous_item_id")}
		}
		for ref in item.evidence_refs {
			if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.source_refs, ref)")}
		}
		if item.change != "retained" {
			if len([for ref in item.evidence_refs if list.Contains(_existing.document.account.delta.evidence_refs, ref) {ref}]) == 0 {_invalid: error("contract relation rejected: len([for ref in item.evidence_refs if list.Contains(_existing.document.account.delta.evidence_refs, ref) {ref}]) == 0")}
		}
	}
	for lens in _existing.document.account.lenses {
		if len([for item in _existingItems if item.lens == lens {item}]) == 0 {_invalid: error("contract relation rejected: len([for item in _existingItems if item.lens == lens {item}]) == 0")}
	}
	for retired in _existing.document.account.retired {
		if !list.Contains(_existingPreviousIDs, retired.previous_item_id) {_invalid: error("contract relation rejected: !list.Contains(_existingPreviousIDs, retired.previous_item_id)")}
		for ref in retired.evidence_refs {
			if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.source_refs, ref)")}
			if !list.Contains(_existing.document.account.delta.evidence_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.delta.evidence_refs, ref)")}
		}
	}
	for result in list.Concat([_existing.document.closure.acceptance_results, _existing.document.closure.terminal_control_results]) {
		for ref in result.evidence_refs {
			if !list.Contains(_existing.document.closure.closure_source_refs, ref) {_invalid: error("judgment evidence must be present in closure sources")}
		}
		for unknown in result.unknowns {
			for ref in unknown.basis_refs {
				if !list.Contains(_existing.document.closure.closure_source_refs, ref) {_invalid: error("judgment unknown evidence must be present in closure sources")}
			}
		}
	}
	for finding in _existing.document.closure.findings {
		for ref in finding.evidence_refs {
			if !list.Contains(_existing.document.closure.closure_source_refs, ref) {_invalid: error("Run finding evidence must be present in closure sources")}
		}
	}
	for unknown in _existing.document.closure.unknowns {
		for ref in unknown.basis_refs {
			if !list.Contains(_existing.document.closure.closure_source_refs, ref) {_invalid: error("Run unknown evidence must be present in closure sources")}
		}
	}
	if _existing.document.account.source_refs != _expectedExistingAccountSources {_invalid: error("Account sources must be derived only from Account item and retirement evidence")}
	if _existing.document.closure.closure_source_refs != _expectedExistingClosureSources {_invalid: error("closure sources must equal the derived closure-only source set")}
	for ref in _abortEvidenceRefs {
		if !list.Contains(_existing.document.closure.closure_source_refs, ref) {_invalid: error("abort evidence must be present in closure sources")}
	}
	for action in _existing.document.closure.closure_actions {
		for ref in action.authorized_by {
			if ref != _goal.value.document.execution_envelope.authorization_ref && !list.Contains(_goal.value.document.execution_envelope.permission_refs, ref) {_invalid: error("closure action authority must be present in the Goal execution envelope")}
		}
		for ref in action.actual_effect_refs {
			if !list.Contains(_goal.value.document.execution_envelope.maximum_side_effects, ref) {_invalid: error("closure action effect must be present in the Goal maximum side effects")}
		}
	}
	for ref in _existing.document.account.delta.evidence_refs {
		if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.source_refs, ref)")}
		if !list.Contains(_existingChangeEvidence, ref) {_invalid: error("contract relation rejected: !list.Contains(_existingChangeEvidence, ref)")}
	}
	if len(_existingPointIDs) != len(_goalPointIDs) {_invalid: error("contract relation rejected: len(_existingPointIDs) != len(_goalPointIDs)")}
	for id in _goalPointIDs {
		if !list.Contains(_existingPointIDs, id) {_invalid: error("contract relation rejected: !list.Contains(_existingPointIDs, id)")}
	}
	for result in _existing.document.closure.acceptance_results {
		if list.Contains(_goalPointIDs, result.id) && result.judge != _goalPointByID[result.id].judge {_invalid: error("acceptance judge must equal the Goal judge")}
		if list.Contains(_goalPointIDs, result.id) && result.comparison_contract != _goalPointByID[result.id].acceptance {_invalid: error("acceptance comparison contract must equal the Goal acceptance contract")}
	}
	if len(_existingTerminalIDs) != len(_terminalControlIDs) {_invalid: error("contract relation rejected: len(_existingTerminalIDs) != len(_terminalControlIDs)")}
	for id in _terminalControlIDs {
		if !list.Contains(_existingTerminalIDs, id) {_invalid: error("contract relation rejected: !list.Contains(_existingTerminalIDs, id)")}
	}
	for result in _existing.document.closure.terminal_control_results {
		if list.Contains(_terminalControlIDs, result.id) && result.judge != _terminalControlByID[result.id].judge {_invalid: error("terminal control judge must equal the Goal judge")}
		if list.Contains(_terminalControlIDs, result.id) && result.comparison_contract != close({
			controlled_variable: _terminalControlByID[result.id].controlled_variable
			allowed_domain:      _terminalControlByID[result.id].allowed_domain
			forbidden_drift:     _terminalControlByID[result.id].forbidden_drift
			required_trace:      _terminalControlByID[result.id].required_trace
			check_method:        _terminalControlByID[result.id].check_method
			check_timing:        _terminalControlByID[result.id].check_timing
		}) {_invalid: error("terminal control comparison contract must equal the Goal control contract")}
	}
	if _existing.document.closure.attempt_result != _expectedExistingAttemptResult {_invalid: error("contract relation rejected: _existing.document.closure.attempt_result != _expectedExistingAttemptResult")}
	if _existing.document.closure.operation_summary != _expectedOperationSummary {_invalid: error("contract relation rejected: _existing.document.closure.operation_summary != _expectedOperationSummary")}
	if _existing.document.closure.findings != _findings {_invalid: error("contract relation rejected: _existing.document.closure.findings != _findings")}
	if _existing.document.closure.unknowns != _expectedExistingUnknowns {_invalid: error("contract relation rejected: _existing.document.closure.unknowns != _expectedExistingUnknowns")}
	if _existing.document.closure.run_halt.trigger != _run.value.document.halt.trigger {_invalid: error("contract relation rejected: _existing.document.closure.run_halt.trigger != _run.value.document.halt.trigger")}
	if _existing.document.closure.run_halt.resume_ref != _run.value.document.halt.resume_ref {_invalid: error("contract relation rejected: _existing.document.closure.run_halt.resume_ref != _run.value.document.halt.resume_ref")}
	if _existing.document.closure.run_halt.abort != _abortSummary {_invalid: error("run_halt.abort: summary must equal the Plan-owned abort response and exact Run evidence")}
	if _existing.document.closure.run_head_event_sha256 != _run.value.document.ledger_head_event_sha256 {_invalid: error("contract relation rejected: _existing.document.closure.run_head_event_sha256 != _run.value.document.ledger_head_event_sha256")}
	if _expectedExistingAttemptResult == "pass" && _existing.document.closure.incomplete_deliverable != null {_invalid: error("contract relation rejected: _expectedExistingAttemptResult == \"pass\" && _existing.document.closure.incomplete_deliverable != null")}
	if _expectedExistingAttemptResult == "fail" && _existing.document.closure.incomplete_deliverable == null {_invalid: error("contract relation rejected: _expectedExistingAttemptResult == \"fail\" && _existing.document.closure.incomplete_deliverable == null")}
}

validate: _validateChecks & _existing
