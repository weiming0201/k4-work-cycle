package k4_align

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
#Binding: close({
	ref:            #Text
	sha256:         #Digest
	content_sha256: #Digest
})
#ItemCore: close({
	state:         "aligned" | "gap" | "conflict" | "unknown"
	statement:     #Text
	evidence_refs: #NonEmptyStrings
	route:         "none" | "goal-candidate" | "retain" | "external"
	route_ref:     null | #Text
})
#ItemInput: close({
	change:           "retained" | "changed" | "added"
	previous_item_id: null | #ItemID
	change_reason:    #Text
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
#Document: close({
	revision:    uint
	mode:        "bootstrap" | "iterate"
	subject:     #Text
	boundary:    #Text
	cutoff:      #Text
	source_refs: #NonEmptyStrings
	delta:       #Delta
	items: [#Item, ...#Item]
	retired: [...#Retired]
	goal_candidate_ids: [...#ItemID] & list.UniqueItems()
	status: "aligned" | "open" | "unknown"
})
#Envelope: close({
	schema:            "k4-align-document/v2"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: close({previous_align: null | #Binding})
	document: #Document
})
#Previous: close({
	binding: null | #Binding
	value:   null | #Envelope
})
#Input: close({
	mode:        "bootstrap" | "iterate"
	subject:     #Text
	boundary:    #Text
	cutoff:      #Text
	source_refs: #NonEmptyStrings
	delta:       #Delta
	items: [#ItemInput, ...#ItemInput]
	retired: [...#Retired]
})

_input:    #Input & context.input
_previous: #Previous & context.bindings.previous_align
_bindings: close({previous_align: null | #Binding})
if _previous.value == null {
	if _previous.binding != null {
		_invalid: _|_
	}
	_bindings: previous_align: null
}
if _previous.value != null {
	if _previous.binding == null {
		_invalid: _|_
	}
	_bindings: previous_align: _previous.binding
}

_generatedItems: [for item in _input.items {
	_core: close({
		state:         item.state
		statement:     item.statement
		evidence_refs: item.evidence_refs
		route:         item.route
		route_ref:     item.route_ref
	})
	close({
		item_id:          "item-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(_core))), 0, 16))"
		change:           item.change
		previous_item_id: item.previous_item_id
		change_reason:    item.change_reason
		state:            item.state
		statement:        item.statement
		evidence_refs:    item.evidence_refs
		route:            item.route
		route_ref:        item.route_ref
	})
}]

_itemIDs: [for item in _generatedItems {item.item_id}]
_itemIDsUnique: list.UniqueItems(_itemIDs) & true
_allEvidence: list.Concat(
	[for item in _generatedItems {item.evidence_refs}] +
	[for item in _input.retired {item.evidence_refs}],
	)
_changeEvidence: list.Concat(
	[for item in _generatedItems if item.change != "retained" {item.evidence_refs}] +
	[for item in _input.retired {item.evidence_refs}],
	)
for item in _generatedItems {
	if item.route == "external" && item.route_ref == null {_invalid: _|_}
	if item.route != "external" && item.route_ref != null {_invalid: _|_}
	for ref in item.evidence_refs {
		if !list.Contains(_input.source_refs, ref) {_invalid: _|_}
	}
	if item.change != "retained" {
		if len([for ref in item.evidence_refs if list.Contains(_input.delta.evidence_refs, ref) {ref}]) == 0 {_invalid: _|_}
	}
}
for retired in _input.retired {
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

_revision: uint
if _previous.value == null {
	_revision: 0
	if _input.mode != "bootstrap" {_invalid: _|_}
	if len(_input.retired) != 0 {_invalid: _|_}
	for item in _generatedItems {
		if item.change != "added" {_invalid: _|_}
		if item.previous_item_id != null {_invalid: _|_}
	}
}
if _previous.value != null {
	_revision: _previous.value.document.revision + 1
	if _input.mode != "iterate" {_invalid: _|_}
	if _input.subject != _previous.value.document.subject {_invalid: _|_}
	if _input.boundary != _previous.value.document.boundary {_invalid: _|_}
	_previousIDs: [for item in _previous.value.document.items {item.item_id}]
	_usedPrevious: [for item in _generatedItems if item.previous_item_id != null {item.previous_item_id}] +
		[for item in _input.retired {item.previous_item_id}]
	_usedPreviousUnique: list.UniqueItems(_usedPrevious) & true
	if len(_usedPrevious) != len(_previousIDs) {_invalid: _|_}
	for previousID in _previousIDs {
		if !list.Contains(_usedPrevious, previousID) {_invalid: _|_}
	}
	for item in _generatedItems {
		if item.change == "added" && item.previous_item_id != null {_invalid: _|_}
		if item.change != "added" && item.previous_item_id == null {_invalid: _|_}
		if item.previous_item_id != null {
			if len([for previousItem in _previous.value.document.items if previousItem.item_id == item.previous_item_id {previousItem}]) != 1 {_invalid: _|_}
			if item.change == "retained" && item.item_id != item.previous_item_id {_invalid: _|_}
			if item.change == "changed" && item.item_id == item.previous_item_id {_invalid: _|_}
		}
	}
	for retired in _input.retired {
		if !list.Contains(_previousIDs, retired.previous_item_id) {_invalid: _|_}
	}
}

_goalCandidates: [for item in _generatedItems if item.route == "goal-candidate" {item.item_id}]
_unknownItems: [for item in _generatedItems if item.state == "unknown" {item.item_id}]
_openItems: [for item in _generatedItems if item.state == "gap" || item.state == "conflict" {item.item_id}]
_status: *"aligned" | "open" | "unknown"
if len(_unknownItems) > 0 {_status: "unknown"}
if len(_unknownItems) == 0 && len(_openItems) > 0 {_status: "open"}

_document: #Document & {
	revision:           _revision
	mode:               _input.mode
	subject:            _input.subject
	boundary:           _input.boundary
	cutoff:             _input.cutoff
	source_refs:        _input.source_refs
	delta:              _input.delta
	items:              _generatedItems
	retired:            _input.retired
	goal_candidate_ids: _goalCandidates
	status:             _status
}
generate: close({
	schema:   "k4-align-document/v2"
	bindings: _bindings
	document: _document
})

_existing: #Envelope & context.existing & {bindings: _bindings}
_existingIDs: [for item in _existing.document.items {item.item_id}]
_existingIDsUnique: list.UniqueItems(_existingIDs) & true
_expectedExistingIDs: [for item in _existing.document.items {
	"item-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(close({
		state:         item.state
		statement:     item.statement
		evidence_refs: item.evidence_refs
		route:         item.route
		route_ref:     item.route_ref
	})))), 0, 16))"
}]
_existingEvidence: list.Concat(
	[for item in _existing.document.items {item.evidence_refs}] +
	[for item in _existing.document.retired {item.evidence_refs}],
	)
