package k4_run

import "list"

context: _

#Text:        string & !=""
#Digest:      string & =~"^[0-9a-f]{64}$"
#ControlID:   string & =~"^control-[0-9a-f]{16}$"
#OperationID: string & =~"^op-[0-9a-f]{16}$"
#Strings: [...#Text] & list.UniqueItems()
#NonEmptyStrings: [#Text, ...#Text] & list.UniqueItems()
#ActualResult:    "pass" | "Finding" | "unknown"
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
	...
}
#CoverageEntry: {
	control_id: #ControlID
	operation_ids: [...#OperationID]
	...
}
#GoalEnvelope: {
	schema:            "k4-goal-document/v4"
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
	schema:            "k4-plan-document/v4"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {goal: #Binding}
	document: {
		status: "executable"
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
#DeferredIssue: close({
	kind:          "Finding" | "unknown"
	statement:     #Text
	evidence_refs: #NonEmptyStrings
})
#OperationEvent: close({
	kind:               "operation-result"
	operation_id:       #OperationID
	result:             #ActualResult
	eligibility_refs:   #NonEmptyStrings
	actual_output_refs: #Strings
	evidence_refs:      #Strings
	trace_refs:         #NonEmptyStrings
	invariant_checks:   [...#InvariantCheck]
	deferred_issues:    [...#DeferredIssue]
})
#HaltEvent: close({
	kind:                       "halt"
	after_operation_id:         null | #OperationID
	next_operation_id:          null | #OperationID
	trigger:                    "route-exhausted" | "operation-non-pass" | "blocked" | "paused" | "cancelled" | "external-change"
	budget_evidence_refs:       #Strings
	side_effect_evidence_refs:  #Strings
	evidence_refs:              #NonEmptyStrings
	resume_ref:                 null | #Text
})
#Event: #OperationEvent | #HaltEvent
#EventEnvelope: close({
	schema:                "k4-run-event/v3"
	sequence:              uint
	recorded_unix_ms:      uint
	previous_event_sha256: null | #Digest
	content_sha256:        #Digest
	event_sha256:          #Digest
	bindings: close({goal: #Binding, plan: #Binding})
	event: #Event
})

_goal: #BoundGoal & context.bindings.goal
_plan: #BoundPlan & context.bindings.plan
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
	_sortedPlanControls: list.SortStrings(_planControlIDs)
	_sortedGoalControls: list.SortStrings(_goalControlIDs)
	_sortedPlanControls: _sortedGoalControls
	for entry in _plan.value.document.coverage.controls {
		_expected: [for operation in _plan.value.document.operations if list.Contains(operation.controlled_by, entry.control_id) {operation.operation_id}]
		_actual: entry.operation_ids
		_actual: _expected
	}
}

