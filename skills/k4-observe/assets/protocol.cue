package k4_observe

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
#Observation: close({
	mode:               "bootstrap" | "iterate"
	goal_candidate_ids: [...#ItemID] & list.UniqueItems()
	status:             "aligned" | "open" | "unknown"
})
#Document: close({
	account:     #Account
	observation: #Observation
})
#Envelope: close({
	schema:            "k4-observe-document/v1"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: close({previous_account: null | #Binding})
	document: #Document
})
#PreviousEnvelope: {
	schema: "k4-observe-document/v1" | "k4-finish-document/v1"
	generated_unix_ms: uint
	content_sha256: #Digest
	bindings: {...}
	document: {
		account: #Account
		...
	}
}
#Previous: close({
	binding: null | #Binding
	value:   null | #PreviousEnvelope
})
#Input: close({
	mode:        "bootstrap" | "iterate"
	subject:     #Text
	boundary:    #Text
	cutoff:      #Text
	source_refs: #NonEmptyStrings
	delta:       #Delta
	items:       [#ItemInput, ...#ItemInput]
	retired:     [...#Retired]
})

_input:    #Input & context.input
_previous: #Previous & context.bindings.previous_account
_bindings: close({previous_account: null | #Binding})
if _previous.value == null {
	if _previous.binding != null {_invalid: _|_}
	_bindings: previous_account: null
}
if _previous.value != null {
	if _previous.binding == null {_invalid: _|_}
	_bindings: previous_account: _previous.binding
}

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
_allEvidence: list.Concat(list.Concat([
	[for item in _generatedItems {item.evidence_refs}],
	[for item in _input.retired {item.evidence_refs}],
]))
_changeEvidence: list.Concat(list.Concat([
	[for item in _generatedItems if item.change != "retained" {item.evidence_refs}],
	[for item in _input.retired {item.evidence_refs}],
]))
_revision: uint
if _previous.value == null {_revision: 0}
if _previous.value != null {_revision: _previous.value.document.account.revision + 1}

_generateChecks: {
	_itemIDsUnique: list.UniqueItems(_itemIDs) & true
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
	if _previous.value == null {
		if _input.mode != "bootstrap" {_invalid: _|_}
		if len(_input.retired) != 0 {_invalid: _|_}
		for item in _generatedItems {
			if item.change != "added" {_invalid: _|_}
			if item.previous_item_id != null {_invalid: _|_}
		}
	}
	if _previous.value != null {
		if _input.mode != "iterate" {_invalid: _|_}
		if _input.subject != _previous.value.document.account.subject {_invalid: error("semantic input subject must equal the previous Account subject for iterate; use bootstrap for a new subject")}
		if _input.boundary != _previous.value.document.account.boundary {_invalid: error("semantic input boundary must equal the previous Account boundary for iterate; use bootstrap for a new boundary")}
		_previousIDs: [for item in _previous.value.document.account.items {item.item_id}]
		_usedPrevious: list.Concat([
			[for item in _generatedItems if item.previous_item_id != null {item.previous_item_id}],
			[for item in _input.retired {item.previous_item_id}],
		])
		_usedPreviousUnique: list.UniqueItems(_usedPrevious) & true
		if len(_usedPrevious) != len(_previousIDs) {_invalid: _|_}
		for previousID in _previousIDs {
			if !list.Contains(_usedPrevious, previousID) {_invalid: _|_}
		}
		for item in _generatedItems {
			if item.change == "added" && item.previous_item_id != null {_invalid: _|_}
			if item.change != "added" && item.previous_item_id == null {_invalid: _|_}
			if item.previous_item_id != null {
				if !list.Contains(_previousIDs, item.previous_item_id) {_invalid: _|_}
				if item.change == "retained" && item.item_id != item.previous_item_id {_invalid: _|_}
				if item.change == "changed" && item.item_id == item.previous_item_id {_invalid: _|_}
			}
		}
		for retired in _input.retired {
			if !list.Contains(_previousIDs, retired.previous_item_id) {_invalid: _|_}
		}
	}
}

_goalCandidates: [for item in _generatedItems if item.route == "goal-candidate" {item.item_id}]
_unknownItems: [for item in _generatedItems if item.state == "unknown" {item.item_id}]
_openItems: [for item in _generatedItems if item.state == "gap" || item.state == "conflict" {item.item_id}]
_status: *"aligned" | "open" | "unknown"
if len(_unknownItems) > 0 {_status: "unknown"}
if len(_unknownItems) == 0 && len(_openItems) > 0 {_status: "open"}

_document: #Document & {
	account: {
		revision:    _revision
		subject:     _input.subject
		boundary:    _input.boundary
		cutoff:      _input.cutoff
		source_refs: _input.source_refs
		delta:       _input.delta
		items:       _generatedItems
		retired:     _input.retired
	}
	observation: {
		mode:               _input.mode
		goal_candidate_ids: _goalCandidates
		status:             _status
	}
}
generate: _generateChecks & close({
	schema:   "k4-observe-document/v1"
	bindings: _bindings
	document: _document
})

_existing: #Envelope & context.existing & {bindings: _bindings}
_existingIDs: [for item in _existing.document.account.items {item.item_id}]
_expectedExistingIDs: [for item in _existing.document.account.items {
	"item-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(close({
		epistemic_kind: item.epistemic_kind
		state:           item.state
		statement:       item.statement
		evidence_refs:   item.evidence_refs
		route:           item.route
		route_ref:       item.route_ref
	})))), 0, 16))"
}]
_expectedCandidates: [for item in _existing.document.account.items if item.route == "goal-candidate" {item.item_id}]
_existingUnknown: [for item in _existing.document.account.items if item.state == "unknown" {item.item_id}]
_existingOpen: [for item in _existing.document.account.items if item.state == "gap" || item.state == "conflict" {item.item_id}]
_existingEvidence: list.Concat(list.Concat([
	[for item in _existing.document.account.items {item.evidence_refs}],
	[for item in _existing.document.account.retired {item.evidence_refs}],
]))

