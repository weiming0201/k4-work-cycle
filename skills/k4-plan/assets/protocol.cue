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
#Binding: close({
	ref:            #Text
	sha256:         #Digest
	content_sha256: #Digest
})
#GoalEnvelope: close({
	schema:            "k4-goal-document/v5"
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
#OutcomeRouteInput: close({
	next_operation_indices: #UInts
	reason:                 #Text
})
#OutcomeRoutesInput: close({
	pass: #OutcomeRouteInput
	fail: #OutcomeRouteInput
})
#OutcomeRoute: close({
	next_operation_ids: [...#OperationID]
	reason: #Text
})
#OutcomeRoutes: close({
	pass: #OutcomeRoute
	fail: #OutcomeRoute
})
#OperationInput: close({
	operation_key:        #Text
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
	on_result:            #OutcomeRoutesInput
})
#Operation: close({
	operation_id:         #OperationID
	operation_key:        #Text
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
	on_result:            #OutcomeRoutes
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
	difference:          #Text
	selection_rationale: #Text
	route:               #Route
	entry_operation_indices: [uint, ...uint] & list.UniqueItems()
	operations: [#OperationInput, ...#OperationInput]
	blockers: #Strings
	unknowns: #Strings
})
#Document: close({
	difference:          #Text
	selection_rationale: #Text
	route:               #Route
	entry_operation_ids: [#OperationID, ...#OperationID] & list.UniqueItems()
	operations: [#Operation, ...#Operation]
	coverage: #Coverage
	topology: close({
		forks: [...close({after_operation_id: null | #OperationID, result: null | "pass" | "fail", next_operation_ids: [#OperationID, #OperationID, ...#OperationID] & list.UniqueItems()})]
		joins: [...close({before_operation_id: #OperationID, predecessor_operation_ids: [#OperationID, #OperationID, ...#OperationID] & list.UniqueItems()})]
		ends: [...close({after_operation_id: #OperationID, result: "pass" | "fail"})]
	})
	blockers: #Strings
	unknowns: #Strings
	status:   "executable" | "not-executable"
})
#Envelope: close({
	schema:            "k4-plan-document/v5"
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
		operation_key:        operation.operation_key
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

for entry in _input.entry_operation_indices {
	if entry >= len(_input.operations) {_invalid: _|_}
}
_entryOperationIDs: [for entry in _input.entry_operation_indices {_operationIDs[entry]}]

for index, operation in _input.operations {
	if !list.Contains(_availableTools, operation.tool_ref) {_invalid: _|_}
	for dependency in operation.depends_on_indices {
		if dependency >= index {_invalid: _|_}
	}
	for target in list.Concat([operation.on_result.pass.next_operation_indices, operation.on_result.fail.next_operation_indices]) {
		if target <= index || target >= len(_input.operations) {_invalid: _|_}
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
		operation_id:  _operationIDs[index]
		operation_key: operation.operation_key
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
		on_result: close({
			pass: close({
				next_operation_ids: [for target in operation.on_result.pass.next_operation_indices {_operationIDs[target]}]
				reason: operation.on_result.pass.reason
			})
			fail: close({
				next_operation_ids: [for target in operation.on_result.fail.next_operation_indices {_operationIDs[target]}]
				reason: operation.on_result.fail.reason
			})
		})
	})
}]

_incomingIndices: [for currentIndex, current in _input.operations {
	[for priorIndex, prior in _input.operations if priorIndex < currentIndex if list.Contains(list.Concat([prior.on_result.pass.next_operation_indices, prior.on_result.fail.next_operation_indices]), currentIndex) {priorIndex}]
}]
for index, operation in _input.operations {
	if list.Contains(_input.entry_operation_indices, index) && len(_incomingIndices[index]) > 0 {_invalid: _|_}
	if !list.Contains(_input.entry_operation_indices, index) && len(_incomingIndices[index]) == 0 {_invalid: _|_}
	if len(operation.depends_on_indices) > 0 {
		if operation.depends_on_indices != _incomingIndices[index] {_invalid: _|_}
		for dependency in operation.depends_on_indices {
			if !list.Contains(_input.operations[dependency].on_result.pass.next_operation_indices, index) {_invalid: _|_}
			if !list.Contains(_input.operations[dependency].on_result.fail.next_operation_indices, index) {_invalid: _|_}
		}
	}
}
_startForks: *[] | [...]
if len(_entryOperationIDs) > 1 {
	_startForks: [close({after_operation_id: null, result: null, next_operation_ids: _entryOperationIDs})]
}
_passForks: [for index, operation in _input.operations if len(operation.on_result.pass.next_operation_indices) > 1 {
	close({after_operation_id: _operationIDs[index], result: "pass", next_operation_ids: _operations[index].on_result.pass.next_operation_ids})
}]
_failForks: [for index, operation in _input.operations if len(operation.on_result.fail.next_operation_indices) > 1 {
	close({after_operation_id: _operationIDs[index], result: "fail", next_operation_ids: _operations[index].on_result.fail.next_operation_ids})
}]
_operationForks: list.Concat([_passForks, _failForks])
_forks: list.Concat([_startForks, _operationForks])
_joins: [for index, operation in _input.operations if len(operation.depends_on_indices) > 1 {close({
	before_operation_id: _operationIDs[index]
	predecessor_operation_ids: [for dependency in operation.depends_on_indices {_operationIDs[dependency]}]
})
}]
_passEnds: [for index, operation in _input.operations if len(operation.on_result.pass.next_operation_indices) == 0 {
	close({after_operation_id: _operationIDs[index], result: "pass"})
}]
_failEnds: [for index, operation in _input.operations if len(operation.on_result.fail.next_operation_indices) == 0 {
	close({after_operation_id: _operationIDs[index], result: "fail"})
}]
_ends: list.Concat([_passEnds, _failEnds])
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

_status: *"executable" | "not-executable"
if len(_input.blockers) > 0 {_status: "not-executable"}
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
		for target in list.Concat([operation.on_result.pass.next_operation_indices, operation.on_result.fail.next_operation_indices]) {
			if target <= index || target >= len(_input.operations) {_invalid: _|_}
		}
		if list.Contains(_input.entry_operation_indices, index) && len(_incomingIndices[index]) > 0 {_invalid: _|_}
		if !list.Contains(_input.entry_operation_indices, index) && len(_incomingIndices[index]) == 0 {_invalid: _|_}
		if len(operation.depends_on_indices) > 0 {
			if operation.depends_on_indices != _incomingIndices[index] {_invalid: _|_}
			for dependency in operation.depends_on_indices {
				if !list.Contains(_input.operations[dependency].on_result.pass.next_operation_indices, index) {_invalid: _|_}
				if !list.Contains(_input.operations[dependency].on_result.fail.next_operation_indices, index) {_invalid: _|_}
			}
		}
		for point in operation.satisfies {
			if !list.Contains(_pointIDs, point) {_invalid: _|_}
		}
		for control in operation.controlled_by {
			if !list.Contains(_controlIDs, control) {_invalid: _|_}
		}
	}
	for entry in _input.entry_operation_indices {
		if entry >= len(_input.operations) {_invalid: _|_}
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
	difference:          _input.difference
	selection_rationale: _input.selection_rationale
	route:               _input.route
	entry_operation_ids: _entryOperationIDs
	operations:          _operations
	coverage: close({
		acceptance: _acceptanceCoverage
		controls:   _controlCoverage
	})
	topology: close({
		forks: _forks
		joins: _joins
		ends:  _ends
	})
	blockers: _input.blockers
	unknowns: _input.unknowns
	status:   _status
}
generate: _generateChecks & close({
	schema: "k4-plan-document/v5"
	bindings: close({goal: _goal.binding})
	document: _document
})

_existing: #Envelope & context.existing & {
	bindings: close({goal: _goal.binding})
}
_existingIDs: [for operation in _existing.document.operations {operation.operation_id}]
_existingIDsUnique: list.UniqueItems(_existingIDs) & true
_existingIndex: {for index, operation in _existing.document.operations {(operation.operation_id): index}}
_existingEntryIDsUnique: list.UniqueItems(_existing.document.entry_operation_ids) & true
for entryID in _existing.document.entry_operation_ids {
	if !list.Contains(_existingIDs, entryID) {_invalid: _|_}
}
_expectedExistingOperationIDs: [for operation in _existing.document.operations {
	"op-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(close({
		operation_key:        operation.operation_key
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
	for target in list.Concat([operation.on_result.pass.next_operation_ids, operation.on_result.fail.next_operation_ids]) {
		if !list.Contains(_existingIDs, target) {_invalid: _|_}
		if _existingIndex[target] <= index {_invalid: _|_}
	}
	for point in operation.satisfies {
		if !list.Contains(_pointIDs, point) {_invalid: _|_}
	}
	for control in operation.controlled_by {
		if !list.Contains(_controlIDs, control) {_invalid: _|_}
	}
}
_existingIncomingIDs: [for currentIndex, current in _existing.document.operations {
	[for priorIndex, prior in _existing.document.operations if priorIndex < currentIndex if list.Contains(list.Concat([prior.on_result.pass.next_operation_ids, prior.on_result.fail.next_operation_ids]), current.operation_id) {prior.operation_id}]
}]
for index, operation in _existing.document.operations {
	if list.Contains(_existing.document.entry_operation_ids, operation.operation_id) && len(_existingIncomingIDs[index]) > 0 {_invalid: _|_}
	if !list.Contains(_existing.document.entry_operation_ids, operation.operation_id) && len(_existingIncomingIDs[index]) == 0 {_invalid: _|_}
	if len(operation.depends_on) > 0 {
		if operation.depends_on != _existingIncomingIDs[index] {_invalid: _|_}
		for dependency in operation.depends_on {
			if !list.Contains(_existing.document.operations[_existingIndex[dependency]].on_result.pass.next_operation_ids, operation.operation_id) {_invalid: _|_}
			if !list.Contains(_existing.document.operations[_existingIndex[dependency]].on_result.fail.next_operation_ids, operation.operation_id) {_invalid: _|_}
		}
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
_existingStartForks: *[] | [...]
if len(_existing.document.entry_operation_ids) > 1 {
	_existingStartForks: [close({after_operation_id: null, result: null, next_operation_ids: _existing.document.entry_operation_ids})]
}
_existingPassForks: [for operation in _existing.document.operations if len(operation.on_result.pass.next_operation_ids) > 1 {
	close({after_operation_id: operation.operation_id, result: "pass", next_operation_ids: operation.on_result.pass.next_operation_ids})
}]
_existingFailForks: [for operation in _existing.document.operations if len(operation.on_result.fail.next_operation_ids) > 1 {
	close({after_operation_id: operation.operation_id, result: "fail", next_operation_ids: operation.on_result.fail.next_operation_ids})
}]
_existingOperationForks: list.Concat([_existingPassForks, _existingFailForks])
_expectedForks: list.Concat([_existingStartForks, _existingOperationForks])
_expectedJoins: [for operation in _existing.document.operations if len(operation.depends_on) > 1 {close({
	before_operation_id:       operation.operation_id
	predecessor_operation_ids: operation.depends_on
})
}]
_existingPassEnds: [for operation in _existing.document.operations if len(operation.on_result.pass.next_operation_ids) == 0 {
	close({after_operation_id: operation.operation_id, result: "pass"})
}]
_existingFailEnds: [for operation in _existing.document.operations if len(operation.on_result.fail.next_operation_ids) == 0 {
	close({after_operation_id: operation.operation_id, result: "fail"})
}]
_expectedEnds: list.Concat([_existingPassEnds, _existingFailEnds])
if _existing.document.topology.forks != _expectedForks {_invalid: _|_}
if _existing.document.topology.joins != _expectedJoins {_invalid: _|_}
if _existing.document.topology.ends != _expectedEnds {_invalid: _|_}
if len(_existing.document.blockers) > 0 && _existing.document.status != "not-executable" {_invalid: _|_}
if len(_existing.document.blockers) == 0 && _existing.document.status != "executable" {_invalid: _|_}
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
	_entryIDsUnique: list.UniqueItems(_existing.document.entry_operation_ids) & true
	for entryID in _existing.document.entry_operation_ids {
		if !list.Contains(_existingIDs, entryID) {_invalid: _|_}
	}
	for index, operation in _existing.document.operations {
		if operation.operation_id != _expectedExistingOperationIDs[index] {_invalid: _|_}
		if !list.Contains(_availableTools, operation.tool_ref) {_invalid: _|_}
		for dependency in operation.depends_on {
			if _existingIndex[dependency] >= index {_invalid: _|_}
		}
		for target in list.Concat([operation.on_result.pass.next_operation_ids, operation.on_result.fail.next_operation_ids]) {
			if !list.Contains(_existingIDs, target) {_invalid: _|_}
			if _existingIndex[target] <= index {_invalid: _|_}
		}
		if list.Contains(_existing.document.entry_operation_ids, operation.operation_id) && len(_existingIncomingIDs[index]) > 0 {_invalid: _|_}
		if !list.Contains(_existing.document.entry_operation_ids, operation.operation_id) && len(_existingIncomingIDs[index]) == 0 {_invalid: _|_}
		if len(operation.depends_on) > 0 {
			if operation.depends_on != _existingIncomingIDs[index] {_invalid: _|_}
			for dependency in operation.depends_on {
				if !list.Contains(_existing.document.operations[_existingIndex[dependency]].on_result.pass.next_operation_ids, operation.operation_id) {_invalid: _|_}
				if !list.Contains(_existing.document.operations[_existingIndex[dependency]].on_result.fail.next_operation_ids, operation.operation_id) {_invalid: _|_}
			}
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
	if _existing.document.topology.forks != _expectedForks {_invalid: _|_}
	if _existing.document.topology.joins != _expectedJoins {_invalid: _|_}
	if _existing.document.topology.ends != _expectedEnds {_invalid: _|_}
	if len(_existing.document.blockers) > 0 && _existing.document.status != "not-executable" {_invalid: _|_}
	if len(_existing.document.blockers) == 0 && _existing.document.status != "executable" {_invalid: _|_}
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
