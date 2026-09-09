package k4_run

import "list"

context: _

#Text:        string & !=""
#Digest:      string & =~"^[0-9a-f]{64}$"
#PointID:     string & =~"^point-[0-9a-f]{16}$"
#ControlID:   string & =~"^control-[0-9a-f]{16}$"
#OperationID: string & =~"^op-[0-9a-f]{16}$"
#Strings: [...#Text] & list.UniqueItems()
#NonEmptyStrings: [#Text, ...#Text] & list.UniqueItems()
#Binding: close({
	ref:            #Text
	sha256:         #Digest
	content_sha256: #Digest
})
#ActualResult:    "pass" | "Finding" | "unknown"
#ProjectedResult: #ActualResult | "not-run"
#GoalPoint: {
	point_id: #PointID
	...
}
#GoalControl: {
	control_id:   #ControlID
	check_timing: "invariant" | "terminal"
	...
}
#PlanOperation: {
	operation_id: #OperationID
	depends_on: [...#OperationID]
	satisfies: [...#PointID]
	controlled_by: [...#ControlID]
	...
}
#CoverageEntry: {
	operation_ids: [...#OperationID]
	...
}
#GoalEnvelope: {
	schema:            "k4-goal-document/v3"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {...}
	document: {
		status: "frozen"
		acceptance_points: [#GoalPoint, ...#GoalPoint]
		control_contracts: [...#GoalControl]
		...
	}
}
#PlanEnvelope: {
	schema:            "k4-plan-document/v3"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {
		goal: #Binding
	}
	document: {
		status: "executable"
		operations: [#PlanOperation, ...#PlanOperation]
		coverage: {
			acceptance: [...#CoverageEntry]
			controls: [...#CoverageEntry]
		}
		...
	}
}
#BoundGoal: close({
	binding: #Binding
	value:   #GoalEnvelope
})
#BoundPlan: close({
	binding: #Binding
	value:   #PlanEnvelope
})
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
	invariant_checks: [...#InvariantCheck]
	deferred_issues: [...#DeferredIssue]
})
#AcceptanceEvent: close({
	kind:            "acceptance-result"
	point_id:        #PointID
	result:          #ActualResult
	actual_refs:     #Strings
	comparison_refs: #Strings
	evidence_refs:   #Strings
})
#ControlEvent: close({
	kind:            "control-result"
	control_id:      #ControlID
	result:          #ActualResult
	actual_refs:     #Strings
	trace_refs:      #NonEmptyStrings
	comparison_refs: #Strings
	evidence_refs:   #Strings
})
#StopEvent: close({
	kind:                      "stop"
	stop_state:                "completed" | "paused" | "failed" | "cancelled"
	budget_evidence_refs:      #Strings
	side_effect_evidence_refs: #Strings
	evidence_refs:             #NonEmptyStrings
	resume_ref:                null | #Text
})
#Event: #OperationEvent | #AcceptanceEvent | #ControlEvent | #StopEvent
#EventEnvelope: close({
	schema:                "k4-run-event/v2"
	sequence:              uint
	recorded_unix_ms:      uint
	previous_event_sha256: null | #Digest
	content_sha256:        #Digest
	event_sha256:          #Digest
	bindings: close({
		goal: #Binding
		plan: #Binding
	})
	event: #Event
})

_goal:            #BoundGoal & context.bindings.goal
_plan:            #BoundPlan & context.bindings.plan
_planGoalBinding: _plan.value.bindings.goal
_planGoalBinding: _goal.binding
_bindings: close({
	goal: _goal.binding
	plan: _plan.binding
})
_pointIDs: [for point in _goal.value.document.acceptance_points {point.point_id}]
_controlIDs: [for control in _goal.value.document.control_contracts {control.control_id}]
_operationIDs: [for operation in _plan.value.document.operations {operation.operation_id}]
_controlTiming: {for control in _goal.value.document.control_contracts {
	(control.control_id): control.check_timing
}}

