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
#JudgmentInput: close({
	id:              #Text
	judge_ref:       #Text
	result:          #Result
	actual_refs:     #NonEmptyStrings
	comparison_refs: #NonEmptyStrings
	evidence_refs:   #NonEmptyStrings
	unknowns: [...#Unknown]
})
#Judgment: #JudgmentInput
#Disposition: close({
	state:     "placed" | "pending" | "none"
	statement: #Text
	refs:      #Strings
})
#Incomplete: close({
	statement: #Text
	refs:      #NonEmptyStrings
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
	schema:            "k4-finish-document/v4"
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
	schema:            "k4-observe-document/v2"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {...}
	document: {account: #Account, ...}
}
#GoalEnvelope: {
	schema:            "k4-goal-document/v6"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {observe: #Binding, ...}
	document: {
		status: "frozen"
		acceptance_points: [{point_id: #Text, judge: {ref: #Text, ...}, ...}, ...]
		control_contracts: [...{control_id: #Text, check_timing: "invariant" | "terminal", judge: {ref: #Text, ...}, ...}]
		...
	}
}
#PlanEnvelope: {
	schema:            "k4-plan-document/v7"
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
	schema:            "k4-run-projection/v6"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {goal: #Binding, plan: #Binding, ...}
	document: {
		halted:                   true
		event_count:              uint & >0
		ledger_head_event_sha256: #Digest
		execution_result:         null | #Result
		abort_confirmation: null | close({source_ref: #Text, reason: #Text, evidence_refs: #NonEmptyStrings, ...})
		halt: close({
			trigger:                   "plan-complete" | "abort"
			side_effect_evidence_refs: #Strings
			resume_ref:                null | #Text
			...
		})
		operations: [{operation_id: #OperationID, result: #Result | "not-run", ...}, ...]
		operation_results: [...{operation_id: #OperationID, result: #Result, findings: [...#Finding], unknowns: [...#Unknown], ...}]
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
	subject:     #Text
	boundary:    #Text
	cutoff:      #Text
	source_refs: #NonEmptyStrings
	lenses:      #NonEmptyStrings
	delta:       #Delta
	items: [#ItemInput, ...#ItemInput]
	retired: [...#Retired]
	acceptance_results: [#JudgmentInput, ...#JudgmentInput]
	terminal_control_results: [...#JudgmentInput]
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
_lensIndex: [for lensName in _input.lenses {close({
	lens: lensName
	item_ids: [for item in _generatedItems if item.lens == lensName {item.item_id}]
})
}]
_goalPointIDs: [for point in _goal.value.document.acceptance_points {point.point_id}]
_goalPointJudgeRefs: {for point in _goal.value.document.acceptance_points {(point.point_id): point.judge.ref}}
_inputPointIDs: [for result in _input.acceptance_results {result.id}]
_terminalControlIDs: [for control in _goal.value.document.control_contracts if control.check_timing == "terminal" {control.control_id}]
_terminalControlJudgeRefs: {for control in _goal.value.document.control_contracts if control.check_timing == "terminal" {(control.control_id): control.judge.ref}}
_inputTerminalIDs: [for result in _input.terminal_control_results {result.id}]
_planOperationIDs: [for operation in _plan.value.document.operations {operation.operation_id}]
_runOperationIDs: [for operation in _run.value.document.operations {operation.operation_id}]

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

_actualOperations: [for operation in _run.value.document.operations if operation.result != "not-run" {operation}]
_notRunOperations: [for operation in _run.value.document.operations if operation.result == "not-run" {operation}]
_passedOperations: [for operation in _run.value.document.operations if operation.result == "pass" {operation}]
_failedOperations: [for operation in _run.value.document.operations if operation.result == "fail" {operation}]
_abortOperations: [for operation in _run.value.document.operations if operation.phase == "abort" {operation}]
_actualAbortOperations: [for operation in _abortOperations if operation.result != "not-run" {operation}]
_passedAbortOperations: [for operation in _abortOperations if operation.result == "pass" {operation}]
_failedAbortOperations: [for operation in _abortOperations if operation.result == "fail" {operation}]
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
_allAcceptancePass: len([for result in _input.acceptance_results if result.result == "fail" {result}]) == 0
_allTerminalPass: len([for result in _input.terminal_control_results if result.result == "fail" {result}]) == 0
_allInvariantPass: len([for result in _run.value.document.invariant_control_results if result.result == "fail" {result}]) == 0
_attemptResult: *"fail" | "pass"
if _run.value.document.halt.trigger == "plan-complete" && _allAcceptancePass && _allTerminalPass && _allInvariantPass {
	_attemptResult: "pass"
}

_allEvidence: list.Concat(list.Concat([
	[for item in _generatedItems {item.evidence_refs}],
	[for item in _input.retired {item.evidence_refs}],
	[for result in _input.acceptance_results {result.evidence_refs}],
	[for result in _input.terminal_control_results {result.evidence_refs}],
	[for finding in _findings {finding.evidence_refs}],
	[for unknown in _unknowns {unknown.basis_refs}],
	[_abortEvidenceRefs],
]))
_changeEvidence: list.Concat(list.Concat([
	[for item in _generatedItems if item.change != "retained" {item.evidence_refs}],
	[for item in _input.retired {item.evidence_refs}],
]))

_generateChecks: {
	_itemIDsUnique:  list.UniqueItems(_itemIDs) & true
	_usedUnique:     list.UniqueItems(_usedPrevious) & true
	_pointsUnique:   list.UniqueItems(_inputPointIDs) & true
	_terminalUnique: list.UniqueItems(_inputTerminalIDs) & true
	if _goal.value.bindings.observe != _previous.binding {_invalid: error("contract relation rejected: _goal.value.bindings.observe != _previous.binding")}
	if _plan.value.bindings.goal != _goal.binding {_invalid: error("contract relation rejected: _plan.value.bindings.goal != _goal.binding")}
	if _run.value.bindings.goal != _goal.binding {_invalid: error("contract relation rejected: _run.value.bindings.goal != _goal.binding")}
	if _run.value.bindings.plan != _plan.binding {_invalid: error("contract relation rejected: _run.value.bindings.plan != _plan.binding")}
	if _input.subject != _previous.value.document.account.subject {_invalid: error("contract relation rejected: _input.subject != _previous.value.document.account.subject")}
	if _input.boundary != _previous.value.document.account.boundary {_invalid: error("contract relation rejected: _input.boundary != _previous.value.document.account.boundary")}
	if _input.lenses != _previous.value.document.account.lenses {_invalid: error("contract relation rejected: _input.lenses != _previous.value.document.account.lenses")}
	if _runOperationIDs != _planOperationIDs {_invalid: error("contract relation rejected: _runOperationIDs != _planOperationIDs")}
	if len(_usedPrevious) != len(_previousIDs) {_invalid: error("contract relation rejected: len(_usedPrevious) != len(_previousIDs)")}
	for previousID in _previousIDs {
		if !list.Contains(_usedPrevious, previousID) {_invalid: error("contract relation rejected: !list.Contains(_usedPrevious, previousID)")}
	}
	for item in _generatedItems {
		if !list.Contains(_input.lenses, item.lens) {_invalid: error("contract relation rejected: !list.Contains(_input.lenses, item.lens)")}
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
			if !list.Contains(_input.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_input.source_refs, ref)")}
		}
		if item.change != "retained" {
			if len([for ref in item.evidence_refs if list.Contains(_input.delta.evidence_refs, ref) {ref}]) == 0 {_invalid: error("contract relation rejected: len([for ref in item.evidence_refs if list.Contains(_input.delta.evidence_refs, ref) {ref}]) == 0")}
		}
	}
	for lens in _input.lenses {
		if len([for item in _generatedItems if item.lens == lens {item}]) == 0 {_invalid: error("contract relation rejected: len([for item in _generatedItems if item.lens == lens {item}]) == 0")}
	}
	for retired in _input.retired {
		if !list.Contains(_previousIDs, retired.previous_item_id) {_invalid: error("contract relation rejected: !list.Contains(_previousIDs, retired.previous_item_id)")}
		for ref in retired.evidence_refs {
			if !list.Contains(_input.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_input.source_refs, ref)")}
			if !list.Contains(_input.delta.evidence_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_input.delta.evidence_refs, ref)")}
		}
	}
	for result in list.Concat([_input.acceptance_results, _input.terminal_control_results]) {
		for ref in result.evidence_refs {
			if !list.Contains(_input.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_input.source_refs, ref)")}
		}
		for unknown in result.unknowns {
			for ref in unknown.basis_refs {
				if !list.Contains(_input.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_input.source_refs, ref)")}
			}
		}
	}
	for finding in _findings {
		for ref in finding.evidence_refs {
			if !list.Contains(_input.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_input.source_refs, ref)")}
		}
	}
	for unknown in list.Concat([_operationUnknowns, _patchUnknowns]) {
		for ref in unknown.basis_refs {
			if !list.Contains(_input.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_input.source_refs, ref)")}
		}
	}
	for ref in _input.source_refs {
		if !list.Contains(_allEvidence, ref) {_invalid: error("contract relation rejected: !list.Contains(_allEvidence, ref)")}
	}
	for ref in _abortEvidenceRefs {
		if !list.Contains(_input.source_refs, ref) {_invalid: error("abort evidence must be declared in source_refs")}
	}
	for ref in _input.delta.evidence_refs {
		if !list.Contains(_input.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_input.source_refs, ref)")}
		if !list.Contains(_changeEvidence, ref) {_invalid: error("contract relation rejected: !list.Contains(_changeEvidence, ref)")}
	}
	if len(_inputPointIDs) != len(_goalPointIDs) {_invalid: error("contract relation rejected: len(_inputPointIDs) != len(_goalPointIDs)")}
	for id in _goalPointIDs {
		if !list.Contains(_inputPointIDs, id) {_invalid: error("contract relation rejected: !list.Contains(_inputPointIDs, id)")}
	}
	for result in _input.acceptance_results {
		if list.Contains(_goalPointIDs, result.id) && result.judge_ref != _goalPointJudgeRefs[result.id] {_invalid: error("acceptance_results.judge_ref: actual judge must equal the Goal acceptance judge")}
	}
	if len(_inputTerminalIDs) != len(_terminalControlIDs) {_invalid: error("contract relation rejected: len(_inputTerminalIDs) != len(_terminalControlIDs)")}
	for id in _terminalControlIDs {
		if !list.Contains(_inputTerminalIDs, id) {_invalid: error("contract relation rejected: !list.Contains(_inputTerminalIDs, id)")}
	}
	for result in _input.terminal_control_results {
		if list.Contains(_terminalControlIDs, result.id) && result.judge_ref != _terminalControlJudgeRefs[result.id] {_invalid: error("terminal_control_results.judge_ref: actual judge must equal the Goal terminal-control judge")}
	}
	if _attemptResult == "pass" && _input.incomplete_deliverable != null {_invalid: error("contract relation rejected: _attemptResult == \"pass\" && _input.incomplete_deliverable != null")}
	if _attemptResult == "fail" && _input.incomplete_deliverable == null {_invalid: error("contract relation rejected: _attemptResult == \"fail\" && _input.incomplete_deliverable == null")}
}

_document: #Document & {
	account: {
		revision:    _previous.value.document.account.revision + 1
		subject:     _input.subject
		boundary:    _input.boundary
		cutoff:      _input.cutoff
		source_refs: _input.source_refs
		lenses:      _input.lenses
		lens_index:  _lensIndex
		delta:       _input.delta
		items:       _generatedItems
		retired:     _input.retired
	}
	closure: {
		acceptance_results:       _input.acceptance_results
		terminal_control_results: _input.terminal_control_results
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
	schema:   "k4-finish-document/v4"
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
_existingAllEvidence: list.Concat(list.Concat([
	[for item in _existingItems {item.evidence_refs}],
	[for item in _existing.document.account.retired {item.evidence_refs}],
	[for result in _existing.document.closure.acceptance_results {result.evidence_refs}],
	[for result in _existing.document.closure.terminal_control_results {result.evidence_refs}],
	[for finding in _existing.document.closure.findings {finding.evidence_refs}],
	[for unknown in _existing.document.closure.unknowns {unknown.basis_refs}],
	[_abortEvidenceRefs],
]))
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
			if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.source_refs, ref)")}
		}
		for unknown in result.unknowns {
			for ref in unknown.basis_refs {
				if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.source_refs, ref)")}
			}
		}
	}
	for finding in _existing.document.closure.findings {
		for ref in finding.evidence_refs {
			if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.source_refs, ref)")}
		}
	}
	for unknown in _existing.document.closure.unknowns {
		for ref in unknown.basis_refs {
			if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.source_refs, ref)")}
		}
	}
	for ref in _existing.document.account.source_refs {
		if !list.Contains(_existingAllEvidence, ref) {_invalid: error("contract relation rejected: !list.Contains(_existingAllEvidence, ref)")}
	}
	for ref in _abortEvidenceRefs {
		if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: error("abort evidence must be declared in account.source_refs")}
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
		if list.Contains(_goalPointIDs, result.id) && result.judge_ref != _goalPointJudgeRefs[result.id] {_invalid: error("acceptance_results.judge_ref: actual judge must equal the Goal acceptance judge")}
	}
	if len(_existingTerminalIDs) != len(_terminalControlIDs) {_invalid: error("contract relation rejected: len(_existingTerminalIDs) != len(_terminalControlIDs)")}
	for id in _terminalControlIDs {
		if !list.Contains(_existingTerminalIDs, id) {_invalid: error("contract relation rejected: !list.Contains(_existingTerminalIDs, id)")}
	}
	for result in _existing.document.closure.terminal_control_results {
		if list.Contains(_terminalControlIDs, result.id) && result.judge_ref != _terminalControlJudgeRefs[result.id] {_invalid: error("terminal_control_results.judge_ref: actual judge must equal the Goal terminal-control judge")}
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
