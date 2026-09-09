package k4_plan

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
#PointID:     string & =~"^point-[0-9a-f]{16}$"
#ControlID:   string & =~"^control-[0-9a-f]{16}$"
#OperationID: string & =~"^op-[0-9a-f]{16}$"
#Strings: [...#Text] & list.UniqueItems()
#NonEmptyStrings: [#Text, ...#Text] & list.UniqueItems()
#UInts: [...uint] & list.UniqueItems()
#AtLeastTwoUInts: [uint, uint, ...uint] & list.UniqueItems()
#Binding: close({
	ref:            #Text
	sha256:         #Digest
	content_sha256: #Digest
})
#GoalEnvelope: close({
	schema:            "k4-goal-document/v3"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {...}
	document: close({
		status: "frozen"
		execution_envelope: close({
			available_tools: #NonEmptyStrings
			...
		})
		acceptance_points: [close({point_id: #PointID, ...}), ...close({point_id: #PointID, ...})]
		control_contracts: [...close({control_id: #ControlID, ...})]
		...
	})
})
#BoundGoal: close({
	binding: #Binding
	value:   #GoalEnvelope
})
#Route: close({
	claim:           #Text
	supporting_refs: #NonEmptyStrings
	counter_refs:    #Strings
})
#OperationInput: close({
	depends_on_indices:   #UInts
	satisfies:            #Strings
	controlled_by:        #Strings
	tool_ref:             #Text
	responsible_ref:      #Text
	read_refs:            #NonEmptyStrings
	write_refs:           #NonEmptyStrings
	permission_refs:      #NonEmptyStrings
	resource_refs:        #NonEmptyStrings
	maximum_side_effects: #NonEmptyStrings
	pre_checks:           #NonEmptyStrings
	post_checks:          #NonEmptyStrings
	idempotency:          #Text
	retry_limit:          uint
	recovery:             #Text
})
#Operation: close({
	operation_id:         #OperationID
	depends_on:           #Strings
	satisfies:            #Strings
	controlled_by:        #Strings
	tool_ref:             #Text
	responsible_ref:      #Text
	read_refs:            #NonEmptyStrings
	write_refs:           #NonEmptyStrings
	permission_refs:      #NonEmptyStrings
	resource_refs:        #NonEmptyStrings
	maximum_side_effects: #NonEmptyStrings
	pre_checks:           #NonEmptyStrings
	post_checks:          #NonEmptyStrings
	idempotency:          #Text
	retry_limit:          uint
	recovery:             #Text
})
#ParallelInput: close({
	operation_indices: #AtLeastTwoUInts
	reason:            #Text
	guards:            #NonEmptyStrings
})
#Parallel: close({
	operation_ids: [#OperationID, #OperationID, ...#OperationID] & list.UniqueItems()
	reason: #Text
	guards: #NonEmptyStrings
})
#AcceptanceCoverage: close({
	point_id:      #PointID
	operation_ids: #Strings
})
#ControlCoverage: close({
	control_id:    #ControlID
	operation_ids: #Strings
})
#Coverage: close({
	acceptance: [...#AcceptanceCoverage]
	controls: [...#ControlCoverage]
})
#Input: close({
	difference: #Text
	route:      #Route
	operations: [...#OperationInput]
	parallel_groups: [...#ParallelInput]
	blockers: #Strings
	unknowns: #Strings
})
#Document: close({
	difference: #Text
	route:      #Route
	operations: [...#Operation]
	coverage: #Coverage
	parallel_groups: [...#Parallel]
	blockers: #Strings
	unknowns: #Strings
	status:   "executable" | "not-executable" | "unknown"
})
#Envelope: close({
	schema:            "k4-plan-document/v3"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: close({goal: #Binding})
	document: #Document
})

_input: #Input & context.input
_goal:  #BoundGoal & context.bindings.goal
_pointIDs: [for point in _goal.value.document.acceptance_points {point.point_id}]
_controlIDs: [for control in _goal.value.document.control_contracts {control.control_id}]
_availableTools: _goal.value.document.execution_envelope.available_tools