_planAcceptanceIDs: [for entry in _plan.value.document.coverage.acceptance {entry.point_id}]
_planControlIDs: [for entry in _plan.value.document.coverage.controls {entry.control_id}]
_sortedPlanAcceptance: list.SortStrings(_planAcceptanceIDs)
_sortedPlanAcceptance: list.SortStrings(_pointIDs)
_sortedPlanControls:   list.SortStrings(_planControlIDs)
_sortedPlanControls:   list.SortStrings(_controlIDs)
_planChecks: {
	_planAcceptanceIDs: [for entry in _plan.value.document.coverage.acceptance {entry.point_id}]
	_planControlIDs: [for entry in _plan.value.document.coverage.controls {entry.control_id}]
	_sortedPlanAcceptance: list.SortStrings(_planAcceptanceIDs)
	_sortedPlanAcceptance: list.SortStrings(_pointIDs)
	_sortedPlanControls:   list.SortStrings(_planControlIDs)
	_sortedPlanControls:   list.SortStrings(_controlIDs)
	_acceptanceCoverage: [for entry in _plan.value.document.coverage.acceptance {
		_expected: [for operation in _plan.value.document.operations if list.Contains(operation.satisfies, entry.point_id) {operation.operation_id}]
		_actual: entry.operation_ids
		_actual: _expected
	}]
	_controlCoverage: [for entry in _plan.value.document.coverage.controls {
		_expected: [for operation in _plan.value.document.operations if list.Contains(operation.controlled_by, entry.control_id) {operation.operation_id}]
		_actual: entry.operation_ids
		_actual: _expected
	}]
}

