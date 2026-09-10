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
	source_refs:         #NonEmptyStrings
	evidence_cutoff:     #Cutoff
	baseline_refs:       #NonEmptyStrings
	scope:               #NonEmptyStrings
	non_goals:           #Strings
	execution_envelope:  #ExecutionEnvelope
	acceptance_points: [...#PointInput]
	control_contracts: [...#ControlInput]
	blockers: #Strings
	unknowns: #Strings
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
	schema:            "k4-goal-document/v5"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: close({observe: #Binding})
	document: #Document
})

_input:             #Input & context.input
_observe:           #BoundObserve & context.bindings.observe
_observeCandidates: _observe.value.document.observation.goal_candidate_ids
for id in _input.observe_item_ids {
	if !list.Contains(_observeCandidates, id) {_invalid: _|_}
}
_generateChecks: {
	for id in _input.observe_item_ids {
		if !list.Contains(_observeCandidates, id) {_invalid: _|_}
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
_pointIDsUnique: list.UniqueItems(_pointIDs) & true

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
_controlIDsUnique: list.UniqueItems(_controlIDs) & true

_status: *"frozen" | "not-frozen"
if len(_input.blockers) > 0 {_status: "not-frozen"}
if _status == "frozen" && len(_points) == 0 {_invalid: _|_}

_document: #Document & {
	observe_item_ids:    _input.observe_item_ids
	objective:           _input.objective
	selection_rationale: _input.selection_rationale
	target:              _input.target
	source_refs:         _input.source_refs
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
	schema: "k4-goal-document/v5"
	bindings: close({observe: _observe.binding})
	document: _document
})

_existing: #Envelope & context.existing & {
	bindings: close({observe: _observe.binding})
}
for id in _existing.document.observe_item_ids {
	if !list.Contains(_observeCandidates, id) {_invalid: _|_}
}
_validateChecks: {
	for id in _existing.document.observe_item_ids {
		if !list.Contains(_observeCandidates, id) {_invalid: _|_}
	}
}
_existingPointIDs: [for point in _existing.document.acceptance_points {point.point_id}]
_existingPointIDsUnique: list.UniqueItems(_existingPointIDs) & true
_expectedExistingPointIDs: [for point in _existing.document.acceptance_points {
	"point-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(close({
		statement:         point.statement
		required_evidence: point.required_evidence
		judge:             point.judge
		acceptance:        point.acceptance
	})))), 0, 16))"
}]
for index, point in _existing.document.acceptance_points {
	if point.point_id != _expectedExistingPointIDs[index] {_invalid: _|_}
}
_existingControlIDs: [for control in _existing.document.control_contracts {control.control_id}]
_existingControlIDsUnique: list.UniqueItems(_existingControlIDs) & true
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
for index, control in _existing.document.control_contracts {
	if control.control_id != _expectedExistingControlIDs[index] {_invalid: _|_}
}
if len(_existing.document.blockers) > 0 && _existing.document.status != "not-frozen" {_invalid: _|_}
if len(_existing.document.blockers) == 0 && _existing.document.status != "frozen" {_invalid: _|_}
if _existing.document.status == "frozen" && len(_existing.document.acceptance_points) == 0 {_invalid: _|_}

validate: _validateChecks & _existing
