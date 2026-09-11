package k4_goal

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"list"
	"strings"
)

context: _

#Text:      string & !=""
#Digest:    string & =~"^[0-9a-f]{64}$"
#ItemID:    string & =~"^item-[0-9a-f]{16}$"
#PointID:   string & =~"^point-[0-9a-f]{16}$"
#ControlID: string & =~"^control-[0-9a-f]{16}$"
#Strings: [...#Text] & list.UniqueItems()
#NonEmptyStrings: [#Text, ...#Text] & list.UniqueItems()
#Binding: close({
	ref:            #Text
	sha256:         #Digest
	content_sha256: #Digest
})
#ObserveEnvelope: close({
	schema:            "k4-observe-document/v2"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: {...}
	document: close({
		account: {...}
		observation: close({
			goal_candidate_ids: [...#ItemID] & list.UniqueItems()
			...
		})
		...
	})
})
#BoundObserve: close({
	binding: #Binding
	value:   #ObserveEnvelope
})
#Judge: close({
	kind:        "self" | "independent-agent" | "script" | "human"
	ref:         #Text
	claim_limit: #Text
})
#Acceptance: close({
	observable:        #Text
	conditions:        #NonEmptyStrings
	window:            #Text
	expected:          #Text
	falsifier:         #Text
	comparison_method: #Text
	sampling_rule:     #Text
})
#PointInput: close({
	statement:         #Text
	required_evidence: #NonEmptyStrings
	judge:             #Judge
	acceptance:        #Acceptance
})
#Point: close({
	point_id:          #PointID
	statement:         #Text
	required_evidence: #NonEmptyStrings
	judge:             #Judge
	acceptance:        #Acceptance
})
#ControlInput: close({
	statement:           #Text
	required_evidence:   #NonEmptyStrings
	judge:               #Judge
	controlled_variable: #Text
	allowed_domain:      #NonEmptyStrings
	forbidden_drift:     #NonEmptyStrings
	required_trace:      #NonEmptyStrings
	check_method:        #Text
	check_timing:        "invariant" | "terminal"
})
#Control: close({
	control_id:          #ControlID
	statement:           #Text
	required_evidence:   #NonEmptyStrings
	judge:               #Judge
	controlled_variable: #Text
	allowed_domain:      #NonEmptyStrings
	forbidden_drift:     #NonEmptyStrings
	required_trace:      #NonEmptyStrings
	check_method:        #Text
	check_timing:        "invariant" | "terminal"
})
#ExecutionEnvelope: close({
	authorization_ref:         #Text
	authorization_scope:       #Text
	authorization_claim_limit: #Text
	available_tools:           #NonEmptyStrings
	permission_refs:           #NonEmptyStrings
	read_refs:                 #NonEmptyStrings
	write_refs:                #NonEmptyStrings
	resources:                 #NonEmptyStrings
	budget:                    #Text
	maximum_side_effects:      #NonEmptyStrings
})
#Cutoff: close({
	at:            #Text
	included_refs: #NonEmptyStrings
})
#Input: close({
	observe_item_ids: [#ItemID, ...#ItemID] & list.UniqueItems()
	objective:           #Text
	selection_rationale: #Text
	target:              #Text
	source_refs?:        #NonEmptyStrings
	evidence_cutoff:     #Cutoff
	baseline_refs:       #NonEmptyStrings
	scope:               #NonEmptyStrings
	non_goals:           *[] | #Strings
	execution_envelope:  #ExecutionEnvelope
	acceptance_points: [...#PointInput]
	control_contracts: *[] | [...#ControlInput]
	blockers:          *[] | #Strings
	unknowns:          *[] | #Strings
})
#Document: close({
	observe_item_ids: [#ItemID, ...#ItemID] & list.UniqueItems()
	objective:           #Text
	selection_rationale: #Text
	target:              #Text
	source_refs:         #NonEmptyStrings
	evidence_cutoff:     #Cutoff
	baseline_refs:       #NonEmptyStrings
	scope:               #NonEmptyStrings
	non_goals:           #Strings
	execution_envelope:  #ExecutionEnvelope
	acceptance_points: [...#Point]
	control_contracts: [...#Control]
	blockers: #Strings
	unknowns: #Strings
	status:   "frozen" | "not-frozen"
})
#Envelope: close({
	schema:            "k4-goal-document/v6"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: close({observe: #Binding})
	document: #Document
})

_rawInput:          context.input
_input:             #Input & _rawInput
_observe:           #BoundObserve & context.bindings.observe
_observeCandidates: _observe.value.document.observation.goal_candidate_ids
_selectedObserveItems: [for item in _observe.value.document.account.items if list.Contains(_input.observe_item_ids, item.item_id) {item}]
_selectedEvidence: list.Concat([for item in _selectedObserveItems {item.evidence_refs}])
_sourceJudges: list.Concat([
	[for point in _input.acceptance_points if point.judge.kind == "self" || point.judge.kind == "independent-agent" {point.judge.ref}],
	[for control in _input.control_contracts if control.judge.kind == "self" || control.judge.kind == "independent-agent" {control.judge.ref}],
])
_sourceRefsRaw: list.Concat([
	_selectedEvidence,
	_input.evidence_cutoff.included_refs,
	_input.baseline_refs,
	_sourceJudges,
])
_sourceRefs: [for index, ref in _sourceRefsRaw if len([for priorIndex, priorRef in _sourceRefsRaw if priorIndex < index && priorRef == ref {priorRef}]) == 0 {ref}]
for id in _input.observe_item_ids {
	if !list.Contains(_observeCandidates, id) {_invalid: error("observe_item_ids: every selected item must be a current Observe goal candidate")}
}
_generateChecks: {
	_pointIDsUnique:   list.UniqueItems(_pointIDs) & true
	_controlIDsUnique: list.UniqueItems(_controlIDs) & true
	if _rawInput.source_refs != _|_ {
		if _rawInput.source_refs != _sourceRefs {_invalid: error("source_refs: explicit compatibility value must equal the mechanically derived source closure")}
	}
	for id in _input.observe_item_ids {
		if !list.Contains(_observeCandidates, id) {_invalid: error("observe_item_ids: every selected item must be a current Observe goal candidate")}
	}
	if _status == "frozen" && len(_points) == 0 {_invalid: error("acceptance_points: a frozen Goal requires at least one acceptance point")}
	for judge in list.Concat([
		[for point in _input.acceptance_points {point.judge}],
		[for control in _input.control_contracts {control.judge}],
	]) {
		if judge.kind == "self" && !list.Contains(_sourceRefs, judge.ref) {_invalid: error("judge.ref: a self judge must be sourceable from Goal sources")}
		if judge.kind == "independent-agent" && !list.Contains(_sourceRefs, judge.ref) {_invalid: error("judge.ref: an independent-agent judge must be sourceable from Goal sources")}
		if judge.kind == "script" && !list.Contains(_input.execution_envelope.available_tools, judge.ref) {_invalid: error("judge.ref: a script judge must be one of execution_envelope.available_tools")}
		if judge.kind == "human" && judge.ref != _input.execution_envelope.authorization_ref {_invalid: error("judge.ref: a human judge must equal execution_envelope.authorization_ref")}
	}
}

_points: [for point in _input.acceptance_points {
	close({
		point_id:          "point-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(point))), 0, 16))"
		statement:         point.statement
		required_evidence: point.required_evidence
		judge:             point.judge
		acceptance:        point.acceptance
	})
}]
_pointIDs: [for point in _points {point.point_id}]

_controls: [for control in _input.control_contracts {
	close({
		control_id:          "control-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(control))), 0, 16))"
		statement:           control.statement
		required_evidence:   control.required_evidence
		judge:               control.judge
		controlled_variable: control.controlled_variable
		allowed_domain:      control.allowed_domain
		forbidden_drift:     control.forbidden_drift
		required_trace:      control.required_trace
		check_method:        control.check_method
		check_timing:        control.check_timing
	})
}]
_controlIDs: [for control in _controls {control.control_id}]

_status: *"frozen" | "not-frozen"
if len(_input.blockers) > 0 {_status: "not-frozen"}

_document: #Document & {
	observe_item_ids:    _input.observe_item_ids
	objective:           _input.objective
	selection_rationale: _input.selection_rationale
	target:              _input.target
	source_refs:         _sourceRefs
	evidence_cutoff:     _input.evidence_cutoff
	baseline_refs:       _input.baseline_refs
	scope:               _input.scope
	non_goals:           _input.non_goals
	execution_envelope:  _input.execution_envelope
	acceptance_points:   _points
	control_contracts:   _controls
	blockers:            _input.blockers
	unknowns:            _input.unknowns
	status:              _status
}

generate: _generateChecks & close({
	schema: "k4-goal-document/v6"
	bindings: close({observe: _observe.binding})
	document: _document
})

_existing: #Envelope & context.existing & {
	bindings: close({observe: _observe.binding})
}
for id in _existing.document.observe_item_ids {
	if !list.Contains(_observeCandidates, id) {_invalid: error("observe_item_ids: every selected item must be a current Observe goal candidate")}
}
_validateChecks: {
	_pointIDsUnique:   list.UniqueItems(_existingPointIDs) & true
	_controlIDsUnique: list.UniqueItems(_existingControlIDs) & true
	for id in _existing.document.observe_item_ids {
		if !list.Contains(_observeCandidates, id) {_invalid: error("observe_item_ids: every selected item must be a current Observe goal candidate")}
	}
	for index, point in _existing.document.acceptance_points {
		if point.point_id != _expectedExistingPointIDs[index] {_invalid: error("acceptance_points.point_id: identity must match the point semantic content")}
	}
	for index, control in _existing.document.control_contracts {
		if control.control_id != _expectedExistingControlIDs[index] {_invalid: error("control_contracts.control_id: identity must match the control semantic content")}
	}
	if len(_existing.document.blockers) > 0 && _existing.document.status != "not-frozen" {_invalid: error("status: blockers require not-frozen")}
	if len(_existing.document.blockers) == 0 && _existing.document.status != "frozen" {_invalid: error("status: an unblocked Goal must be frozen")}
	if _existing.document.status == "frozen" && len(_existing.document.acceptance_points) == 0 {_invalid: error("acceptance_points: a frozen Goal requires at least one acceptance point")}
	for judge in list.Concat([
		[for point in _existing.document.acceptance_points {point.judge}],
		[for control in _existing.document.control_contracts {control.judge}],
	]) {
		if judge.kind == "self" && !list.Contains(_existing.document.source_refs, judge.ref) {_invalid: error("judge.ref: a self judge must be sourceable from Goal source_refs")}
		if judge.kind == "independent-agent" && !list.Contains(_existing.document.source_refs, judge.ref) {_invalid: error("judge.ref: an independent-agent judge must be sourceable from Goal source_refs")}
		if judge.kind == "script" && !list.Contains(_existing.document.execution_envelope.available_tools, judge.ref) {_invalid: error("judge.ref: a script judge must be one of execution_envelope.available_tools")}
		if judge.kind == "human" && judge.ref != _existing.document.execution_envelope.authorization_ref {_invalid: error("judge.ref: a human judge must equal execution_envelope.authorization_ref")}
	}
}
_existingPointIDs: [for point in _existing.document.acceptance_points {point.point_id}]
_expectedExistingPointIDs: [for point in _existing.document.acceptance_points {
	"point-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(close({
		statement:         point.statement
		required_evidence: point.required_evidence
		judge:             point.judge
		acceptance:        point.acceptance
	})))), 0, 16))"
}]
_existingControlIDs: [for control in _existing.document.control_contracts {control.control_id}]
_expectedExistingControlIDs: [for control in _existing.document.control_contracts {
	"control-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(close({
		statement:           control.statement
		required_evidence:   control.required_evidence
		judge:               control.judge
		controlled_variable: control.controlled_variable
		allowed_domain:      control.allowed_domain
		forbidden_drift:     control.forbidden_drift
		required_trace:      control.required_trace
		check_method:        control.check_method
		check_timing:        control.check_timing
	})))), 0, 16))"
}]
validate: _validateChecks & _existing