_events: [...#EventEnvelope] & context.events
for envelope in _events {
	if envelope.bindings != _bindings {_eventBindingMismatch: _|_}
}
_operationEventIDs: [for envelope in _events if envelope.event.kind == "operation-result" {envelope.event.operation_id}]
_acceptanceEventIDs: [for envelope in _events if envelope.event.kind == "acceptance-result" {envelope.event.point_id}]
_controlEventIDs: [for envelope in _events if envelope.event.kind == "control-result" {envelope.event.control_id}]
_operationEventIDsUnique:  list.UniqueItems(_operationEventIDs) & true
_acceptanceEventIDsUnique: list.UniqueItems(_acceptanceEventIDs) & true
_controlEventIDsUnique:    list.UniqueItems(_controlEventIDs) & true
_stopEvents: [for envelope in _events if envelope.event.kind == "stop" {envelope}]
if len(_stopEvents) > 1 {_multipleStopEvents: _|_}
if len(_stopEvents) == 1 && _stopEvents[0].sequence != len(_events)-1 {_eventAfterStop: _|_}

for envelope in _events if envelope.event.kind == "operation-result" {
	_result: envelope.event
	_matches: [for operation in _plan.value.document.operations if operation.operation_id == _result.operation_id {operation}]
	if len(_matches) != 1 {_unknownOperation: _|_}
	if _result.result == "pass" && len(_result.actual_output_refs) == 0 {_passingOperationMissingOutput: _|_}
	if (_result.result == "pass" || _result.result == "Finding") && len(_result.evidence_refs) == 0 {_operationMissingEvidence: _|_}
	if len(_matches) == 1 {
		_operation: _matches[0]
		_prior: [for prior in _events if prior.sequence < envelope.sequence {prior}]
		for dependency in _operation.depends_on {
			_dependencyEvents: [for prior in _prior if prior.event.kind == "operation-result" if prior.event.operation_id == dependency {prior.event}]
			if len(_dependencyEvents) != 1 {_operationBeforeDependency: _|_}
			if len(_dependencyEvents) == 1 && _dependencyEvents[0].result != "pass" {_operationAfterNonPassDependency: _|_}
		}
		_expectedInvariantIDs: [for controlID in _operation.controlled_by if _controlTiming[controlID] == "invariant" {controlID}]
		_actualInvariantIDs: [for check in _result.invariant_checks {check.control_id}]
		_actualInvariantIDsUnique:   list.UniqueItems(_actualInvariantIDs) & true
		_sortedExpectedInvariantIDs: list.SortStrings(_expectedInvariantIDs)
		_sortedActualInvariantIDs:   list.SortStrings(_actualInvariantIDs)
		_sortedExpectedInvariantIDs: _sortedActualInvariantIDs
		for check in _result.invariant_checks {
			if check.result == "pass" && (len(check.actual_refs) == 0 || len(check.comparison_refs) == 0) {_passingInvariantMissingComparison: _|_}
			if (check.result == "pass" || check.result == "Finding") && len(check.evidence_refs) == 0 {_invariantMissingEvidence: _|_}
		}
		_nonPassChecks: [for check in _result.invariant_checks if check.result != "pass" {check.control_id}]
		if _result.result == "pass" && len(_nonPassChecks) > 0 {_operationPassedWithNonPassInvariant: _|_}
	}
}

for envelope in _events if envelope.event.kind == "acceptance-result" {
	_result: envelope.event
	if !list.Contains(_pointIDs, _result.point_id) {_unknownAcceptancePoint: _|_}
	if _result.result == "pass" && (len(_result.actual_refs) == 0 || len(_result.comparison_refs) == 0) {_passingAcceptanceMissingComparison: _|_}
	if (_result.result == "pass" || _result.result == "Finding") && len(_result.evidence_refs) == 0 {_acceptanceMissingEvidence: _|_}
	if _result.result == "pass" {
		_coverage: [for entry in _plan.value.document.coverage.acceptance if entry.point_id == _result.point_id {entry}]
		if len(_coverage) != 1 {_acceptanceCoverageMissing: _|_}
		if len(_coverage) == 1 {
			for operationID in _coverage[0].operation_ids {
				_priorPasses: [for prior in _events if prior.sequence < envelope.sequence if prior.event.kind == "operation-result" if prior.event.operation_id == operationID if prior.event.result == "pass" {prior}]
				if len(_priorPasses) != 1 {_prematureAcceptancePass: _|_}
			}
		}
	}
}

for envelope in _events if envelope.event.kind == "control-result" {
	_result: envelope.event
	if !list.Contains(_controlIDs, _result.control_id) {_unknownControl: _|_}
	if _controlTiming[_result.control_id] != "terminal" {_invariantControlCannotUseTerminalEvent: _|_}
	if _result.result == "pass" && (len(_result.actual_refs) == 0 || len(_result.comparison_refs) == 0) {_passingControlMissingComparison: _|_}
	if (_result.result == "pass" || _result.result == "Finding") && len(_result.evidence_refs) == 0 {_controlMissingEvidence: _|_}
}

for envelope in _events if envelope.event.kind == "stop" {
	_stop: envelope.event
	if _stop.stop_state == "completed" && _stop.resume_ref != null {_completedHasResume: _|_}
	if _stop.stop_state != "completed" && _stop.resume_ref == null {_nonCompletedMissingResume: _|_}
	if _stop.stop_state == "completed" {
		if len(_stop.budget_evidence_refs) == 0 || len(_stop.side_effect_evidence_refs) == 0 {_completedMissingBoundaryEvidence: _|_}
		for operationID in _operationIDs {
			_passes: [for prior in _events if prior.sequence < envelope.sequence if prior.event.kind == "operation-result" if prior.event.operation_id == operationID if prior.event.result == "pass" {prior}]
			if len(_passes) != 1 {_completedWithIncompleteOperation: _|_}
		}
		for pointID in _pointIDs {
			_passes: [for prior in _events if prior.sequence < envelope.sequence if prior.event.kind == "acceptance-result" if prior.event.point_id == pointID if prior.event.result == "pass" {prior}]
			if len(_passes) != 1 {_completedWithIncompleteAcceptance: _|_}
		}
		for controlID in _controlIDs {
			if _controlTiming[controlID] == "terminal" {
				_passes: [for prior in _events if prior.sequence < envelope.sequence if prior.event.kind == "control-result" if prior.event.control_id == controlID if prior.event.result == "pass" {prior}]
				if len(_passes) != 1 {_completedWithIncompleteTerminalControl: _|_}
			}
			if _controlTiming[controlID] == "invariant" {
				_mappedOperations: [for entry in _plan.value.document.coverage.controls if entry.control_id == controlID {for operationID in entry.operation_ids {operationID}}]
				_flatMappedOperations: list.Concat(_mappedOperations)
				for operationID in _flatMappedOperations {
					_checks: [for prior in _events if prior.sequence < envelope.sequence if prior.event.kind == "operation-result" if prior.event.operation_id == operationID {
						for check in prior.event.invariant_checks if check.control_id == controlID && check.result == "pass" {check}
					}]
					_flatChecks: list.Concat(_checks)
					if len(_flatChecks) != 1 {_completedWithIncompleteInvariantControl: _|_}
				}
			}
		}
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
			_dependencyPasses: [for prior in _events if prior.event.kind == "operation-result" if prior.event.operation_id == dependency if prior.event.result == "pass" {prior}]
			if len(_dependencyPasses) != 1 {_candidateOperationBeforeDependency: _|_}
		}
		_expectedInvariantIDs: [for controlID in _candidateOperation.controlled_by if _controlTiming[controlID] == "invariant" {controlID}]
		_actualInvariantIDs: [for check in _input.invariant_checks {check.control_id}]
		_actualInvariantIDsUnique:   list.UniqueItems(_actualInvariantIDs) & true
		_sortedExpectedInvariantIDs: list.SortStrings(_expectedInvariantIDs)
		_sortedActualInvariantIDs:   list.SortStrings(_actualInvariantIDs)
		_sortedExpectedInvariantIDs: _sortedActualInvariantIDs
		for check in _input.invariant_checks {
			if check.result == "pass" && (len(check.actual_refs) == 0 || len(check.comparison_refs) == 0) {_candidatePassingInvariantMissingComparison: _|_}
			if (check.result == "pass" || check.result == "Finding") && len(check.evidence_refs) == 0 {_candidateInvariantMissingEvidence: _|_}
		}
		_candidateNonPassChecks: [for check in _input.invariant_checks if check.result != "pass" {check.control_id}]
		if _input.result == "pass" && len(_candidateNonPassChecks) > 0 {_candidateOperationPassedWithNonPassInvariant: _|_}
	}
}
if _input.kind == "acceptance-result" {
	_generatedEvent: close({
		kind:            _input.kind
		point_id:        _input.point_id
		result:          _input.result
		actual_refs:     _input.actual_refs
		comparison_refs: _input.comparison_refs
		evidence_refs:   _input.evidence_refs
	})
	if !list.Contains(_pointIDs, _input.point_id) {_candidateUnknownPoint: _|_}
	if list.Contains(_acceptanceEventIDs, _input.point_id) {_duplicateAcceptanceEvent: _|_}
	if _input.result == "pass" && (len(_input.actual_refs) == 0 || len(_input.comparison_refs) == 0) {_candidatePassingAcceptanceMissingComparison: _|_}
	if (_input.result == "pass" || _input.result == "Finding") && len(_input.evidence_refs) == 0 {_candidateAcceptanceMissingEvidence: _|_}
	if _input.result == "pass" {
		_coverage: [for entry in _plan.value.document.coverage.acceptance if entry.point_id == _input.point_id {entry}]
		if len(_coverage) != 1 {_candidateAcceptanceCoverageMissing: _|_}
		if len(_coverage) == 1 {
			for operationID in _coverage[0].operation_ids {
				_passes: [for prior in _events if prior.event.kind == "operation-result" if prior.event.operation_id == operationID if prior.event.result == "pass" {prior}]
				if len(_passes) != 1 {_candidatePrematureAcceptance: _|_}
			}
		}
	}
}
if _input.kind == "control-result" {
	_generatedEvent: close({
		kind:            _input.kind
		control_id:      _input.control_id
		result:          _input.result
		actual_refs:     _input.actual_refs
		trace_refs:      _input.trace_refs
		comparison_refs: _input.comparison_refs
		evidence_refs:   _input.evidence_refs
	})
	if !list.Contains(_controlIDs, _input.control_id) {_candidateUnknownControl: _|_}
	if _controlTiming[_input.control_id] != "terminal" {_candidateInvariantControlEvent: _|_}
	if list.Contains(_controlEventIDs, _input.control_id) {_duplicateControlEvent: _|_}
	if _input.result == "pass" && (len(_input.actual_refs) == 0 || len(_input.comparison_refs) == 0) {_candidatePassingControlMissingComparison: _|_}
	if (_input.result == "pass" || _input.result == "Finding") && len(_input.evidence_refs) == 0 {_candidateControlMissingEvidence: _|_}
}
if _input.kind == "stop" {
	_generatedEvent: close({
		kind:                      _input.kind
		stop_state:                _input.stop_state
		budget_evidence_refs:      _input.budget_evidence_refs
		side_effect_evidence_refs: _input.side_effect_evidence_refs
		evidence_refs:             _input.evidence_refs
		resume_ref:                _input.resume_ref
	})
	if len(_stopEvents) != 0 {_duplicateStop: _|_}
	if _input.stop_state == "completed" && _input.resume_ref != null {_candidateCompletedHasResume: _|_}
	if _input.stop_state != "completed" && _input.resume_ref == null {_candidateNonCompletedMissingResume: _|_}
	if _input.stop_state == "completed" {
		if len(_input.budget_evidence_refs) == 0 || len(_input.side_effect_evidence_refs) == 0 {_candidateCompletedMissingBoundaryEvidence: _|_}
		for operationID in _operationIDs {
			_passes: [for prior in _events if prior.event.kind == "operation-result" if prior.event.operation_id == operationID if prior.event.result == "pass" {prior}]
			if len(_passes) != 1 {_candidateCompletedWithIncompleteOperation: _|_}
		}
		for pointID in _pointIDs {
			_passes: [for prior in _events if prior.event.kind == "acceptance-result" if prior.event.point_id == pointID if prior.event.result == "pass" {prior}]
			if len(_passes) != 1 {_candidateCompletedWithIncompleteAcceptance: _|_}
		}
		for controlID in _controlIDs {
			if _controlTiming[controlID] == "terminal" {
				_passes: [for prior in _events if prior.event.kind == "control-result" if prior.event.control_id == controlID if prior.event.result == "pass" {prior}]
				if len(_passes) != 1 {_candidateCompletedWithIncompleteTerminalControl: _|_}
			}
			if _controlTiming[controlID] == "invariant" {
				_mapped: [for entry in _plan.value.document.coverage.controls if entry.control_id == controlID {for operationID in entry.operation_ids {operationID}}]
				_flatMapped: list.Concat(_mapped)
				for operationID in _flatMapped {
					_checks: [for prior in _events if prior.event.kind == "operation-result" if prior.event.operation_id == operationID {
						for check in prior.event.invariant_checks if check.control_id == controlID && check.result == "pass" {check}
					}]
					_flatChecks: list.Concat(_checks)
					if len(_flatChecks) != 1 {_candidateCompletedWithIncompleteInvariantControl: _|_}
				}
			}
		}
	}
}
if len(_stopEvents) != 0 {_cannotAppendAfterStop: _|_}