_events: [...#EventEnvelope] & context.events
for envelope in _events {
	if envelope.bindings != _bindings {_eventBindingMismatch: _|_}
}
_operationEvents: [for envelope in _events if envelope.event.kind == "operation-result" {envelope}]
_operationEventIDs: [for envelope in _operationEvents {envelope.event.operation_id}]
_operationEventIDsUnique: list.UniqueItems(_operationEventIDs) & true
_haltEvents: [for envelope in _events if envelope.event.kind == "halt" {envelope}]
if len(_haltEvents) > 1 {_multipleHaltEvents: _|_}
if len(_haltEvents) == 1 && _haltEvents[0].sequence != len(_events)-1 {_eventAfterHalt: _|_}

for envelope in _operationEvents {
	_result: envelope.event
	_matches: [for operation in _plan.value.document.operations if operation.operation_id == _result.operation_id {operation}]
	if len(_matches) != 1 {_unknownOperation: _|_}
	if _result.result == "pass" && len(_result.actual_output_refs) == 0 {_passingOperationMissingOutput: _|_}
	if (_result.result == "pass" || _result.result == "Finding") && len(_result.evidence_refs) == 0 {_operationMissingEvidence: _|_}
	if len(_matches) == 1 {
		_operation: _matches[0]
		_prior: [for prior in _events if prior.sequence < envelope.sequence {prior}]
		for dependency in _operation.depends_on {
			_dependencyPasses: [for prior in _prior if prior.event.kind == "operation-result" if prior.event.operation_id == dependency if prior.event.result == "pass" {prior}]
			if len(_dependencyPasses) != 1 {_operationBeforePassingDependency: _|_}
		}
		_expectedInvariantIDs: [for controlID in _operation.controlled_by if _controlTiming[controlID] == "invariant" {controlID}]
		_actualInvariantIDs: [for check in _result.invariant_checks {check.control_id}]
		_actualInvariantIDsUnique: list.UniqueItems(_actualInvariantIDs) & true
		_sortedExpected: list.SortStrings(_expectedInvariantIDs)
		_sortedActual: list.SortStrings(_actualInvariantIDs)
		_sortedExpected: _sortedActual
		for check in _result.invariant_checks {
			if check.result == "pass" && (len(check.actual_refs) == 0 || len(check.comparison_refs) == 0) {_passingInvariantMissingComparison: _|_}
			if (check.result == "pass" || check.result == "Finding") && len(check.evidence_refs) == 0 {_invariantMissingEvidence: _|_}
		}
		_nonPassChecks: [for check in _result.invariant_checks if check.result != "pass" {check}]
		if _result.result == "pass" && len(_nonPassChecks) > 0 {_operationPassedWithNonPassInvariant: _|_}
	}
}

for envelope in _haltEvents {
	_priorOperations: [for prior in _events if prior.sequence < envelope.sequence if prior.event.kind == "operation-result" {prior}]
	_expectedAfter: null | #OperationID
	if len(_priorOperations) == 0 {_expectedAfter: null}
	if len(_priorOperations) > 0 {_expectedAfter: _priorOperations[len(_priorOperations)-1].event.operation_id}
	if envelope.event.after_operation_id != _expectedAfter {_haltPositionMismatch: _|_}
	if envelope.event.next_operation_id != null {
		if !list.Contains(_operationIDs, envelope.event.next_operation_id) {_unknownResumeOperation: _|_}
	}
	if envelope.event.trigger == "route-exhausted" && len(_priorOperations) != len(_operationIDs) {_routeNotExhausted: _|_}
	if envelope.event.trigger == "operation-non-pass" {
		if len(_priorOperations) == 0 {_missingNonPassOperation: _|_}
		if len(_priorOperations) > 0 && _priorOperations[len(_priorOperations)-1].event.result == "pass" {_lastOperationPassed: _|_}
	}
}

_input: #Event & context.input
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
		deferred_issues:    _input.deferred_issues
	})
	_candidateMatches: [for operation in _plan.value.document.operations if operation.operation_id == _input.operation_id {operation}]
	if len(_candidateMatches) != 1 {_candidateUnknownOperation: _|_}
	if list.Contains(_operationEventIDs, _input.operation_id) {_duplicateOperationEvent: _|_}
	if _input.result == "pass" && len(_input.actual_output_refs) == 0 {_candidatePassingOperationMissingOutput: _|_}
	if (_input.result == "pass" || _input.result == "Finding") && len(_input.evidence_refs) == 0 {_candidateOperationMissingEvidence: _|_}
	if len(_candidateMatches) == 1 {
		_candidateOperation: _candidateMatches[0]
		for dependency in _candidateOperation.depends_on {
			if len([for prior in _events if prior.event.kind == "operation-result" if prior.event.operation_id == dependency if prior.event.result == "pass" {prior}]) != 1 {_candidateBeforePassingDependency: _|_}
		}
		_expectedInvariantIDs: [for controlID in _candidateOperation.controlled_by if _controlTiming[controlID] == "invariant" {controlID}]
		_actualInvariantIDs: [for check in _input.invariant_checks {check.control_id}]
		_actualInvariantIDsUnique: list.UniqueItems(_actualInvariantIDs) & true
		_sortedExpected: list.SortStrings(_expectedInvariantIDs)
		_sortedActual: list.SortStrings(_actualInvariantIDs)
		_sortedExpected: _sortedActual
		for check in _input.invariant_checks {
			if check.result == "pass" && (len(check.actual_refs) == 0 || len(check.comparison_refs) == 0) {_candidatePassingInvariantMissingComparison: _|_}
			if (check.result == "pass" || check.result == "Finding") && len(check.evidence_refs) == 0 {_candidateInvariantMissingEvidence: _|_}
		}
		_nonPassChecks: [for check in _input.invariant_checks if check.result != "pass" {check}]
		if _input.result == "pass" && len(_nonPassChecks) > 0 {_candidateOperationPassedWithNonPassInvariant: _|_}
	}
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
	if len(_haltEvents) != 0 {_duplicateHalt: _|_}
	_expectedAfter: null | #OperationID
	if len(_operationEvents) == 0 {_expectedAfter: null}
	if len(_operationEvents) > 0 {_expectedAfter: _operationEvents[len(_operationEvents)-1].event.operation_id}
	if _input.after_operation_id != _expectedAfter {_candidateHaltPositionMismatch: _|_}
	if _input.next_operation_id != null {
		if !list.Contains(_operationIDs, _input.next_operation_id) {_candidateUnknownResumeOperation: _|_}
	}
	if _input.trigger == "route-exhausted" && len(_operationEvents) != len(_operationIDs) {_candidateRouteNotExhausted: _|_}
	if _input.trigger == "operation-non-pass" {
		if len(_operationEvents) == 0 {_candidateMissingNonPassOperation: _|_}
		if len(_operationEvents) > 0 && _operationEvents[len(_operationEvents)-1].event.result == "pass" {_candidateLastOperationPassed: _|_}
	}
}
if len(_haltEvents) != 0 {_cannotAppendAfterHalt: _|_}

