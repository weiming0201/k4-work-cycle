package k4_run

import "list"

context: _

#Text:        string & !=""
#Digest:      string & =~"^[0-9a-f]{64}$"
#ControlID:   string & =~"^control-[0-9a-f]{16}$"
#OperationID: string & =~"^op-[0-9a-f]{16}$"
#Strings: [...#Text] & list.UniqueItems()
#NonEmptyStrings: [#Text, ...#Text] & list.UniqueItems()
#ActualResult:    "pass" | "fail"
#ProjectedResult: #ActualResult | "not-run"
#Binding: close({
	ref:            #Text
	sha256:         #Digest
	content_sha256: #Digest
})
#GoalControl: {
	control_id:   #ControlID
	check_timing: "invariant" | "terminal"
	...
}
#PlanOperation: {
	operation_id: #OperationID
	depends_on: [...#OperationID]
	controlled_by: [...#ControlID]
	on_result: close({
		pass: close({next_operation_ids: [...#OperationID], reason: #Text})
		fail: close({next_operation_ids: [...#OperationID], reason: #Text})
	})
	...
}
#CoverageEntry: {
	control_id: #ControlID
	operation_ids: [...#OperationID]
	...
}
#GoalEnvelope: {
	schema:            "k4-goal-document/v5"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {...}
	document: {
		status: "frozen"
		control_contracts: [...#GoalControl]
		...
	}
}
#PlanEnvelope: {
	schema:            "k4-plan-document/v5"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {goal: #Binding}
	document: {
		status: "executable"
		entry_operation_ids: [#OperationID, ...#OperationID]
		operations: [#PlanOperation, ...#PlanOperation]
		coverage: {
			controls: [...#CoverageEntry]
			...
		}
		...
	}
}
#BoundGoal: close({binding: #Binding, value: #GoalEnvelope})
#BoundPlan: close({binding: #Binding, value: #PlanEnvelope})
#InvariantCheck: close({
	control_id:      #ControlID
	result:          #ActualResult
	actual_refs:     #Strings
	trace_refs:      #NonEmptyStrings
	comparison_refs: #Strings
	evidence_refs:   #Strings
})
#Finding: close({
	statement:     #Text
	evidence_refs: #NonEmptyStrings
})
#Unknown: close({
	statement:  #Text
	basis_refs: #NonEmptyStrings
})
#OperationEvent: close({
	kind:               "operation-result"
	operation_id:       #OperationID
	result:             #ActualResult
	eligibility_refs:   #NonEmptyStrings
	actual_output_refs: #Strings
	evidence_refs:      #Strings
	trace_refs:         #NonEmptyStrings
	invariant_checks: [...#InvariantCheck]
	findings: [...#Finding]
	unknowns: [...#Unknown]
})
#PatchEvent: close({
	kind:                    "emergency-patch"
	operation_id:            #OperationID
	attempt:                 1
	application_result:      "applied" | "not-applied"
	reason:                  #Text
	script_ref:              #Text
	tool_refs:               #NonEmptyStrings
	read_refs:               #Strings
	write_refs:              #NonEmptyStrings
	maximum_side_effects:    #NonEmptyStrings
	actual_side_effect_refs: #NonEmptyStrings
	trace_refs:              #NonEmptyStrings
	findings: [#Finding, ...#Finding]
	unknowns: [...#Unknown]
	verification_scope: "mainline-resumption-only"
})
#HaltEvent: close({
	kind:                      "halt"
	after_operation_id:        null | #OperationID
	next_operation_id:         null | #OperationID
	trigger:                   "plan-complete" | "blocked" | "cancelled"
	budget_evidence_refs:      #Strings
	side_effect_evidence_refs: #Strings
	evidence_refs:             #NonEmptyStrings
	resume_ref:                null | #Text
})
#Event: #OperationEvent | #PatchEvent | #HaltEvent
#EventEnvelope: close({
	schema:                "k4-run-event/v4"
	sequence:              uint
	recorded_unix_ms:      uint
	previous_event_sha256: null | #Digest
	content_sha256:        #Digest
	event_sha256:          #Digest
	bindings: close({goal: #Binding, plan: #Binding})
	event: #Event
})

_goal:            #BoundGoal & context.bindings.goal
_plan:            #BoundPlan & context.bindings.plan
_planGoalBinding: _plan.value.bindings.goal
_planGoalBinding: _goal.binding
_bindings: close({goal: _goal.binding, plan: _plan.binding})
_operationIDs: [for operation in _plan.value.document.operations {operation.operation_id}]
_controlTiming: {for control in _goal.value.document.control_contracts {
	(control.control_id): control.check_timing
}}
_planControlIDs: [for entry in _plan.value.document.coverage.controls {entry.control_id}]
_goalControlIDs: [for control in _goal.value.document.control_contracts {control.control_id}]
_planChecks: {
	_entryIDsUnique: list.UniqueItems(_plan.value.document.entry_operation_ids) & true
	for operationID in _plan.value.document.entry_operation_ids {
		if !list.Contains(_operationIDs, operationID) {_invalid: error("Plan entry must identify an operation")}
	}
	for operation in _plan.value.document.operations {
		_passTargetsUnique: list.UniqueItems(operation.on_result.pass.next_operation_ids) & true
		_failTargetsUnique: list.UniqueItems(operation.on_result.fail.next_operation_ids) & true
		for target in list.Concat([operation.on_result.pass.next_operation_ids, operation.on_result.fail.next_operation_ids]) {
			if !list.Contains(_operationIDs, target) {_invalid: error("Plan result edge must identify an operation")}
		}
	}
	_sortedPlanControls: list.SortStrings(_planControlIDs)
	_sortedGoalControls: list.SortStrings(_goalControlIDs)
	_sortedPlanControls: _sortedGoalControls
	_expectedCoverage: [for entry in _plan.value.document.coverage.controls {close({
		control_id: entry.control_id
		operation_ids: [for operation in _plan.value.document.operations if list.Contains(operation.controlled_by, entry.control_id) {operation.operation_id}]
	})
	}]
	_actualCoverage: _plan.value.document.coverage.controls
	_actualCoverage: _expectedCoverage
}

_events: [...#EventEnvelope] & context.events
for envelope in _events {
	if envelope.bindings != _bindings {_eventBindingMismatch: _|_}
}
_operationEvents: [for envelope in _events if envelope.event.kind == "operation-result" {envelope}]
_operationEventIDs: [for envelope in _operationEvents {envelope.event.operation_id}]
_operationEventIDsUnique: list.UniqueItems(_operationEventIDs) & true
_patchEvents: [for envelope in _events if envelope.event.kind == "emergency-patch" {envelope}]
_patchOperationIDs: [for envelope in _patchEvents {envelope.event.operation_id}]
_patchOperationIDsUnique: list.UniqueItems(_patchOperationIDs) & true
_haltEvents: [for envelope in _events if envelope.event.kind == "halt" {envelope}]

_operationByID: {for operation in _plan.value.document.operations {(operation.operation_id): operation}}
_passRoutes: [for envelope in _operationEvents if envelope.event.result == "pass" if list.Contains(_operationIDs, envelope.event.operation_id) {close({
	operation_id:       envelope.event.operation_id
	sequence:           envelope.sequence
	next_operation_ids: _operationByID[envelope.event.operation_id].on_result.pass.next_operation_ids
})
}]
_failRoutes: [for envelope in _operationEvents if envelope.event.result == "fail" if list.Contains(_operationIDs, envelope.event.operation_id) {close({
	operation_id:       envelope.event.operation_id
	sequence:           envelope.sequence
	next_operation_ids: _operationByID[envelope.event.operation_id].on_result.fail.next_operation_ids
})
}]
_routedResponses: list.Concat([_passRoutes, _failRoutes])
_selectedSuccessors: list.Concat([for route in _routedResponses {route.next_operation_ids}])
_activatedOperationIDs: list.Concat([_plan.value.document.entry_operation_ids, _selectedSuccessors])
_pendingOperationIDs: [for operation in _plan.value.document.operations if list.Contains(_activatedOperationIDs, operation.operation_id) if !list.Contains(_operationEventIDs, operation.operation_id) {operation.operation_id}]

_publicLedgerChecks: {
	for envelope in _events {
		if envelope.bindings != _bindings {_invalid: error("Run event bindings must equal the current Goal and Plan bindings")}
	}
	_operationIDsUnique: list.UniqueItems(_operationEventIDs) & true
	_patchIDsUnique:     list.UniqueItems(_patchOperationIDs) & true
	if len(_haltEvents) > 1 {_invalid: error("Run ledger may contain only one halt event")}
	if len(_haltEvents) == 1 {
		if _haltEvents[0].sequence != len(_events)-1 {_invalid: error("Run ledger cannot contain an event after halt")}
	}
	for envelope in _operationEvents {
		if !list.Contains(_operationIDs, envelope.event.operation_id) {_invalid: error("Run ledger contains an unknown Plan operation")}
		if !list.Contains(_plan.value.document.entry_operation_ids, envelope.event.operation_id) && len([for route in _routedResponses if route.sequence < envelope.sequence if list.Contains(route.next_operation_ids, envelope.event.operation_id) {route}]) == 0 {_invalid: error("Run operation was not activated by the frozen Plan route")}
		if envelope.event.result == "pass" && len(envelope.event.actual_output_refs) == 0 {_invalid: error("passing Run operation requires actual output")}
		if len(envelope.event.evidence_refs) == 0 {_invalid: error("Run operation result requires evidence")}
		if list.Contains(_operationIDs, envelope.event.operation_id) {
			for dependency in _operationByID[envelope.event.operation_id].depends_on {
				if len([for prior in _events if prior.sequence < envelope.sequence if prior.event.kind == "operation-result" if prior.event.operation_id == dependency {prior}]) != 1 {_invalid: error("operation dependency must already have exactly one response in the Run ledger")}
			}
			_actualInvariantIDsUnique: list.UniqueItems([for check in envelope.event.invariant_checks {check.control_id}]) & true
			if list.SortStrings([for controlID in _operationByID[envelope.event.operation_id].controlled_by if _controlTiming[controlID] == "invariant" {controlID}]) != list.SortStrings([for check in envelope.event.invariant_checks {check.control_id}]) {_invalid: error("Run invariant checks must exactly cover the operation's invariant controls")}
			for check in envelope.event.invariant_checks {
				if check.result == "pass" && (len(check.actual_refs) == 0 || len(check.comparison_refs) == 0) {_invalid: error("passing invariant check requires actual and comparison references")}
				if len(check.evidence_refs) == 0 {_invalid: error("invariant result requires evidence")}
			}
			if envelope.event.result == "pass" && len([for check in envelope.event.invariant_checks if check.result == "fail" {check}]) > 0 {_invalid: error("operation cannot pass with a failed invariant check")}
		}
	}
	for envelope in _patchEvents {
		if !list.Contains(_operationIDs, envelope.event.operation_id) {_invalid: error("emergency patch must identify one Plan operation")}
		if len([for prior in _operationEvents if prior.sequence < envelope.sequence if prior.event.operation_id == envelope.event.operation_id {prior}]) != 0 {_invalid: error("emergency patch must precede the Plan operation response")}
		if !list.Contains(_plan.value.document.entry_operation_ids, envelope.event.operation_id) && len([for route in _routedResponses if route.sequence < envelope.sequence if list.Contains(route.next_operation_ids, envelope.event.operation_id) {route}]) == 0 {_invalid: error("emergency patch may only restore an activated Plan operation")}
		if list.Contains(_operationIDs, envelope.event.operation_id) {
			for dependency in _operationByID[envelope.event.operation_id].depends_on {
				if len([for prior in _events if prior.sequence < envelope.sequence if prior.event.kind == "operation-result" if prior.event.operation_id == dependency {prior}]) != 1 {_invalid: error("emergency patch requires all Plan dependencies to have responses")}
			}
		}
	}
	if len(_haltEvents) == 1 {
		if len(_operationEvents) == 0 && _haltEvents[0].event.after_operation_id != null {_invalid: error("halt position must follow the last Run operation response")}
		if len(_operationEvents) > 0 && _haltEvents[0].event.after_operation_id != _operationEvents[len(_operationEvents)-1].event.operation_id {_invalid: error("halt position must follow the last Run operation response")}
		if _haltEvents[0].event.next_operation_id != null && !list.Contains(_operationIDs, _haltEvents[0].event.next_operation_id) {_invalid: error("halt next_operation_id must identify a Plan operation")}
		if _haltEvents[0].event.trigger == "plan-complete" && len(_pendingOperationIDs) != 0 {_invalid: error("plan-complete requires every activated Plan operation to have a response")}
	}
}

_publicCandidateChecks: {
	if len(_haltEvents) != 0 {_invalid: error("cannot append an event after Run halt")}
	if _input.kind == "operation-result" {
		if !list.Contains(_operationIDs, _input.operation_id) {_invalid: error("operation_id must identify exactly one Plan operation")}
		if list.Contains(_operationEventIDs, _input.operation_id) {_invalid: error("operation_id already has a Run response")}
		if !list.Contains(_activatedOperationIDs, _input.operation_id) {_invalid: error("operation_id is not activated by the frozen Plan route")}
		if _input.result == "pass" && len(_input.actual_output_refs) == 0 {_invalid: error("passing Run operation requires actual output")}
		if len(_input.evidence_refs) == 0 {_invalid: error("Run operation result requires evidence")}
		if list.Contains(_operationIDs, _input.operation_id) {
			for dependency in _operationByID[_input.operation_id].depends_on {
				if len([for prior in _operationEvents if prior.event.operation_id == dependency {prior}]) != 1 {_invalid: error("operation dependency must already have exactly one response in the Run journal")}
			}
			_actualInvariantIDsUnique: list.UniqueItems([for check in _input.invariant_checks {check.control_id}]) & true
			if list.SortStrings([for controlID in _operationByID[_input.operation_id].controlled_by if _controlTiming[controlID] == "invariant" {controlID}]) != list.SortStrings([for check in _input.invariant_checks {check.control_id}]) {_invalid: error("Run invariant checks must exactly cover the operation's invariant controls")}
			for check in _input.invariant_checks {
				if check.result == "pass" && (len(check.actual_refs) == 0 || len(check.comparison_refs) == 0) {_invalid: error("passing invariant check requires actual and comparison references")}
				if len(check.evidence_refs) == 0 {_invalid: error("invariant result requires evidence")}
			}
			if _input.result == "pass" && len([for check in _input.invariant_checks if check.result == "fail" {check}]) > 0 {_invalid: error("operation cannot pass with a failed invariant check")}
		}
	}
	if _input.kind == "emergency-patch" {
		if !list.Contains(_operationIDs, _input.operation_id) {_invalid: error("emergency patch must identify exactly one Plan operation")}
		if list.Contains(_patchOperationIDs, _input.operation_id) {_invalid: error("a Plan operation may receive at most one emergency patch")}
		if list.Contains(_operationEventIDs, _input.operation_id) {_invalid: error("emergency patch must precede the Plan operation response")}
		if !list.Contains(_activatedOperationIDs, _input.operation_id) {_invalid: error("emergency patch may only restore an activated Plan operation")}
		if list.Contains(_operationIDs, _input.operation_id) {
			for dependency in _operationByID[_input.operation_id].depends_on {
				if len([for prior in _operationEvents if prior.event.operation_id == dependency {prior}]) != 1 {_invalid: error("emergency patch requires all Plan dependencies to have responses")}
			}
		}
	}
	if _input.kind == "halt" {
		if len(_operationEvents) == 0 && _input.after_operation_id != null {_invalid: error("halt position must follow the last Run operation response")}
		if len(_operationEvents) > 0 && _input.after_operation_id != _operationEvents[len(_operationEvents)-1].event.operation_id {_invalid: error("halt position must follow the last Run operation response")}
		if _input.next_operation_id != null && !list.Contains(_operationIDs, _input.next_operation_id) {_invalid: error("halt next_operation_id must identify a Plan operation")}
		if _input.trigger == "plan-complete" && len(_pendingOperationIDs) != 0 {_invalid: error("plan-complete requires every activated Plan operation to have a response")}
	}
}

_input:          #Event & context.input
_generatedEvent: #Event
if _input.kind == "operation-result" {
	_generatedEvent: close({
		kind:               _input.kind
		operation_id:       _input.operation_id
		result:             _input.result
		eligibility_refs:   _input.eligibility_refs
		actual_output_refs: _input.actual_output_refs
		evidence_refs:      _input.evidence_refs
		trace_refs:         _input.trace_refs
		invariant_checks:   _input.invariant_checks
		findings:           _input.findings
		unknowns:           _input.unknowns
	})
}
if _input.kind == "emergency-patch" {
	_generatedEvent: close({
		kind:                    _input.kind
		operation_id:            _input.operation_id
		attempt:                 _input.attempt
		application_result:      _input.application_result
		reason:                  _input.reason
		script_ref:              _input.script_ref
		tool_refs:               _input.tool_refs
		read_refs:               _input.read_refs
		write_refs:              _input.write_refs
		maximum_side_effects:    _input.maximum_side_effects
		actual_side_effect_refs: _input.actual_side_effect_refs
		trace_refs:              _input.trace_refs
		findings:                _input.findings
		unknowns:                _input.unknowns
		verification_scope:      _input.verification_scope
	})
}
if _input.kind == "halt" {
	_generatedEvent: close({
		kind:                      _input.kind
		after_operation_id:        _input.after_operation_id
		next_operation_id:         _input.next_operation_id
		trigger:                   _input.trigger
		budget_evidence_refs:      _input.budget_evidence_refs
		side_effect_evidence_refs: _input.side_effect_evidence_refs
		evidence_refs:             _input.evidence_refs
		resume_ref:                _input.resume_ref
	})
}

next_event: _planChecks & _publicLedgerChecks & _publicCandidateChecks & close({
	schema:   "k4-run-event/v4"
	bindings: _bindings
	event:    _generatedEvent
})

#ProjectedOperation: close({
	operation_id:       #OperationID
	result:             #ProjectedResult
	event_sequence:     null | uint
	eligibility_refs:   #Strings
	actual_output_refs: #Strings
	evidence_refs:      #Strings
	trace_refs:         #Strings
	findings: [...#Finding]
	unknowns: [...#Unknown]
})
#ControlObservation: close({
	event_sequence:  uint
	operation_id:    #OperationID
	result:          #ActualResult
	actual_refs:     #Strings
	trace_refs:      #Strings
	comparison_refs: #Strings
	evidence_refs:   #Strings
})
#InvariantResult: close({
	control_id: #ControlID
	result:     #ActualResult
	observations: [#ControlObservation, ...#ControlObservation]
})
#ProjectedPatch: close({
	event_sequence:          uint
	operation_id:            #OperationID
	application_result:      "applied" | "not-applied"
	reason:                  #Text
	script_ref:              #Text
	tool_refs:               #NonEmptyStrings
	read_refs:               #Strings
	write_refs:              #NonEmptyStrings
	maximum_side_effects:    #NonEmptyStrings
	actual_side_effect_refs: #NonEmptyStrings
	trace_refs:              #NonEmptyStrings
	findings: [#Finding, ...#Finding]
	unknowns: [...#Unknown]
})

_operationProjection: [for operation in _plan.value.document.operations {
	_matches: [for envelope in _operationEvents if envelope.event.operation_id == operation.operation_id {envelope}]
	if len(_matches) == 0 {
		close({
			operation_id:   operation.operation_id
			result:         "not-run"
			event_sequence: null
			eligibility_refs: []
			actual_output_refs: []
			evidence_refs: []
			trace_refs: []
			findings: []
			unknowns: []
		})
	}
	if len(_matches) == 1 {
		close({
			operation_id:       operation.operation_id
			result:             _matches[0].event.result
			event_sequence:     _matches[0].sequence
			eligibility_refs:   _matches[0].event.eligibility_refs
			actual_output_refs: _matches[0].event.actual_output_refs
			evidence_refs:      _matches[0].event.evidence_refs
			trace_refs:         _matches[0].event.trace_refs
			findings:           _matches[0].event.findings
			unknowns:           _matches[0].event.unknowns
		})
	}
}]
_actualOperationResults: [for operation in _operationProjection if operation.result != "not-run" {operation}]
_patchProjection: [for envelope in _patchEvents {close({
	event_sequence:          envelope.sequence
	operation_id:            envelope.event.operation_id
	application_result:      envelope.event.application_result
	reason:                  envelope.event.reason
	script_ref:              envelope.event.script_ref
	tool_refs:               envelope.event.tool_refs
	read_refs:               envelope.event.read_refs
	write_refs:              envelope.event.write_refs
	maximum_side_effects:    envelope.event.maximum_side_effects
	actual_side_effect_refs: envelope.event.actual_side_effect_refs
	trace_refs:              envelope.event.trace_refs
	findings:                envelope.event.findings
	unknowns:                envelope.event.unknowns
})
}]
_invariantObservations: [for control in _goal.value.document.control_contracts if control.check_timing == "invariant" {
	control_id: control.control_id
	observations: list.Concat([for envelope in _operationEvents {
		[for check in envelope.event.invariant_checks if check.control_id == control.control_id {
			close({
				event_sequence:  envelope.sequence
				operation_id:    envelope.event.operation_id
				result:          check.result
				actual_refs:     check.actual_refs
				trace_refs:      check.trace_refs
				comparison_refs: check.comparison_refs
				evidence_refs:   check.evidence_refs
			})
		}]
	}])
}]
_invariantResults: [for control in _invariantObservations if len(control.observations) > 0 {
	_failures: [for observation in control.observations if observation.result == "fail" {observation}]
	_result: *"pass" | "fail"
	if len(_failures) > 0 {_result: "fail"}
	close({
		control_id:   control.control_id
		result:       _result
		observations: control.observations
	})
}]
_operationStates: [for result in _operationProjection {result.result}]
_operationFailures: [for state in _operationStates if state == "fail" {state}]
_executionResult: null | "pass" | "fail"
if len(_haltEvents) == 0 {_executionResult: null}
if len(_haltEvents) == 1 {
	if _haltEvents[0].event.trigger != "plan-complete" {_executionResult: null}
	if _haltEvents[0].event.trigger == "plan-complete" && len(_operationFailures) == 0 {_executionResult: "pass"}
	if _haltEvents[0].event.trigger == "plan-complete" && len(_operationFailures) > 0 {_executionResult: "fail"}
}

_halted: len(_haltEvents) == 1
_halt:   null | _
if !_halted {_halt: null}
if _halted {
	_halt: close({
		event_sequence:            _haltEvents[0].sequence
		after_operation_id:        _haltEvents[0].event.after_operation_id
		next_operation_id:         _haltEvents[0].event.next_operation_id
		trigger:                   _haltEvents[0].event.trigger
		budget_evidence_refs:      _haltEvents[0].event.budget_evidence_refs
		side_effect_evidence_refs: _haltEvents[0].event.side_effect_evidence_refs
		evidence_refs:             _haltEvents[0].event.evidence_refs
		resume_ref:                _haltEvents[0].event.resume_ref
	})
}
_lastSequence: null | uint
_ledgerHead:   null | #Digest
if len(_events) == 0 {
	_lastSequence: null
	_ledgerHead:   null
}
if len(_events) > 0 {
	_lastSequence: len(_events) - 1
	_ledgerHead:   _events[len(_events)-1].event_sha256
}

project: _planChecks & _publicLedgerChecks & close({
	schema:   "k4-run-projection/v4"
	bindings: _bindings
	document: close({
		operations:                _operationProjection
		operation_results:         _actualOperationResults
		emergency_patches:         _patchProjection
		invariant_control_results: _invariantResults
		execution_result:          _executionResult
		halted:                    _halted
		halt:                      _halt
		event_count:               len(_events)
		last_sequence:             _lastSequence
		ledger_head_event_sha256:  _ledgerHead
	})
})

_existingProjection: context.existing & {
	schema:            "k4-run-projection/v4"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings:          _bindings
	document:          _
}
_expectedProjection: project
validate: _planChecks & _publicLedgerChecks & _existingProjection & {
	schema:   _expectedProjection.schema
	bindings: _expectedProjection.bindings
	document: _expectedProjection.document
}

validate_log: _planChecks & _publicLedgerChecks & _events