_existingChangeEvidence: list.Concat(
	[for item in _existing.document.items if item.change != "retained" {item.evidence_refs}] +
	[for item in _existing.document.retired {item.evidence_refs}],
	)
for index, item in _existing.document.items {
	if item.item_id != _expectedExistingIDs[index] {_invalid: _|_}
	if item.route == "external" && item.route_ref == null {_invalid: _|_}
	if item.route != "external" && item.route_ref != null {_invalid: _|_}
	for ref in item.evidence_refs {
		if !list.Contains(_existing.document.source_refs, ref) {_invalid: _|_}
	}
	if item.change != "retained" {
		if len([for ref in item.evidence_refs if list.Contains(_existing.document.delta.evidence_refs, ref) {ref}]) == 0 {_invalid: _|_}
	}
}
for retired in _existing.document.retired {
	for ref in retired.evidence_refs {
		if !list.Contains(_existing.document.source_refs, ref) {_invalid: _|_}
		if !list.Contains(_existing.document.delta.evidence_refs, ref) {_invalid: _|_}
	}
}
for ref in _existing.document.source_refs {
	if !list.Contains(_existingEvidence, ref) {_invalid: _|_}
}
for ref in _existing.document.delta.evidence_refs {
	if !list.Contains(_existing.document.source_refs, ref) {_invalid: _|_}
	if !list.Contains(_existingChangeEvidence, ref) {_invalid: _|_}
}
_expectedCandidates: [for item in _existing.document.items if item.route == "goal-candidate" {item.item_id}]
if _existing.document.goal_candidate_ids != _expectedCandidates {_invalid: _|_}
_existingUnknown: [for item in _existing.document.items if item.state == "unknown" {item.item_id}]
_existingOpen: [for item in _existing.document.items if item.state == "gap" || item.state == "conflict" {item.item_id}]
if len(_existingUnknown) > 0 && _existing.document.status != "unknown" {_invalid: _|_}
if len(_existingUnknown) == 0 && len(_existingOpen) > 0 && _existing.document.status != "open" {_invalid: _|_}
if len(_existingUnknown) == 0 && len(_existingOpen) == 0 && _existing.document.status != "aligned" {_invalid: _|_}

if _previous.value == null {
	if _existing.document.revision != 0 {_invalid: _|_}
	if _existing.document.mode != "bootstrap" {_invalid: _|_}
	if len(_existing.document.retired) != 0 {_invalid: _|_}
	for item in _existing.document.items {
		if item.change != "added" {_invalid: _|_}
		if item.previous_item_id != null {_invalid: _|_}
	}
}
if _previous.value != null {
	if _existing.document.revision != _previous.value.document.revision+1 {_invalid: _|_}
	if _existing.document.mode != "iterate" {_invalid: _|_}
	if _existing.document.subject != _previous.value.document.subject {_invalid: _|_}
	if _existing.document.boundary != _previous.value.document.boundary {_invalid: _|_}
	_priorIDs: [for item in _previous.value.document.items {item.item_id}]
	_accounted: [for item in _existing.document.items if item.previous_item_id != null {item.previous_item_id}] +
		[for item in _existing.document.retired {item.previous_item_id}]
	_accountedUnique: list.UniqueItems(_accounted) & true
	if len(_accounted) != len(_priorIDs) {_invalid: _|_}
	for priorID in _priorIDs {
		if !list.Contains(_accounted, priorID) {_invalid: _|_}
	}
	for item in _existing.document.items {
		if item.change == "added" && item.previous_item_id != null {_invalid: _|_}
		if item.change != "added" && item.previous_item_id == null {_invalid: _|_}
		if item.previous_item_id != null {
			if !list.Contains(_priorIDs, item.previous_item_id) {_invalid: _|_}
			if item.change == "retained" && item.item_id != item.previous_item_id {_invalid: _|_}
			if item.change == "changed" && item.item_id == item.previous_item_id {_invalid: _|_}
		}
	}
}
validate: _existing