_nextChecks: {
	if _input.kind == "operation-result" {
		_matches: [for operation in _plan.value.document.operations if operation.operation_id == _input.operation_id {operation}]
		if len(_matches) != 1 {_invalid: _|_}
		if list.Contains(_operationEventIDs, _input.operation_id) {_invalid: _|_}
		if _input.result == "pass" && len(_input.actual_output_refs) == 0 {_invalid: _|_}
		if (_input.result == "pass" || _input.result == "Finding") && len(_input.evidence_refs) == 0 {_invalid: _|_}
		if len(_matches) == 1 {
			_operation: _matches[0]
			for dependency in _operation.depends_on {
				if len([for prior in _events if prior.event.kind == "operation-result" if prior.event.operation_id == dependency if prior.event.result == "pass" {prior}]) != 1 {_invalid: _|_}
			}
			_expectedInvariantIDs: [for controlID in _operation.controlled_by if _controlTiming[controlID] == "invariant" {controlID}]
			_actualInvariantIDs: [for check in _input.invariant_checks {check.control_id}]
			_actualInvariantIDsUnique:   list.UniqueItems(_actualInvariantIDs) & true
			_sortedExpectedInvariantIDs: list.SortStrings(_expectedInvariantIDs)
			_sortedActualInvariantIDs:   list.SortStrings(_actualInvariantIDs)
			_sortedExpectedInvariantIDs: _sortedActualInvariantIDs
			for check in _input.invariant_checks {
				if check.result == "pass" && (len(check.actual_refs) == 0 || len(check.comparison_refs) == 0) {_invalid: _|_}
				if (check.result == "pass" || check.result == "Finding") && len(check.evidence_refs) == 0 {_invalid: _|_}
			}
			_nonPassChecks: [for check in _input.invariant_checks if check.result != "pass" {check.control_id}]
			if _input.result == "pass" && len(_nonPassChecks) > 0 {_invalid: _|_}
		}
	}
	if _input.kind == "acceptance-result" {
		if !list.Contains(_pointIDs, _input.point_id) {_invalid: _|_}
		if list.Contains(_acceptanceEventIDs, _input.point_id) {_invalid: _|_}
		if _input.result == "pass" && (len(_input.actual_refs) == 0 || len(_input.comparison_refs) == 0) {_invalid: _|_}
		if (_input.result == "pass" || _input.result == "Finding") && len(_input.evidence_refs) == 0 {_invalid: _|_}
		if _input.result == "pass" {
			_coverage: [for entry in _plan.value.document.coverage.acceptance if entry.point_id == _input.point_id {entry}]
			if len(_coverage) != 1 {_invalid: _|_}
			if len(_coverage) == 1 {
				for operationID in _coverage[0].operation_ids {
					if len([for prior in _events if prior.event.kind == "operation-result" if prior.event.operation_id == operationID if prior.event.result == "pass" {prior}]) != 1 {_invalid: _|_}
				}
			}
		}
	}
	if _input.kind == "control-result" {
		if !list.Contains(_controlIDs, _input.control_id) {_invalid: _|_}
		if _controlTiming[_input.control_id] != "terminal" {_invalid: _|_}
		if list.Contains(_controlEventIDs, _input.control_id) {_invalid: _|_}
		if _input.result == "pass" && (len(_input.actual_refs) == 0 || len(_input.comparison_refs) == 0) {_invalid: _|_}
		if (_input.result == "pass" || _input.result == "Finding") && len(_input.evidence_refs) == 0 {_invalid: _|_}
	}
	if _input.kind == "stop" {
		if len(_stopEvents) != 0 {_invalid: _|_}
		if _input.stop_state == "completed" && _input.resume_ref != null {_invalid: _|_}
		if _input.stop_state != "completed" && _input.resume_ref == null {_invalid: _|_}
		if _input.stop_state == "completed" {
			if len(_input.budget_evidence_refs) == 0 || len(_input.side_effect_evidence_refs) == 0 {_invalid: _|_}
			for operationID in _operationIDs {
				if len([for prior in _events if prior.event.kind == "operation-result" if prior.event.operation_id == operationID if prior.event.result == "pass" {prior}]) != 1 {_invalid: _|_}
			}
			for pointID in _pointIDs {
				if len([for prior in _events if prior.event.kind == "acceptance-result" if prior.event.point_id == pointID if prior.event.result == "pass" {prior}]) != 1 {_invalid: _|_}
			}
			for controlID in _controlIDs {
				if _controlTiming[controlID] == "terminal" {
					if len([for prior in _events if prior.event.kind == "control-result" if prior.event.control_id == controlID if prior.event.result == "pass" {prior}]) != 1 {_invalid: _|_}
				}
				if _controlTiming[controlID] == "invariant" {
					for entry in _plan.value.document.coverage.controls if entry.control_id == controlID {
						for operationID in entry.operation_ids {
							if len(list.Concat([for prior in _events if prior.event.kind == "operation-result" if prior.event.operation_id == operationID {
								[for check in prior.event.invariant_checks if check.control_id == controlID && check.result == "pass" {check}]
							}])) != 1 {_invalid: _|_}
						}
					}
				}
			}
		}
	}
	if len(_stopEvents) != 0 {_invalid: _|_}
}

