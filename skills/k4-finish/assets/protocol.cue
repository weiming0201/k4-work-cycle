package k4_finish

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"list"
	"strings"
)

context: _

#Text:   string & !=""
#Digest: string & =~"^[0-9a-f]{64}$"
#ItemID: string & =~"^item-[0-9a-f]{16}$"
#Strings: [...#Text] & list.UniqueItems()
#NonEmptyStrings: [#Text, ...#Text] & list.UniqueItems()
#Result: "pass" | "Finding" | "unknown"
#Binding: close({
	ref:            #Text
	sha256:         #Digest
	content_sha256: #Digest
})
#ItemCore: close({
	epistemic_kind: "fact" | "source-statement" | "inference" | "preference" | "unknown"
	state:           "aligned" | "gap" | "conflict" | "unknown"
	statement:       #Text
	evidence_refs:   #NonEmptyStrings
	route:           "none" | "goal-candidate" | "retain" | "external"
	route_ref:       null | #Text
})
#ItemInput: close({
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
#Account: close({
	revision:    uint
	subject:     #Text
	boundary:    #Text
	cutoff:      #Text
	source_refs: #NonEmptyStrings
	delta:       #Delta
	items:       [#Item, ...#Item]
	retired:     [...#Retired]
})
#JudgmentInput: close({
	id:              #Text
	result:          #Result
	actual_refs:     #NonEmptyStrings
	comparison_refs: #NonEmptyStrings
	evidence_refs:   #NonEmptyStrings
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
#Closure: close({
	acceptance_results:       [#Judgment, ...#Judgment]
	terminal_control_results: [...#Judgment]
	terminal_state:           "completed" | "paused" | "failed" | "cancelled"
	result_disposition:       #Disposition
	incomplete_deliverable:   null | #Incomplete
	resume_ref:               null | #Text
	run_log_ref:              #Text
	run_head_event_sha256:    #Digest
})
#Document: close({
	account: #Account
	closure: #Closure
})
#Envelope: close({
	schema:            "k4-finish-document/v1"
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
	schema: "k4-observe-document/v1" | "k4-finish-document/v1"
	generated_unix_ms: uint
	content_sha256: #Digest
	bindings: {...}
	document: {account: #Account, ...}
}
#GoalEnvelope: {
	schema: #Text
	generated_unix_ms: uint
	content_sha256: #Digest
	bindings: {observe: #Binding, ...}
	document: {
		status: "frozen"
		acceptance_points: [{point_id: #Text, ...}, ...]
		control_contracts: [{control_id: #Text, check_timing: "invariant" | "terminal", ...}, ...]
		...
	}
}
#PlanEnvelope: {
	schema: #Text
	generated_unix_ms: uint
	content_sha256: #Digest
	bindings: {goal: #Binding, ...}
	document: {
		status: "executable"
		operations: [{operation_id: #Text, ...}, ...]
		...
	}
}
#RunEnvelope: {
	schema: #Text
	generated_unix_ms: uint
	content_sha256: #Digest
	bindings: {goal: #Binding, plan: #Binding, ...}
	document: {
		halted: true
		event_count: uint & >0
		ledger_head_event_sha256: #Digest
		operation_results: [{operation_id: #Text, result: #Result, ...}, ...]
		invariant_control_results: [{control_id: #Text, result: #Result, ...}, ...]
		...
	}
}
#Bound: close({
	binding: #Binding
	value: _
})
#Input: close({
	subject:     #Text
	boundary:    #Text
	cutoff:      #Text
	source_refs: #NonEmptyStrings
	delta:       #Delta
	items:       [#ItemInput, ...#ItemInput]
	retired:     [...#Retired]
	acceptance_results:       [#JudgmentInput, ...#JudgmentInput]
	terminal_control_results: [...#JudgmentInput]
	terminal_state:           "completed" | "paused" | "failed" | "cancelled"
	result_disposition:       #Disposition
	incomplete_deliverable:   null | #Incomplete
	resume_ref:               null | #Text
	run_log_ref:              #Text
	run_head_event_sha256:    #Digest
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
		epistemic_kind: item.epistemic_kind
		state:           item.state
		statement:       item.statement
		evidence_refs:   item.evidence_refs
		route:           item.route
		route_ref:       item.route_ref
	})
	close({
		item_id:          "item-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(_core))), 0, 16))"
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
_allEvidence: list.Concat(list.Concat([
	[for item in _generatedItems {item.evidence_refs}],
	[for item in _input.retired {item.evidence_refs}],
	[for result in _input.acceptance_results {result.evidence_refs}],
	[for result in _input.terminal_control_results {result.evidence_refs}],
]))
_changeEvidence: list.Concat(list.Concat([
	[for item in _generatedItems if item.change != "retained" {item.evidence_refs}],
	[for item in _input.retired {item.evidence_refs}],
]))
_goalPointIDs: [for point in _goal.value.document.acceptance_points {point.point_id}]
_inputPointIDs: [for result in _input.acceptance_results {result.id}]
_terminalControlIDs: [for control in _goal.value.document.control_contracts if control.check_timing == "terminal" {control.control_id}]
_inputTerminalIDs: [for result in _input.terminal_control_results {result.id}]
_planOperationIDs: [for operation in _plan.value.document.operations {operation.operation_id}]
_runOperationIDs: [for result in _run.value.document.operation_results {result.operation_id}]
_allAcceptancePass: len([for result in _input.acceptance_results if result.result != "pass" {result}]) == 0
_allTerminalPass: len([for result in _input.terminal_control_results if result.result != "pass" {result}]) == 0
_allInvariantPass: len([for result in _run.value.document.invariant_control_results if result.result != "pass" {result}]) == 0
_allOperationsPass: len(_runOperationIDs) == len(_planOperationIDs) &&
	len([for result in _run.value.document.operation_results if result.result != "pass" {result}]) == 0

_generateChecks: {
	_itemIDsUnique: list.UniqueItems(_itemIDs) & true
	_usedUnique: list.UniqueItems(_usedPrevious) & true
	_pointsUnique: list.UniqueItems(_inputPointIDs) & true
	_terminalUnique: list.UniqueItems(_inputTerminalIDs) & true
	if _goal.value.bindings.observe != _previous.binding {_invalid: _|_}
	if _plan.value.bindings.goal != _goal.binding {_invalid: _|_}
	if _run.value.bindings.goal != _goal.binding {_invalid: _|_}
	if _run.value.bindings.plan != _plan.binding {_invalid: _|_}
	if _input.run_head_event_sha256 != _run.value.document.ledger_head_event_sha256 {_invalid: _|_}
	if _input.subject != _previous.value.document.account.subject {_invalid: _|_}
	if _input.boundary != _previous.value.document.account.boundary {_invalid: _|_}
	if len(_usedPrevious) != len(_previousIDs) {_invalid: _|_}
	for previousID in _previousIDs {
		if !list.Contains(_usedPrevious, previousID) {_invalid: _|_}
	}
	for item in _generatedItems {
		if item.route == "goal-candidate" {_invalid: _|_}
		if item.route == "external" && item.route_ref == null {_invalid: _|_}
		if item.route != "external" && item.route_ref != null {_invalid: _|_}
		if item.change == "added" && item.previous_item_id != null {_invalid: _|_}
		if item.change != "added" && item.previous_item_id == null {_invalid: _|_}
		if item.previous_item_id != null {
			if !list.Contains(_previousIDs, item.previous_item_id) {_invalid: _|_}
			if item.change == "retained" && item.item_id != item.previous_item_id {_invalid: _|_}
			if item.change == "changed" && item.item_id == item.previous_item_id {_invalid: _|_}
		}
		for ref in item.evidence_refs {
			if !list.Contains(_input.source_refs, ref) {_invalid: _|_}
		}
		if item.change != "retained" {
			if len([for ref in item.evidence_refs if list.Contains(_input.delta.evidence_refs, ref) {ref}]) == 0 {_invalid: _|_}
		}
	}
	for retired in _input.retired {
		if !list.Contains(_previousIDs, retired.previous_item_id) {_invalid: _|_}
		for ref in retired.evidence_refs {
			if !list.Contains(_input.source_refs, ref) {_invalid: _|_}
			if !list.Contains(_input.delta.evidence_refs, ref) {_invalid: _|_}
		}
	}
	for ref in _input.source_refs {
		if !list.Contains(_allEvidence, ref) {_invalid: _|_}
	}
	for ref in _input.delta.evidence_refs {
		if !list.Contains(_input.source_refs, ref) {_invalid: _|_}
		if !list.Contains(_changeEvidence, ref) {_invalid: _|_}
	}
	if len(_inputPointIDs) != len(_goalPointIDs) {_invalid: _|_}
	for id in _goalPointIDs {
		if !list.Contains(_inputPointIDs, id) {_invalid: _|_}
	}
	if len(_inputTerminalIDs) != len(_terminalControlIDs) {_invalid: _|_}
	for id in _terminalControlIDs {
		if !list.Contains(_inputTerminalIDs, id) {_invalid: _|_}
	}
	if len(_runOperationIDs) > len(_planOperationIDs) {_invalid: _|_}
	for id in _runOperationIDs {
		if !list.Contains(_planOperationIDs, id) {_invalid: _|_}
	}
	if _input.terminal_state == "completed" {
		if !_allOperationsPass {_invalid: _|_}
		if !_allAcceptancePass {_invalid: _|_}
		if !_allTerminalPass {_invalid: _|_}
		if !_allInvariantPass {_invalid: _|_}
		if _input.incomplete_deliverable != null {_invalid: _|_}
		if _input.resume_ref != null {_invalid: _|_}
	}
	if _input.terminal_state != "completed" {
		if _input.incomplete_deliverable == null {_invalid: _|_}
		if _input.resume_ref == null {_invalid: _|_}
	}
}

_document: #Document & {
	account: {
		revision:    _previous.value.document.account.revision + 1
		subject:     _input.subject
		boundary:    _input.boundary
		cutoff:      _input.cutoff
		source_refs: _input.source_refs
		delta:       _input.delta
		items:       _generatedItems
		retired:     _input.retired
	}
	closure: {
		acceptance_results:       _input.acceptance_results
		terminal_control_results: _input.terminal_control_results
		terminal_state:           _input.terminal_state
		result_disposition:       _input.result_disposition
		incomplete_deliverable:   _input.incomplete_deliverable
		resume_ref:               _input.resume_ref
		run_log_ref:              _input.run_log_ref
		run_head_event_sha256:    _input.run_head_event_sha256
	}
}
generate: _generateChecks & close({
	schema:   "k4-finish-document/v1"
	bindings: _bindings
	document: _document
})

_existing: #Envelope & context.existing & {bindings: _bindings}
_existingItems: _existing.document.account.items
_existingItemIDs: [for item in _existingItems {item.item_id}]
_expectedExistingItemIDs: [for item in _existingItems {
	"item-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(close({
		epistemic_kind: item.epistemic_kind
		state:           item.state
		statement:       item.statement
		evidence_refs:   item.evidence_refs
		route:           item.route
		route_ref:       item.route_ref
	})))), 0, 16))"
}]
_existingPreviousIDs: [for item in _previous.value.document.account.items {item.item_id}]
_existingUsedPrevious: list.Concat([
	[for item in _existingItems if item.previous_item_id != null {item.previous_item_id}],
	[for item in _existing.document.account.retired {item.previous_item_id}],
])
_existingAllEvidence: list.Concat(list.Concat([
	[for item in _existingItems {item.evidence_refs}],
	[for item in _existing.document.account.retired {item.evidence_refs}],
	[for result in _existing.document.closure.acceptance_results {result.evidence_refs}],
	[for result in _existing.document.closure.terminal_control_results {result.evidence_refs}],
]))
_existingChangeEvidence: list.Concat(list.Concat([
	[for item in _existingItems if item.change != "retained" {item.evidence_refs}],
	[for item in _existing.document.account.retired {item.evidence_refs}],
]))
_existingPointIDs: [for result in _existing.document.closure.acceptance_results {result.id}]
_existingTerminalIDs: [for result in _existing.document.closure.terminal_control_results {result.id}]
_existingRunOperationIDs: [for result in _run.value.document.operation_results {result.operation_id}]
_existingAllAcceptancePass: len([for result in _existing.document.closure.acceptance_results if result.result != "pass" {result}]) == 0
_existingAllTerminalPass: len([for result in _existing.document.closure.terminal_control_results if result.result != "pass" {result}]) == 0
_existingAllInvariantPass: len([for result in _run.value.document.invariant_control_results if result.result != "pass" {result}]) == 0
_existingAllOperationsPass: len(_existingRunOperationIDs) == len(_planOperationIDs) &&
	len([for result in _run.value.document.operation_results if result.result != "pass" {result}]) == 0

_validateChecks: {
	_itemIDsUnique:     list.UniqueItems(_existingItemIDs) & true
	_usedUnique:        list.UniqueItems(_existingUsedPrevious) & true
	_pointsUnique:      list.UniqueItems(_existingPointIDs) & true
	_terminalUnique:    list.UniqueItems(_existingTerminalIDs) & true
	if _goal.value.bindings.observe != _previous.binding {_invalid: _|_}
	if _plan.value.bindings.goal != _goal.binding {_invalid: _|_}
	if _run.value.bindings.goal != _goal.binding {_invalid: _|_}
	if _run.value.bindings.plan != _plan.binding {_invalid: _|_}
	if _existing.document.account.revision != _previous.value.document.account.revision + 1 {_invalid: _|_}
	if _existing.document.closure.run_head_event_sha256 != _run.value.document.ledger_head_event_sha256 {_invalid: _|_}
	if _existing.document.account.subject != _previous.value.document.account.subject {_invalid: _|_}
	if _existing.document.account.boundary != _previous.value.document.account.boundary {_invalid: _|_}
	if len(_existingUsedPrevious) != len(_existingPreviousIDs) {_invalid: _|_}
	for previousID in _existingPreviousIDs {
		if !list.Contains(_existingUsedPrevious, previousID) {_invalid: _|_}
	}
	for index, item in _existingItems {
		if item.item_id != _expectedExistingItemIDs[index] {_invalid: _|_}
		if item.route == "goal-candidate" {_invalid: _|_}
		if item.route == "external" && item.route_ref == null {_invalid: _|_}
		if item.route != "external" && item.route_ref != null {_invalid: _|_}
		if item.change == "added" && item.previous_item_id != null {_invalid: _|_}
		if item.change != "added" && item.previous_item_id == null {_invalid: _|_}
		if item.previous_item_id != null {
			if !list.Contains(_existingPreviousIDs, item.previous_item_id) {_invalid: _|_}
			if item.change == "retained" && item.item_id != item.previous_item_id {_invalid: _|_}
			if item.change == "changed" && item.item_id == item.previous_item_id {_invalid: _|_}
		}
		for ref in item.evidence_refs {
			if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: _|_}
		}
		if item.change != "retained" {
			if len([for ref in item.evidence_refs if list.Contains(_existing.document.account.delta.evidence_refs, ref) {ref}]) == 0 {_invalid: _|_}
		}
	}
	for retired in _existing.document.account.retired {
		if !list.Contains(_existingPreviousIDs, retired.previous_item_id) {_invalid: _|_}
		for ref in retired.evidence_refs {
			if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: _|_}
			if !list.Contains(_existing.document.account.delta.evidence_refs, ref) {_invalid: _|_}
		}
	}
	for ref in _existing.document.account.source_refs {
		if !list.Contains(_existingAllEvidence, ref) {_invalid: _|_}
	}
	for ref in _existing.document.account.delta.evidence_refs {
		if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: _|_}
		if !list.Contains(_existingChangeEvidence, ref) {_invalid: _|_}
	}
	if len(_existingPointIDs) != len(_goalPointIDs) {_invalid: _|_}
	for id in _goalPointIDs {
		if !list.Contains(_existingPointIDs, id) {_invalid: _|_}
	}
	if len(_existingTerminalIDs) != len(_terminalControlIDs) {_invalid: _|_}
	for id in _terminalControlIDs {
		if !list.Contains(_existingTerminalIDs, id) {_invalid: _|_}
	}
	if len(_existingRunOperationIDs) > len(_planOperationIDs) {_invalid: _|_}
	for id in _existingRunOperationIDs {
		if !list.Contains(_planOperationIDs, id) {_invalid: _|_}
	}
	if _existing.document.closure.terminal_state == "completed" {
		if !_existingAllOperationsPass {_invalid: _|_}
		if !_existingAllAcceptancePass {_invalid: _|_}
		if !_existingAllTerminalPass {_invalid: _|_}
		if !_existingAllInvariantPass {_invalid: _|_}
		if _existing.document.closure.incomplete_deliverable != null {_invalid: _|_}
		if _existing.document.closure.resume_ref != null {_invalid: _|_}
	}
	if _existing.document.closure.terminal_state != "completed" {
		if _existing.document.closure.incomplete_deliverable == null {_invalid: _|_}
		if _existing.document.closure.resume_ref == null {_invalid: _|_}
	}
}

validate: _validateChecks & _existing