_operationIDs: [for operation in _input.operations {
	_core: close({
		satisfies:            operation.satisfies
		controlled_by:        operation.controlled_by
		tool_ref:             operation.tool_ref
		responsible_ref:      operation.responsible_ref
		read_refs:            operation.read_refs
		write_refs:           operation.write_refs
		permission_refs:      operation.permission_refs
		resource_refs:        operation.resource_refs
		maximum_side_effects: operation.maximum_side_effects
		pre_checks:           operation.pre_checks
		post_checks:          operation.post_checks
		idempotency:          operation.idempotency
		retry_limit:          operation.retry_limit
		recovery:             operation.recovery
	})
	"op-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(_core))), 0, 16))"
}]
_operationIDsUnique: list.UniqueItems(_operationIDs) & true

for index, operation in _input.operations {
	if !list.Contains(_availableTools, operation.tool_ref) {_invalid: _|_}
	for dependency in operation.depends_on_indices {
		if dependency >= index {_invalid: _|_}
	}
	for point in operation.satisfies {
		if !list.Contains(_pointIDs, point) {_invalid: _|_}
	}
	for control in operation.controlled_by {
		if !list.Contains(_controlIDs, control) {_invalid: _|_}
	}
}

_operations: [for index, operation in _input.operations {
	close({
		operation_id: _operationIDs[index]
		depends_on: [for dependency in operation.depends_on_indices {_operationIDs[dependency]}]
		satisfies:            operation.satisfies
		controlled_by:        operation.controlled_by
		tool_ref:             operation.tool_ref
		responsible_ref:      operation.responsible_ref
		read_refs:            operation.read_refs
		write_refs:           operation.write_refs
		permission_refs:      operation.permission_refs
		resource_refs:        operation.resource_refs
		maximum_side_effects: operation.maximum_side_effects
		pre_checks:           operation.pre_checks
		post_checks:          operation.post_checks
		idempotency:          operation.idempotency
		retry_limit:          operation.retry_limit
		recovery:             operation.recovery
	})
}]

_inputAncestors: [for index, operation in _input.operations {
	list.Concat([
		[for dependency in operation.depends_on_indices {dependency}],
		[for dependency in operation.depends_on_indices {
			for ancestor in _inputAncestors[dependency] {ancestor}
		}],
	])
}]
for group in _input.parallel_groups {
	for leftPosition, left in group.operation_indices {
		if left >= len(_input.operations) {_invalid: _|_}
		for rightPosition, right in group.operation_indices {
			if right >= len(_input.operations) {_invalid: _|_}
			if leftPosition < rightPosition &&
				(list.Contains(_inputAncestors[left], right) ||
				list.Contains(_inputAncestors[right], left)) {
				_invalid: _|_
			}
		}
	}
}
_parallel: [for group in _input.parallel_groups {
	close({
		operation_ids: [for index in group.operation_indices {_operationIDs[index]}]
		reason: group.reason
		guards: group.guards
	})
}]
_acceptanceCoverage: [for point in _pointIDs {
	close({
		point_id: point
		operation_ids: [for operation in _operations if list.Contains(operation.satisfies, point) {operation.operation_id}]
	})
}]
_controlCoverage: [for control in _controlIDs {
	close({
		control_id: control
		operation_ids: [for operation in _operations if list.Contains(operation.controlled_by, control) {operation.operation_id}]
	})
}]

_status: *"executable" | "not-executable" | "unknown"
if len(_input.blockers) > 0 {_status: "not-executable"}
if len(_input.blockers) == 0 && len(_input.unknowns) > 0 {_status: "unknown"}
if _status == "executable" && len(_operations) == 0 {_invalid: _|_}
if _status == "executable" {
	for entry in _acceptanceCoverage {
		if len(entry.operation_ids) == 0 {_invalid: _|_}
	}
	for entry in _controlCoverage {
		if len(entry.operation_ids) == 0 {_invalid: _|_}
	}
}