_candidateDependencyEligibility: {
	if _input.kind == "operation-result" {
		_matches: [for operation in _plan.value.document.operations if operation.operation_id == _input.operation_id {operation}]
		if len(_matches) == 1 {
			for dependency in _matches[0].depends_on {
				if len([for prior in _events if prior.event.kind == "operation-result" if prior.event.operation_id == dependency if prior.event.result == "pass" {prior}]) != 1 {
					_invalid: error("operation dependency must already have exactly one passing result in the Run journal")
				}
			}
		}
	}
}

_candidateInvariantEligibility: {
	if _input.kind == "operation-result" {
		_matches: [for operation in _plan.value.document.operations if operation.operation_id == _input.operation_id {operation}]
		if len(_matches) == 1 {
			_expectedIDs: [for controlID in _matches[0].controlled_by if _controlTiming[controlID] == "invariant" {controlID}]
			_actualIDs: [for check in _input.invariant_checks {check.control_id}]
			_actualIDsUnique: list.UniqueItems(_actualIDs) & true
			_sortedExpected: list.SortStrings(_expectedIDs)
			_sortedActual: list.SortStrings(_actualIDs)
			_sortedExpected: _sortedActual
			for check in _input.invariant_checks {
				if check.result == "pass" && (len(check.actual_refs) == 0 || len(check.comparison_refs) == 0) {
					_invalid: error("passing invariant check requires actual and comparison references")
				}
				if (check.result == "pass" || check.result == "Finding") && len(check.evidence_refs) == 0 {
					_invalid: error("decisive invariant check requires evidence")
				}
			}
			_nonPass: [for check in _input.invariant_checks if check.result != "pass" {check}]
			if _input.result == "pass" && len(_nonPass) > 0 {
				_invalid: error("operation cannot pass with a non-pass invariant check")
			}
		}
	}
}

next_event: _planChecks & _candidateDependencyEligibility & _candidateInvariantEligibility & close({
	schema:   "k4-run-event/v3"
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
	deferred_issues:    [...#DeferredIssue]
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
	control_id:  #ControlID
	result:      #ActualResult
	observations: [#ControlObservation, ...#ControlObservation]
})

_operationProjection: [for operation in _plan.value.document.operations {
	_matches: [for envelope in _operationEvents if envelope.event.operation_id == operation.operation_id {envelope}]
	if len(_matches) == 0 {
		close({
			operation_id: operation.operation_id
			result: "not-run"
			event_sequence: null
			eligibility_refs: []
			actual_output_refs: []
			evidence_refs: []
			trace_refs: []
			deferred_issues: []
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
			deferred_issues:    _matches[0].event.deferred_issues
		})
	}
}]
_actualOperationResults: [for operation in _operationProjection if operation.result != "not-run" {operation}]
_invariantResults: [for control in _goal.value.document.control_contracts if control.check_timing == "invariant" {
	_nested: [for envelope in _operationEvents {
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
	}]
	_observations: list.Concat(_nested)
	if len(_observations) > 0 {
		_findings: [for observation in _observations if observation.result == "Finding" {observation}]
		_unknowns: [for observation in _observations if observation.result == "unknown" {observation}]
		_result: *"pass" | "Finding" | "unknown"
		if len(_findings) > 0 {_result: "Finding"}
		if len(_findings) == 0 && len(_unknowns) > 0 {_result: "unknown"}
		close({
			control_id:  control.control_id
			result:      _result
			observations: _observations
		})
	}
}]
_operationStates: [for result in _operationProjection {result.result}]
_operationFindings: [for state in _operationStates if state == "Finding" {state}]
_operationIncomplete: [for state in _operationStates if state == "unknown" || state == "not-run" {state}]
_executionResult: *"pass" | "Finding" | "unknown"
if len(_operationFindings) > 0 {_executionResult: "Finding"}
if len(_operationFindings) == 0 && len(_operationIncomplete) > 0 {_executionResult: "unknown"}

_halted: len(_haltEvents) == 1
_halt: null | _
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
_ledgerHead: null | #Digest
if len(_events) == 0 {
	_lastSequence: null
	_ledgerHead: null
}
if len(_events) > 0 {
	_lastSequence: len(_events)-1
	_ledgerHead: _events[len(_events)-1].event_sha256
}

project: _planChecks & close({
	schema:   "k4-run-projection/v3"
	bindings: _bindings
	document: close({
		operations:                    _operationProjection
		operation_results:             _actualOperationResults
		invariant_control_results:     _invariantResults
		execution_result:              _executionResult
		halted:                       _halted
		halt:                         _halt
		event_count:                  len(_events)
		last_sequence:                _lastSequence
		ledger_head_event_sha256:      _ledgerHead
	})
})

validate_log: _planChecks & _events