next_event: _planChecks & _nextChecks & close({
	schema:   "k4-run-event/v2"
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
	deferred_issues: [...#DeferredIssue]
})
#ProjectedAcceptance: close({
	point_id:        #PointID
	result:          #ProjectedResult
	event_sequence:  null | uint
	actual_refs:     #Strings
	comparison_refs: #Strings
	evidence_refs:   #Strings
})
#ControlObservation: close({
	event_sequence:  uint
	operation_id:    null | #OperationID
	result:          #ActualResult
	actual_refs:     #Strings
	trace_refs:      #Strings
	comparison_refs: #Strings
	evidence_refs:   #Strings
})
#ProjectedControl: close({
	control_id:            #ControlID
	required_check_timing: "invariant" | "terminal"
	result:                #ProjectedResult
	observations: [...#ControlObservation]
})

_operationProjection: [for operation in _plan.value.document.operations {
	_matches: [for envelope in _events if envelope.event.kind == "operation-result" if envelope.event.operation_id == operation.operation_id {envelope}]
	if len(_matches) == 0 {
		close({
			operation_id:   operation.operation_id
			result:         "not-run"
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
_acceptanceProjection: [for point in _goal.value.document.acceptance_points {
	_matches: [for envelope in _events if envelope.event.kind == "acceptance-result" if envelope.event.point_id == point.point_id {envelope}]
	if len(_matches) == 0 {
		close({
			point_id:       point.point_id
			result:         "not-run"
			event_sequence: null
			actual_refs: []
			comparison_refs: []
			evidence_refs: []
		})
	}
	if len(_matches) == 1 {
		close({
			point_id:        point.point_id
			result:          _matches[0].event.result
			event_sequence:  _matches[0].sequence
			actual_refs:     _matches[0].event.actual_refs
			comparison_refs: _matches[0].event.comparison_refs
			evidence_refs:   _matches[0].event.evidence_refs
		})
	}
}]
_controlProjection: [for control in _goal.value.document.control_contracts {
	if control.check_timing == "invariant" {
		_nested: [for envelope in _events if envelope.event.kind == "operation-result" {
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
		_findings: [for observation in _observations if observation.result == "Finding" {observation}]
		_unknowns: [for observation in _observations if observation.result == "unknown" {observation}]
		_result: *"pass" | "Finding" | "unknown" | "not-run"
		if len(_observations) == 0 {_result: "not-run"}
		if len(_observations) > 0 && len(_findings) > 0 {_result: "Finding"}
		if len(_observations) > 0 && len(_findings) == 0 && len(_unknowns) > 0 {_result: "unknown"}
		close({
			control_id:            control.control_id
			required_check_timing: control.check_timing
			result:                _result
			observations:          _observations
		})
	}
	if control.check_timing == "terminal" {
		_matches: [for envelope in _events if envelope.event.kind == "control-result" if envelope.event.control_id == control.control_id {envelope}]
		if len(_matches) == 0 {
			close({
				control_id:            control.control_id
				required_check_timing: control.check_timing
				result:                "not-run"
				observations: []
			})
		}
		if len(_matches) == 1 {
			close({
				control_id:            control.control_id
				required_check_timing: control.check_timing
				result:                _matches[0].event.result
				observations: [close({
					event_sequence:  _matches[0].sequence
					operation_id:    null
					result:          _matches[0].event.result
					actual_refs:     _matches[0].event.actual_refs
					trace_refs:      _matches[0].event.trace_refs
					comparison_refs: _matches[0].event.comparison_refs
					evidence_refs:   _matches[0].event.evidence_refs
				})]
			})
		}
	}
}]

_projectedStates: [
	for result in _operationProjection {result.result},
	for result in _acceptanceProjection {result.result},
	for result in _controlProjection {result.result},
]
_projectedFindings: [for state in _projectedStates if state == "Finding" {state}]
_projectedIncomplete: [for state in _projectedStates if state == "unknown" || state == "not-run" {state}]
_projectionResult: *"pass" | "Finding" | "unknown"
if len(_projectedFindings) > 0 {_projectionResult: "Finding"}
if len(_projectedFindings) == 0 && (len(_projectedIncomplete) > 0 || len(_stopEvents) == 0) {_projectionResult: "unknown"}

_stopState:      *"running" | "completed" | "paused" | "failed" | "cancelled"
_resumeRef:      *null | #Text
_budgetRefs:     #Strings
_sideEffectRefs: #Strings
if len(_stopEvents) == 0 {
	_stopState: "running"
	_resumeRef: null
	_budgetRefs: []
	_sideEffectRefs: []
}
if len(_stopEvents) == 1 {
	_stopState:      _stopEvents[0].event.stop_state
	_resumeRef:      _stopEvents[0].event.resume_ref
	_budgetRefs:     _stopEvents[0].event.budget_evidence_refs
	_sideEffectRefs: _stopEvents[0].event.side_effect_evidence_refs
}
if (_projectionResult == "pass") != (_stopState == "completed") {_projectionStopMismatch: _|_}

_lastSequence: null | uint
if len(_events) == 0 {_lastSequence: null}
if len(_events) > 0 {_lastSequence: len(_events) - 1}

_projection: close({
	operation_results:         _operationProjection
	acceptance_results:        _acceptanceProjection
	control_results:           _controlProjection
	budget_evidence_refs:      _budgetRefs
	side_effect_evidence_refs: _sideEffectRefs
	stop_state:                _stopState
	resume_ref:                _resumeRef
	result:                    _projectionResult
	event_count:               len(_events)
	last_sequence:             _lastSequence
})

project: _planChecks & close({
	schema:   "k4-run-projection/v2"
	bindings: _bindings
	document: _projection
})

validate_log: _planChecks & _events