_validateChecks: {
	_idsUnique: list.UniqueItems(_existingIDs) & true
	for index, item in _existing.document.account.items {
		if item.item_id != _expectedExistingIDs[index] {_invalid: _|_}
		if item.route == "external" && item.route_ref == null {_invalid: _|_}
		if item.route != "external" && item.route_ref != null {_invalid: _|_}
		for ref in item.evidence_refs {
			if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: _|_}
		}
	}
	for ref in _existing.document.account.source_refs {
		if !list.Contains(_existingEvidence, ref) {_invalid: _|_}
	}
	if _existing.document.observation.goal_candidate_ids != _expectedCandidates {_invalid: _|_}
	if len(_existingUnknown) > 0 && _existing.document.observation.status != "unknown" {_invalid: _|_}
	if len(_existingUnknown) == 0 && len(_existingOpen) > 0 && _existing.document.observation.status != "open" {_invalid: _|_}
	if len(_existingUnknown) == 0 && len(_existingOpen) == 0 && _existing.document.observation.status != "aligned" {_invalid: _|_}
	if _previous.value == null {
		if _existing.document.account.revision != 0 {_invalid: _|_}
		if _existing.document.observation.mode != "bootstrap" {_invalid: _|_}
	}
	if _previous.value != null {
		if _existing.document.account.revision != _previous.value.document.account.revision+1 {_invalid: _|_}
		if _existing.document.observation.mode != "iterate" {_invalid: _|_}
		if _existing.document.account.subject != _previous.value.document.account.subject {_invalid: error("document subject must equal the previous Account subject for iterate")}
		if _existing.document.account.boundary != _previous.value.document.account.boundary {_invalid: error("document boundary must equal the previous Account boundary for iterate")}
	}
}
validate: _validateChecks & _existing