_generateChecks: {
	for index, operation in _input.operations {
		if !list.Contains(_availableTools, operation.tool_ref) {_invalid: _|_}
		for dependency in operation.depends_on_indices {
			if dependency >= index {_invalid: _|_}
		}
		for point in operation.satisfies {
			if !list.Contains(_pointIDs, point) {_invalid: _|_}
		}
		for control in operation.controlled_by {
			if !list.Contains(_controlIDs, control) {_invalid: _|_}
		}
	}
	for group in _input.parallel_groups {
		for leftPosition, left in group.operation_indices {
			if left >= len(_input.operations) {_invalid: _|_}
			for rightPosition, right in group.operation_indices {
				if right >= len(_input.operations) {_invalid: _|_}
				if leftPosition < rightPosition &&
					(list.Contains(_inputAncestors[left], right) ||
					list.Contains(_inputAncestors[right], left)) {
					_invalid: _|_
				}
			}
		}
	}
	if _status == "executable" && len(_operations) == 0 {_invalid: _|_}
	if _status == "executable" {
		for entry in _acceptanceCoverage {
			if len(entry.operation_ids) == 0 {_invalid: _|_}
		}
		for entry in _controlCoverage {
			if len(entry.operation_ids) == 0 {_invalid: _|_}
		}
	}
}

_document: #Document & {
	difference: _input.difference
	route:      _input.route
	operations: _operations
	coverage: close({
		acceptance: _acceptanceCoverage
		controls:   _controlCoverage
	})
	parallel_groups: _parallel
	blockers:        _input.blockers
	unknowns:        _input.unknowns
	status:          _status
}
generate: _generateChecks & close({
	schema: "k4-plan-document/v3"
	bindings: close({goal: _goal.binding})
	document: _document
})

