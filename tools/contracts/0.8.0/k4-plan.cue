package k4_plan

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"list"
	"strings"
)

context: _

#Text:           string & !=""
#Digest:         string & =~"^[0-9a-f]{64}$"
#PointID:        string & =~"^point-[0-9a-f]{16}$"
#ControlID:      string & =~"^control-[0-9a-f]{16}$"
#OperationID:    string & =~"^op-[0-9a-f]{16}$"
#OperationPhase: "normal" | "abort"
#Strings: [...#Text] & list.UniqueItems()
#NonEmptyStrings: [#Text, ...#Text] & list.UniqueItems()
#UInts: [...uint] & list.UniqueItems()
#Binding: close({
	ref:            #Text
	sha256:         #Digest
	content_sha256: #Digest
})
#GoalEnvelope: close({
	schema:            "k4-goal-document/v6"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {...}
	document: close({
		status: "frozen"
		execution_envelope: close({
			available_tools:      #NonEmptyStrings
			permission_refs:      #NonEmptyStrings
			read_refs:            #NonEmptyStrings
			write_refs:           #NonEmptyStrings
			resources:            #NonEmptyStrings
			maximum_side_effects: #NonEmptyStrings
			...
		})
		acceptance_points: [{point_id: #PointID, judge: {kind: #Text, ref: #Text, ...}, ...}, ...{point_id: #PointID, judge: {kind: #Text, ref: #Text, ...}, ...}]
		control_contracts: [...{control_id: #ControlID, judge: {kind: #Text, ref: #Text, ...}, ...}]
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
	phase:                #OperationPhase
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
	phase:                #OperationPhase
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
#AbortResponseInput: close({
	mode:                  "preserve-only" | "route"
	entry_operation_index: null | uint
	reason:                #Text
})
#AbortResponse: close({
	mode:               "preserve-only" | "route"
	entry_operation_id: null | #OperationID
	reason:             #Text
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
	on_abort: #AbortResponseInput
	operations: [#OperationInput, ...#OperationInput]
	blockers: #Strings
	unknowns: #Strings
})
#Document: close({
	difference:          #Text
	selection_rationale: #Text
	route:               #Route
	entry_operation_ids: [#OperationID, ...#OperationID] & list.UniqueItems()
	on_abort: #AbortResponse
	operations: [#Operation, ...#Operation]
	coverage: #Coverage
	topology: close({
		forks: [...close({phase: #OperationPhase, after_operation_id: null | #OperationID, result: null | "pass" | "fail", next_operation_ids: [#OperationID, #OperationID, ...#OperationID] & list.UniqueItems()})]
		joins: [...close({phase: #OperationPhase, before_operation_id: #OperationID, predecessor_operation_ids: [#OperationID, #OperationID, ...#OperationID] & list.UniqueItems()})]
		ends: [...close({phase: #OperationPhase, after_operation_id: #OperationID, result: "pass" | "fail"})]
	})
	blockers: #Strings
	unknowns: #Strings
	status:   "executable" | "not-executable"
})
#Envelope: close({
	schema:            "k4-plan-document/v7"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: close({goal: #Binding})
	document: #Document
})

_input: #Input & context.input
_goal:  #BoundGoal & context.bindings.goal
_pointIDs: [for point in _goal.value.document.acceptance_points {point.point_id}]
_controlIDs: [for control in _goal.value.document.control_contracts {control.control_id}]
_availableTools:       _goal.value.document.execution_envelope.available_tools
_availablePermissions: _goal.value.document.execution_envelope.permission_refs
_availableReads:       _goal.value.document.execution_envelope.read_refs
_availableWrites:      _goal.value.document.execution_envelope.write_refs
_availableResources:   _goal.value.document.execution_envelope.resources
_availableEffects:     _goal.value.document.execution_envelope.maximum_side_effects
_pointJudges: {for point in _goal.value.document.acceptance_points {(point.point_id): point.judge}}
_controlJudges: {for control in _goal.value.document.control_contracts {(control.control_id): control.judge}}

_operationIDs: [for operation in _input.operations {
	_core: close({
		phase:                operation.phase
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

_abortOperationIndices: [for index, operation in _input.operations if operation.phase == "abort" {index}]
_abortEntryOperationID: null | #OperationID
if _input.on_abort.entry_operation_index == null {_abortEntryOperationID: null}
if _input.on_abort.entry_operation_index != null {
	if _input.on_abort.entry_operation_index >= len(_input.operations) {_invalid: error("on_abort.entry_operation_index: index must identify an operation")}
	if _input.on_abort.entry_operation_index < len(_input.operations) {_abortEntryOperationID: _operationIDs[_input.on_abort.entry_operation_index]}
}
if _input.on_abort.mode == "preserve-only" {
	if _input.on_abort.entry_operation_index != null {_invalid: error("on_abort.entry_operation_index: preserve-only requires null")}
	if len(_abortOperationIndices) != 0 {_invalid: error("operations.phase: preserve-only cannot contain abort operations")}
}
if _input.on_abort.mode == "route" {
	if _input.on_abort.entry_operation_index == null {_invalid: error("on_abort.entry_operation_index: route requires one abort entry")}
	if _input.on_abort.entry_operation_index != null {
		if _input.on_abort.entry_operation_index < len(_input.operations) && _input.operations[_input.on_abort.entry_operation_index].phase != "abort" {_invalid: error("on_abort.entry_operation_index: route entry must identify an abort operation")}
	}
}

for entry in _input.entry_operation_indices {
	if entry >= len(_input.operations) {_invalid: error("contract relation rejected: entry >= len(_input.operations)")}
	if entry < len(_input.operations) && _input.operations[entry].phase != "normal" {_invalid: error("entry_operation_indices: normal entry must identify a normal operation")}
}
_entryOperationIDs: [for entry in _input.entry_operation_indices {_operationIDs[entry]}]
_allEntryIndices: list.Concat([_input.entry_operation_indices, [for index in _abortOperationIndices if _input.on_abort.entry_operation_index == index {index}]])

for index, operation in _input.operations {
	if !list.Contains(_availableTools, operation.tool_ref) {_invalid: error("operations.tool_ref: tool must be allowed by the Goal execution envelope")}
	for ref in operation.permission_refs {if !list.Contains(_availablePermissions, ref) {_invalid: error("operations.permission_refs: every permission must be allowed by the Goal execution envelope")}}
	for ref in operation.read_refs {if !list.Contains(_availableReads, ref) {_invalid: error("operations.read_refs: every read position must be allowed by the Goal execution envelope")}}
	for ref in operation.write_refs {if !list.Contains(_availableWrites, ref) {_invalid: error("operations.write_refs: every write position must be allowed by the Goal execution envelope")}}
	for ref in operation.resource_refs {if !list.Contains(_availableResources, ref) {_invalid: error("operations.resource_refs: every resource must be allowed by the Goal execution envelope")}}
	for effect in operation.maximum_side_effects {if !list.Contains(_availableEffects, effect) {_invalid: error("operations.maximum_side_effects: every effect must be allowed by the Goal execution envelope")}}
	for dependency in operation.depends_on_indices {
		if dependency >= index {_invalid: error("contract relation rejected: dependency >= index")}
	}
	for target in list.Concat([operation.on_result.pass.next_operation_indices, operation.on_result.fail.next_operation_indices]) {
		if target <= index || target >= len(_input.operations) {_invalid: error("contract relation rejected: target <= index || target >= len(_input.operations)")}
		if target < len(_input.operations) && _input.operations[target].phase != operation.phase {_invalid: error("operations.on_result: result edges cannot cross normal and abort phases")}
	}
	if operation.phase == "abort" && len(operation.satisfies) != 0 {_invalid: error("operations.satisfies: abort response operations cannot claim Goal acceptance")}
	for point in operation.satisfies {
		if !list.Contains(_pointIDs, point) {_invalid: error("operations.satisfies: every point must identify a Goal acceptance point")}
		if list.Contains(_pointIDs, point) && _pointJudges[point].kind == "independent-agent" && operation.responsible_ref == _pointJudges[point].ref {_invalid: error("operations.responsible_ref: an independent acceptance judge cannot execute the operation it judges")}
	}
	for control in operation.controlled_by {
		if !list.Contains(_controlIDs, control) {_invalid: error("operations.controlled_by: every control must identify a Goal control contract")}
		if list.Contains(_controlIDs, control) && _controlJudges[control].kind == "independent-agent" && operation.responsible_ref == _controlJudges[control].ref {_invalid: error("operations.responsible_ref: an independent control judge cannot execute the operation it judges")}
	}
}

_operations: [for index, operation in _input.operations {
	close({
		operation_id:  _operationIDs[index]
		phase:         operation.phase
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
	if list.Contains(_allEntryIndices, index) && len(_incomingIndices[index]) > 0 {_invalid: error("operations: an entry operation cannot have an incoming result edge")}
	if !list.Contains(_allEntryIndices, index) && len(_incomingIndices[index]) == 0 {_invalid: error("operations: every non-entry operation requires an incoming result edge")}
	if len(_incomingIndices[index]) > 1 && operation.depends_on_indices != _incomingIndices[index] {_invalid: error("contract relation rejected: len(_incomingIndices[index]) > 1 && operation.depends_on_indices != _incomingIndices[index]")}
	if len(operation.depends_on_indices) > 0 {
		if operation.depends_on_indices != _incomingIndices[index] {_invalid: error("contract relation rejected: operation.depends_on_indices != _incomingIndices[index]")}
		for dependency in operation.depends_on_indices {
			if !list.Contains(_input.operations[dependency].on_result.pass.next_operation_indices, index) {_invalid: error("contract relation rejected: !list.Contains(_input.operations[dependency].on_result.pass.next_operation_indices, index)")}
			if !list.Contains(_input.operations[dependency].on_result.fail.next_operation_indices, index) {_invalid: error("contract relation rejected: !list.Contains(_input.operations[dependency].on_result.fail.next_operation_indices, index)")}
		}
	}
}
_startForks: *[] | [...]
if len(_entryOperationIDs) > 1 {
	_startForks: [close({phase: "normal", after_operation_id: null, result: null, next_operation_ids: _entryOperationIDs})]
}
_passForks: [for index, operation in _input.operations if len(operation.on_result.pass.next_operation_indices) > 1 {
	close({phase: operation.phase, after_operation_id: _operationIDs[index], result: "pass", next_operation_ids: _operations[index].on_result.pass.next_operation_ids})
}]
_failForks: [for index, operation in _input.operations if len(operation.on_result.fail.next_operation_indices) > 1 {
	close({phase: operation.phase, after_operation_id: _operationIDs[index], result: "fail", next_operation_ids: _operations[index].on_result.fail.next_operation_ids})
}]
_operationForks: list.Concat([_passForks, _failForks])
_forks: list.Concat([_startForks, _operationForks])
_joins: [for index, operation in _input.operations if len(_incomingIndices[index]) > 1 {close({
	phase:               operation.phase
	before_operation_id: _operationIDs[index]
	predecessor_operation_ids: [for dependency in _incomingIndices[index] {_operationIDs[dependency]}]
})
}]
_passEnds: [for index, operation in _input.operations if len(operation.on_result.pass.next_operation_indices) == 0 {
	close({phase: operation.phase, after_operation_id: _operationIDs[index], result: "pass"})
}]
_failEnds: [for index, operation in _input.operations if len(operation.on_result.fail.next_operation_indices) == 0 {
	close({phase: operation.phase, after_operation_id: _operationIDs[index], result: "fail"})
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
if _status == "executable" && len(_operations) == 0 {_invalid: error("contract relation rejected: _status == \"executable\" && len(_operations) == 0")}
if _status == "executable" {
	for entry in _acceptanceCoverage {
		if len(entry.operation_ids) == 0 {_invalid: error("contract relation rejected: len(entry.operation_ids) == 0")}
	}
	for entry in _controlCoverage {
		if len(entry.operation_ids) == 0 {_invalid: error("contract relation rejected: len(entry.operation_ids) == 0")}
	}
}

_generateChecks: {
	if _input.on_abort.mode == "preserve-only" {
		if _input.on_abort.entry_operation_index != null {_invalid: error("on_abort.entry_operation_index: preserve-only requires null")}
		if len(_abortOperationIndices) != 0 {_invalid: error("operations.phase: preserve-only cannot contain abort operations")}
	}
	if _input.on_abort.mode == "route" {
		if _input.on_abort.entry_operation_index == null {_invalid: error("on_abort.entry_operation_index: route requires one abort entry")}
		if _input.on_abort.entry_operation_index != null {
			if _input.on_abort.entry_operation_index < len(_input.operations) && _input.operations[_input.on_abort.entry_operation_index].phase != "abort" {_invalid: error("on_abort.entry_operation_index: route entry must identify an abort operation")}
		}
	}
	for index, operation in _input.operations {
		if !list.Contains(_availableTools, operation.tool_ref) {_invalid: error("operations.tool_ref: tool must be allowed by the Goal execution envelope")}
		for ref in operation.permission_refs {if !list.Contains(_availablePermissions, ref) {_invalid: error("operations.permission_refs: every permission must be allowed by the Goal execution envelope")}}
		for ref in operation.read_refs {if !list.Contains(_availableReads, ref) {_invalid: error("operations.read_refs: every read position must be allowed by the Goal execution envelope")}}
		for ref in operation.write_refs {if !list.Contains(_availableWrites, ref) {_invalid: error("operations.write_refs: every write position must be allowed by the Goal execution envelope")}}
		for ref in operation.resource_refs {if !list.Contains(_availableResources, ref) {_invalid: error("operations.resource_refs: every resource must be allowed by the Goal execution envelope")}}
		for effect in operation.maximum_side_effects {if !list.Contains(_availableEffects, effect) {_invalid: error("operations.maximum_side_effects: every effect must be allowed by the Goal execution envelope")}}
		for dependency in operation.depends_on_indices {
			if dependency >= index {_invalid: error("contract relation rejected: dependency >= index")}
		}
		for target in list.Concat([operation.on_result.pass.next_operation_indices, operation.on_result.fail.next_operation_indices]) {
			if target <= index || target >= len(_input.operations) {_invalid: error("contract relation rejected: target <= index || target >= len(_input.operations)")}
			if target < len(_input.operations) && _input.operations[target].phase != operation.phase {_invalid: error("operations.on_result: result edges cannot cross normal and abort phases")}
		}
		if operation.phase == "abort" && len(operation.satisfies) != 0 {_invalid: error("operations.satisfies: abort response operations cannot claim Goal acceptance")}
		if list.Contains(_allEntryIndices, index) && len(_incomingIndices[index]) > 0 {_invalid: error("operations: an entry operation cannot have an incoming result edge")}
		if !list.Contains(_allEntryIndices, index) && len(_incomingIndices[index]) == 0 {_invalid: error("operations: every non-entry operation requires an incoming result edge")}
		if len(_incomingIndices[index]) > 1 && operation.depends_on_indices != _incomingIndices[index] {_invalid: error("contract relation rejected: len(_incomingIndices[index]) > 1 && operation.depends_on_indices != _incomingIndices[index]")}
		if len(operation.depends_on_indices) > 0 {
			if operation.depends_on_indices != _incomingIndices[index] {_invalid: error("contract relation rejected: operation.depends_on_indices != _incomingIndices[index]")}
			for dependency in operation.depends_on_indices {
				if !list.Contains(_input.operations[dependency].on_result.pass.next_operation_indices, index) {_invalid: error("contract relation rejected: !list.Contains(_input.operations[dependency].on_result.pass.next_operation_indices, index)")}
				if !list.Contains(_input.operations[dependency].on_result.fail.next_operation_indices, index) {_invalid: error("contract relation rejected: !list.Contains(_input.operations[dependency].on_result.fail.next_operation_indices, index)")}
			}
		}
		for point in operation.satisfies {
			if !list.Contains(_pointIDs, point) {_invalid: error("operations.satisfies: every point must identify a Goal acceptance point")}
			if list.Contains(_pointIDs, point) && _pointJudges[point].kind == "independent-agent" && operation.responsible_ref == _pointJudges[point].ref {_invalid: error("operations.responsible_ref: an independent acceptance judge cannot execute the operation it judges")}
		}
		for control in operation.controlled_by {
			if !list.Contains(_controlIDs, control) {_invalid: error("operations.controlled_by: every control must identify a Goal control contract")}
			if list.Contains(_controlIDs, control) && _controlJudges[control].kind == "independent-agent" && operation.responsible_ref == _controlJudges[control].ref {_invalid: error("operations.responsible_ref: an independent control judge cannot execute the operation it judges")}
		}
	}
	for entry in _input.entry_operation_indices {
		if entry >= len(_input.operations) {_invalid: error("contract relation rejected: entry >= len(_input.operations)")}
		if entry < len(_input.operations) && _input.operations[entry].phase != "normal" {_invalid: error("entry_operation_indices: normal entry must identify a normal operation")}
	}
	if _input.on_abort.entry_operation_index != null {
		if _input.on_abort.entry_operation_index >= len(_input.operations) {_invalid: error("on_abort.entry_operation_index: index must identify an operation")}
	}
	if _status == "executable" && len(_operations) == 0 {_invalid: error("contract relation rejected: _status == \"executable\" && len(_operations) == 0")}
	if _status == "executable" {
		for entry in _acceptanceCoverage {
			if len(entry.operation_ids) == 0 {_invalid: error("contract relation rejected: len(entry.operation_ids) == 0")}
		}
		for entry in _controlCoverage {
			if len(entry.operation_ids) == 0 {_invalid: error("contract relation rejected: len(entry.operation_ids) == 0")}
		}
	}
}

_document: #Document & {
	difference:          _input.difference
	selection_rationale: _input.selection_rationale
	route:               _input.route
	entry_operation_ids: _entryOperationIDs
	on_abort: close({
		mode:               _input.on_abort.mode
		entry_operation_id: _abortEntryOperationID
		reason:             _input.on_abort.reason
	})
	operations: _operations
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
	schema: "k4-plan-document/v7"
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
_existingAbortOperationIDs: [for operation in _existing.document.operations if operation.phase == "abort" {operation.operation_id}]
_existingAbortEntryIDs: *[] | [...]
if _existing.document.on_abort.entry_operation_id != null {
	_existingAbortEntryIDs: [_existing.document.on_abort.entry_operation_id]
}
_existingAllEntryIDs: list.Concat([_existing.document.entry_operation_ids, _existingAbortEntryIDs])
for entryID in _existing.document.entry_operation_ids {
	if !list.Contains(_existingIDs, entryID) {_invalid: error("contract relation rejected: !list.Contains(_existingIDs, entryID)")}
	if list.Contains(_existingIDs, entryID) && _existing.document.operations[_existingIndex[entryID]].phase != "normal" {_invalid: error("entry_operation_ids: normal entry must identify a normal operation")}
}
if _existing.document.on_abort.mode == "preserve-only" {
	if _existing.document.on_abort.entry_operation_id != null {_invalid: error("on_abort.entry_operation_id: preserve-only requires null")}
	if len(_existingAbortOperationIDs) != 0 {_invalid: error("operations.phase: preserve-only cannot contain abort operations")}
}
if _existing.document.on_abort.mode == "route" {
	if _existing.document.on_abort.entry_operation_id == null {_invalid: error("on_abort.entry_operation_id: route requires one abort entry")}
	if _existing.document.on_abort.entry_operation_id != null {
		if !list.Contains(_existingIDs, _existing.document.on_abort.entry_operation_id) {_invalid: error("on_abort.entry_operation_id: entry must identify an operation")}
		if list.Contains(_existingIDs, _existing.document.on_abort.entry_operation_id) && _existing.document.operations[_existingIndex[_existing.document.on_abort.entry_operation_id]].phase != "abort" {_invalid: error("on_abort.entry_operation_id: route entry must identify an abort operation")}
	}
}
_expectedExistingOperationIDs: [for operation in _existing.document.operations {
	"op-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(close({
		phase:                operation.phase
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
	if operation.operation_id != _expectedExistingOperationIDs[index] {_invalid: error("contract relation rejected: operation.operation_id != _expectedExistingOperationIDs[index]")}
	if !list.Contains(_availableTools, operation.tool_ref) {_invalid: error("contract relation rejected: !list.Contains(_availableTools, operation.tool_ref)")}
	for dependency in operation.depends_on {
		if _existingIndex[dependency] >= index {_invalid: error("contract relation rejected: _existingIndex[dependency] >= index")}
	}
	for target in list.Concat([operation.on_result.pass.next_operation_ids, operation.on_result.fail.next_operation_ids]) {
		if !list.Contains(_existingIDs, target) {_invalid: error("contract relation rejected: !list.Contains(_existingIDs, target)")}
		if _existingIndex[target] <= index {_invalid: error("contract relation rejected: _existingIndex[target] <= index")}
		if list.Contains(_existingIDs, target) && _existing.document.operations[_existingIndex[target]].phase != operation.phase {_invalid: error("operations.on_result: result edges cannot cross normal and abort phases")}
	}
	if operation.phase == "abort" && len(operation.satisfies) != 0 {_invalid: error("operations.satisfies: abort response operations cannot claim Goal acceptance")}
	for point in operation.satisfies {
		if !list.Contains(_pointIDs, point) {_invalid: error("contract relation rejected: !list.Contains(_pointIDs, point)")}
	}
	for control in operation.controlled_by {
		if !list.Contains(_controlIDs, control) {_invalid: error("contract relation rejected: !list.Contains(_controlIDs, control)")}
	}
}
_existingIncomingIDs: [for currentIndex, current in _existing.document.operations {
	[for priorIndex, prior in _existing.document.operations if priorIndex < currentIndex if list.Contains(list.Concat([prior.on_result.pass.next_operation_ids, prior.on_result.fail.next_operation_ids]), current.operation_id) {prior.operation_id}]
}]
for index, operation in _existing.document.operations {
	if list.Contains(_existingAllEntryIDs, operation.operation_id) && len(_existingIncomingIDs[index]) > 0 {_invalid: error("operations: an entry operation cannot have an incoming result edge")}
	if !list.Contains(_existingAllEntryIDs, operation.operation_id) && len(_existingIncomingIDs[index]) == 0 {_invalid: error("operations: every non-entry operation requires an incoming result edge")}
	if len(_existingIncomingIDs[index]) > 1 && operation.depends_on != _existingIncomingIDs[index] {_invalid: error("contract relation rejected: len(_existingIncomingIDs[index]) > 1 && operation.depends_on != _existingIncomingIDs[index]")}
	if len(operation.depends_on) > 0 {
		if operation.depends_on != _existingIncomingIDs[index] {_invalid: error("contract relation rejected: operation.depends_on != _existingIncomingIDs[index]")}
		for dependency in operation.depends_on {
			if !list.Contains(_existing.document.operations[_existingIndex[dependency]].on_result.pass.next_operation_ids, operation.operation_id) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.operations[_existingIndex[dependency]].on_result.pass.next_operation_ids, operation.operation_id)")}
			if !list.Contains(_existing.document.operations[_existingIndex[dependency]].on_result.fail.next_operation_ids, operation.operation_id) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.operations[_existingIndex[dependency]].on_result.fail.next_operation_ids, operation.operation_id)")}
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
if _existing.document.coverage.acceptance != _expectedAcceptanceCoverage {_invalid: error("contract relation rejected: _existing.document.coverage.acceptance != _expectedAcceptanceCoverage")}
if _existing.document.coverage.controls != _expectedControlCoverage {_invalid: error("contract relation rejected: _existing.document.coverage.controls != _expectedControlCoverage")}
_existingStartForks: *[] | [...]
if len(_existing.document.entry_operation_ids) > 1 {
	_existingStartForks: [close({phase: "normal", after_operation_id: null, result: null, next_operation_ids: _existing.document.entry_operation_ids})]
}
_existingPassForks: [for operation in _existing.document.operations if len(operation.on_result.pass.next_operation_ids) > 1 {
	close({phase: operation.phase, after_operation_id: operation.operation_id, result: "pass", next_operation_ids: operation.on_result.pass.next_operation_ids})
}]
_existingFailForks: [for operation in _existing.document.operations if len(operation.on_result.fail.next_operation_ids) > 1 {
	close({phase: operation.phase, after_operation_id: operation.operation_id, result: "fail", next_operation_ids: operation.on_result.fail.next_operation_ids})
}]
_existingOperationForks: list.Concat([_existingPassForks, _existingFailForks])
_expectedForks: list.Concat([_existingStartForks, _existingOperationForks])
_expectedJoins: [for index, operation in _existing.document.operations if len(_existingIncomingIDs[index]) > 1 {close({
	phase:                     operation.phase
	before_operation_id:       operation.operation_id
	predecessor_operation_ids: _existingIncomingIDs[index]
})
}]
_existingPassEnds: [for operation in _existing.document.operations if len(operation.on_result.pass.next_operation_ids) == 0 {
	close({phase: operation.phase, after_operation_id: operation.operation_id, result: "pass"})
}]
_existingFailEnds: [for operation in _existing.document.operations if len(operation.on_result.fail.next_operation_ids) == 0 {
	close({phase: operation.phase, after_operation_id: operation.operation_id, result: "fail"})
}]
_expectedEnds: list.Concat([_existingPassEnds, _existingFailEnds])
if _existing.document.topology.forks != _expectedForks {_invalid: error("contract relation rejected: _existing.document.topology.forks != _expectedForks")}
if _existing.document.topology.joins != _expectedJoins {_invalid: error("contract relation rejected: _existing.document.topology.joins != _expectedJoins")}
if _existing.document.topology.ends != _expectedEnds {_invalid: error("contract relation rejected: _existing.document.topology.ends != _expectedEnds")}
if len(_existing.document.blockers) > 0 && _existing.document.status != "not-executable" {_invalid: error("contract relation rejected: len(_existing.document.blockers) > 0 && _existing.document.status != \"not-executable\"")}
if len(_existing.document.blockers) == 0 && _existing.document.status != "executable" {_invalid: error("contract relation rejected: len(_existing.document.blockers) == 0 && _existing.document.status != \"executable\"")}
if _existing.document.status == "executable" {
	if len(_existing.document.operations) == 0 {_invalid: error("contract relation rejected: len(_existing.document.operations) == 0")}
	for entry in _existing.document.coverage.acceptance {
		if len(entry.operation_ids) == 0 {_invalid: error("contract relation rejected: len(entry.operation_ids) == 0")}
	}
	for entry in _existing.document.coverage.controls {
		if len(entry.operation_ids) == 0 {_invalid: error("contract relation rejected: len(entry.operation_ids) == 0")}
	}
}
_validateChecks: {
	_entryIDsUnique: list.UniqueItems(_existing.document.entry_operation_ids) & true
	for entryID in _existing.document.entry_operation_ids {
		if !list.Contains(_existingIDs, entryID) {_invalid: error("contract relation rejected: !list.Contains(_existingIDs, entryID)")}
		if list.Contains(_existingIDs, entryID) && _existing.document.operations[_existingIndex[entryID]].phase != "normal" {_invalid: error("entry_operation_ids: normal entry must identify a normal operation")}
	}
	if _existing.document.on_abort.mode == "preserve-only" {
		if _existing.document.on_abort.entry_operation_id != null {_invalid: error("on_abort.entry_operation_id: preserve-only requires null")}
		if len(_existingAbortOperationIDs) != 0 {_invalid: error("operations.phase: preserve-only cannot contain abort operations")}
	}
	if _existing.document.on_abort.mode == "route" {
		if _existing.document.on_abort.entry_operation_id == null {_invalid: error("on_abort.entry_operation_id: route requires one abort entry")}
		if _existing.document.on_abort.entry_operation_id != null {
			if !list.Contains(_existingIDs, _existing.document.on_abort.entry_operation_id) {_invalid: error("on_abort.entry_operation_id: entry must identify an operation")}
			if list.Contains(_existingIDs, _existing.document.on_abort.entry_operation_id) && _existing.document.operations[_existingIndex[_existing.document.on_abort.entry_operation_id]].phase != "abort" {_invalid: error("on_abort.entry_operation_id: route entry must identify an abort operation")}
		}
	}
	for index, operation in _existing.document.operations {
		if operation.operation_id != _expectedExistingOperationIDs[index] {_invalid: error("contract relation rejected: operation.operation_id != _expectedExistingOperationIDs[index]")}
		if !list.Contains(_availableTools, operation.tool_ref) {_invalid: error("operations.tool_ref: tool must be allowed by the Goal execution envelope")}
		for ref in operation.permission_refs {if !list.Contains(_availablePermissions, ref) {_invalid: error("operations.permission_refs: every permission must be allowed by the Goal execution envelope")}}
		for ref in operation.read_refs {if !list.Contains(_availableReads, ref) {_invalid: error("operations.read_refs: every read position must be allowed by the Goal execution envelope")}}
		for ref in operation.write_refs {if !list.Contains(_availableWrites, ref) {_invalid: error("operations.write_refs: every write position must be allowed by the Goal execution envelope")}}
		for ref in operation.resource_refs {if !list.Contains(_availableResources, ref) {_invalid: error("operations.resource_refs: every resource must be allowed by the Goal execution envelope")}}
		for effect in operation.maximum_side_effects {if !list.Contains(_availableEffects, effect) {_invalid: error("operations.maximum_side_effects: every effect must be allowed by the Goal execution envelope")}}
		for dependency in operation.depends_on {
			if _existingIndex[dependency] >= index {_invalid: error("contract relation rejected: _existingIndex[dependency] >= index")}
		}
		for target in list.Concat([operation.on_result.pass.next_operation_ids, operation.on_result.fail.next_operation_ids]) {
			if !list.Contains(_existingIDs, target) {_invalid: error("contract relation rejected: !list.Contains(_existingIDs, target)")}
			if _existingIndex[target] <= index {_invalid: error("contract relation rejected: _existingIndex[target] <= index")}
			if list.Contains(_existingIDs, target) && _existing.document.operations[_existingIndex[target]].phase != operation.phase {_invalid: error("operations.on_result: result edges cannot cross normal and abort phases")}
		}
		if operation.phase == "abort" && len(operation.satisfies) != 0 {_invalid: error("operations.satisfies: abort response operations cannot claim Goal acceptance")}
		if list.Contains(_existingAllEntryIDs, operation.operation_id) && len(_existingIncomingIDs[index]) > 0 {_invalid: error("operations: an entry operation cannot have an incoming result edge")}
		if !list.Contains(_existingAllEntryIDs, operation.operation_id) && len(_existingIncomingIDs[index]) == 0 {_invalid: error("operations: every non-entry operation requires an incoming result edge")}
		if len(_existingIncomingIDs[index]) > 1 && operation.depends_on != _existingIncomingIDs[index] {_invalid: error("contract relation rejected: len(_existingIncomingIDs[index]) > 1 && operation.depends_on != _existingIncomingIDs[index]")}
		if len(operation.depends_on) > 0 {
			if operation.depends_on != _existingIncomingIDs[index] {_invalid: error("contract relation rejected: operation.depends_on != _existingIncomingIDs[index]")}
			for dependency in operation.depends_on {
				if !list.Contains(_existing.document.operations[_existingIndex[dependency]].on_result.pass.next_operation_ids, operation.operation_id) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.operations[_existingIndex[dependency]].on_result.pass.next_operation_ids, operation.operation_id)")}
				if !list.Contains(_existing.document.operations[_existingIndex[dependency]].on_result.fail.next_operation_ids, operation.operation_id) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.operations[_existingIndex[dependency]].on_result.fail.next_operation_ids, operation.operation_id)")}
			}
		}
		for point in operation.satisfies {
			if !list.Contains(_pointIDs, point) {_invalid: error("operations.satisfies: every point must identify a Goal acceptance point")}
			if list.Contains(_pointIDs, point) && _pointJudges[point].kind == "independent-agent" && operation.responsible_ref == _pointJudges[point].ref {_invalid: error("operations.responsible_ref: an independent acceptance judge cannot execute the operation it judges")}
		}
		for control in operation.controlled_by {
			if !list.Contains(_controlIDs, control) {_invalid: error("operations.controlled_by: every control must identify a Goal control contract")}
			if list.Contains(_controlIDs, control) && _controlJudges[control].kind == "independent-agent" && operation.responsible_ref == _controlJudges[control].ref {_invalid: error("operations.responsible_ref: an independent control judge cannot execute the operation it judges")}
		}
	}
	if _existing.document.coverage.acceptance != _expectedAcceptanceCoverage {_invalid: error("contract relation rejected: _existing.document.coverage.acceptance != _expectedAcceptanceCoverage")}
	if _existing.document.coverage.controls != _expectedControlCoverage {_invalid: error("contract relation rejected: _existing.document.coverage.controls != _expectedControlCoverage")}
	if _existing.document.topology.forks != _expectedForks {_invalid: error("contract relation rejected: _existing.document.topology.forks != _expectedForks")}
	if _existing.document.topology.joins != _expectedJoins {_invalid: error("contract relation rejected: _existing.document.topology.joins != _expectedJoins")}
	if _existing.document.topology.ends != _expectedEnds {_invalid: error("contract relation rejected: _existing.document.topology.ends != _expectedEnds")}
	if len(_existing.document.blockers) > 0 && _existing.document.status != "not-executable" {_invalid: error("contract relation rejected: len(_existing.document.blockers) > 0 && _existing.document.status != \"not-executable\"")}
	if len(_existing.document.blockers) == 0 && _existing.document.status != "executable" {_invalid: error("contract relation rejected: len(_existing.document.blockers) == 0 && _existing.document.status != \"executable\"")}
	if _existing.document.status == "executable" {
		if len(_existing.document.operations) == 0 {_invalid: error("contract relation rejected: len(_existing.document.operations) == 0")}
		for entry in _existing.document.coverage.acceptance {
			if len(entry.operation_ids) == 0 {_invalid: error("contract relation rejected: len(entry.operation_ids) == 0")}
		}
		for entry in _existing.document.coverage.controls {
			if len(entry.operation_ids) == 0 {_invalid: error("contract relation rejected: len(entry.operation_ids) == 0")}
		}
	}
}
validate: _validateChecks & _existing