_existing: #Envelope & context.existing & {
	bindings: close({goal: _goal.binding})
}
_existingIDs: [for operation in _existing.document.operations {operation.operation_id}]
_existingIDsUnique: list.UniqueItems(_existingIDs) & true
_existingIndex: {for index, operation in _existing.document.operations {(operation.operation_id): index}}
_expectedExistingOperationIDs: [for operation in _existing.document.operations {
	"op-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(close({
		satisfies:            operation.satisfies
		controlled_by:        operation.controlled_by
		tool_ref:             operation.tool_ref
		responsible_ref:      operation.responsible_ref
		read_refs:            operation.read_refs
		write_refs:           operation.write_refs
		permission_refs:      operation.permission_refs
		resource_refs:        operation.resource_refs
		maximum_side_effects: operation.maximum_side_effects
		pre_checks:           operation.pre_checks
		post_checks:          operation.post_checks
		idempotency:          operation.idempotency
		retry_limit:          operation.retry_limit
		recovery:             operation.recovery
	})))), 0, 16))"
}]
for index, operation in _existing.document.operations {
	if operation.operation_id != _expectedExistingOperationIDs[index] {_invalid: _|_}
	if !list.Contains(_availableTools, operation.tool_ref) {_invalid: _|_}
	for dependency in operation.depends_on {
		if _existingIndex[dependency] >= index {_invalid: _|_}
	}
	for point in operation.satisfies {
		if !list.Contains(_pointIDs, point) {_invalid: _|_}
	}
	for control in operation.controlled_by {
		if !list.Contains(_controlIDs, control) {_invalid: _|_}
	}
}
_expectedAcceptanceCoverage: [for point in _pointIDs {
	close({
		point_id: point
		operation_ids: [for operation in _existing.document.operations if list.Contains(operation.satisfies, point) {operation.operation_id}]
	})
}]
_expectedControlCoverage: [for control in _controlIDs {
	close({
		control_id: control
		operation_ids: [for operation in _existing.document.operations if list.Contains(operation.controlled_by, control) {operation.operation_id}]
	})
}]
if _existing.document.coverage.acceptance != _expectedAcceptanceCoverage {_invalid: _|_}
if _existing.document.coverage.controls != _expectedControlCoverage {_invalid: _|_}
_existingAncestors: [for index, operation in _existing.document.operations {
	list.Concat([
		[for dependency in operation.depends_on {_existingIndex[dependency]}],
		[for dependency in operation.depends_on {
			for ancestor in _existingAncestors[_existingIndex[dependency]] {ancestor}
		}],
	])
}]
for group in _existing.document.parallel_groups {
	for leftPosition, leftID in group.operation_ids {
		_left: _existingIndex[leftID]
		for rightPosition, rightID in group.operation_ids {
			_right: _existingIndex[rightID]
			if leftPosition < rightPosition &&
				(list.Contains(_existingAncestors[_left], _right) ||
				list.Contains(_existingAncestors[_right], _left)) {
				_invalid: _|_
			}
		}
	}
}
if len(_existing.document.blockers) > 0 && _existing.document.status != "not-executable" {_invalid: _|_}
if len(_existing.document.blockers) == 0 && len(_existing.document.unknowns) > 0 && _existing.document.status != "unknown" {_invalid: _|_}
if len(_existing.document.blockers) == 0 && len(_existing.document.unknowns) == 0 && _existing.document.status != "executable" {_invalid: _|_}
if _existing.document.status == "executable" {
	if len(_existing.document.operations) == 0 {_invalid: _|_}
	for entry in _existing.document.coverage.acceptance {
		if len(entry.operation_ids) == 0 {_invalid: _|_}
	}
	for entry in _existing.document.coverage.controls {
		if len(entry.operation_ids) == 0 {_invalid: _|_}
	}
}
_validateChecks: {
	for index, operation in _existing.document.operations {
		if operation.operation_id != _expectedExistingOperationIDs[index] {_invalid: _|_}
		if !list.Contains(_availableTools, operation.tool_ref) {_invalid: _|_}
		for dependency in operation.depends_on {
			if _existingIndex[dependency] >= index {_invalid: _|_}
		}
		for point in operation.satisfies {
			if !list.Contains(_pointIDs, point) {_invalid: _|_}
		}
		for control in operation.controlled_by {
			if !list.Contains(_controlIDs, control) {_invalid: _|_}
		}
	}
	if _existing.document.coverage.acceptance != _expectedAcceptanceCoverage {_invalid: _|_}
	if _existing.document.coverage.controls != _expectedControlCoverage {_invalid: _|_}
	for group in _existing.document.parallel_groups {
		for leftPosition, leftID in group.operation_ids {
			_left: _existingIndex[leftID]
			for rightPosition, rightID in group.operation_ids {
				_right: _existingIndex[rightID]
				if leftPosition < rightPosition &&
					(list.Contains(_existingAncestors[_left], _right) ||
					list.Contains(_existingAncestors[_right], _left)) {
					_invalid: _|_
				}
			}
		}
	}
	if len(_existing.document.blockers) > 0 && _existing.document.status != "not-executable" {_invalid: _|_}
	if len(_existing.document.blockers) == 0 && len(_existing.document.unknowns) > 0 && _existing.document.status != "unknown" {_invalid: _|_}
	if len(_existing.document.blockers) == 0 && len(_existing.document.unknowns) == 0 && _existing.document.status != "executable" {_invalid: _|_}
	if _existing.document.status == "executable" {
		if len(_existing.document.operations) == 0 {_invalid: _|_}
		for entry in _existing.document.coverage.acceptance {
			if len(entry.operation_ids) == 0 {_invalid: _|_}
		}
		for entry in _existing.document.coverage.controls {
			if len(entry.operation_ids) == 0 {_invalid: _|_}
		}
	}
}
validate: _validateChecks & _existing
