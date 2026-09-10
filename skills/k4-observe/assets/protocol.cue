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
	lens:           #Text
	epistemic_kind: "fact" | "source-statement" | "inference" | "preference" | "unknown"
	state:          "aligned" | "gap" | "conflict" | "unknown"
	statement:      #Text
	evidence_refs:  #NonEmptyStrings
	route:          "none" | "goal-candidate" | "retain" | "external"
	route_ref:      null | #Text
})
#ItemInput: close({
	lens:             #ItemCore.lens
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
	lens:             #ItemCore.lens
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
	lenses:      #NonEmptyStrings
	lens_index: [...close({lens: #Text, item_ids: [#ItemID, ...#ItemID] & list.UniqueItems()})]
	delta: #Delta
	items: [#Item, ...#Item]
	retired: [...#Retired]
})
#Observation: close({
	mode: "bootstrap" | "iterate"
	goal_candidate_ids: [...#ItemID] & list.UniqueItems()
	status: "aligned" | "open"
})
#Document: close({
	account:     #Account
	observation: #Observation
})
#Envelope: close({
	schema:            "k4-observe-document/v2"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: close({previous_account: null | #Binding})
	document: #Document
})
#PreviousEnvelope: {
	schema:            "k4-observe-document/v2" | "k4-finish-document/v3"
	generated_unix_ms: uint
	content_sha256:    #Digest
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
	lenses:      #NonEmptyStrings
	delta:       #Delta
	items: [#ItemInput, ...#ItemInput]
	retired: [...#Retired]
})

_input:    #Input & context.input
_previous: #Previous & context.bindings.previous_account
_bindings: close({previous_account: null | #Binding})
if _previous.value == null {
	if _previous.binding != null {_invalid: error("contract relation rejected: _previous.binding != null")}
	_bindings: previous_account: null
}
if _previous.value != null {
	if _previous.binding == null {_invalid: error("contract relation rejected: _previous.binding == null")}
	_bindings: previous_account: _previous.binding
}

_generatedItems: [for item in _input.items {
	_core: close({
		lens:           item.lens
		epistemic_kind: item.epistemic_kind
		state:          item.state
		statement:      item.statement
		evidence_refs:  item.evidence_refs
		route:          item.route
		route_ref:      item.route_ref
	})
	close({
		item_id:          "item-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(_core))), 0, 16))"
		lens:             item.lens
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
		if !list.Contains(_input.lenses, item.lens) {_invalid: error("contract relation rejected: !list.Contains(_input.lenses, item.lens)")}
		if item.route == "external" && item.route_ref == null {_invalid: error("contract relation rejected: item.route == \"external\" && item.route_ref == null")}
		if item.route != "external" && item.route_ref != null {_invalid: error("contract relation rejected: item.route != \"external\" && item.route_ref != null")}
		for ref in item.evidence_refs {
			if !list.Contains(_input.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_input.source_refs, ref)")}
		}
		if item.change != "retained" {
			if len([for ref in item.evidence_refs if list.Contains(_input.delta.evidence_refs, ref) {ref}]) == 0 {_invalid: error("contract relation rejected: len([for ref in item.evidence_refs if list.Contains(_input.delta.evidence_refs, ref) {ref}]) == 0")}
		}
	}
	for lens in _input.lenses {
		if len([for item in _generatedItems if item.lens == lens {item}]) == 0 {_invalid: error("contract relation rejected: len([for item in _generatedItems if item.lens == lens {item}]) == 0")}
	}
	for retired in _input.retired {
		for ref in retired.evidence_refs {
			if !list.Contains(_input.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_input.source_refs, ref)")}
			if !list.Contains(_input.delta.evidence_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_input.delta.evidence_refs, ref)")}
		}
	}
	for ref in _input.source_refs {
		if !list.Contains(_allEvidence, ref) {_invalid: error("contract relation rejected: !list.Contains(_allEvidence, ref)")}
	}
	for ref in _input.delta.evidence_refs {
		if !list.Contains(_input.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_input.source_refs, ref)")}
		if !list.Contains(_changeEvidence, ref) {_invalid: error("contract relation rejected: !list.Contains(_changeEvidence, ref)")}
	}
	if _previous.value == null {
		if _input.mode != "bootstrap" {_invalid: error("contract relation rejected: _input.mode != \"bootstrap\"")}
		if len(_input.retired) != 0 {_invalid: error("contract relation rejected: len(_input.retired) != 0")}
		for item in _generatedItems {
			if item.change != "added" {_invalid: error("contract relation rejected: item.change != \"added\"")}
			if item.previous_item_id != null {_invalid: error("contract relation rejected: item.previous_item_id != null")}
		}
	}
	if _previous.value != null {
		if _input.mode != "iterate" {_invalid: error("contract relation rejected: _input.mode != \"iterate\"")}
		if _input.subject != _previous.value.document.account.subject {_invalid: error("semantic input subject must equal the previous Account subject for iterate; use bootstrap for a new subject")}
		if _input.boundary != _previous.value.document.account.boundary {_invalid: error("semantic input boundary must equal the previous Account boundary for iterate; use bootstrap for a new boundary")}
		_previousIDs: [for item in _previous.value.document.account.items {item.item_id}]
		_usedPrevious: list.Concat([
			[for item in _generatedItems if item.previous_item_id != null {item.previous_item_id}],
			[for item in _input.retired {item.previous_item_id}],
		])
		_usedPreviousUnique: list.UniqueItems(_usedPrevious) & true
		if len(_usedPrevious) != len(_previousIDs) {_invalid: error("contract relation rejected: len(_usedPrevious) != len(_previousIDs)")}
		for previousID in _previousIDs {
			if !list.Contains(_usedPrevious, previousID) {_invalid: error("contract relation rejected: !list.Contains(_usedPrevious, previousID)")}
		}
		for item in _generatedItems {
			if item.change == "added" && item.previous_item_id != null {_invalid: error("contract relation rejected: item.change == \"added\" && item.previous_item_id != null")}
			if item.change != "added" && item.previous_item_id == null {_invalid: error("contract relation rejected: item.change != \"added\" && item.previous_item_id == null")}
			if item.previous_item_id != null {
				if !list.Contains(_previousIDs, item.previous_item_id) {_invalid: error("contract relation rejected: !list.Contains(_previousIDs, item.previous_item_id)")}
				if item.change == "retained" && item.item_id != item.previous_item_id {_invalid: error("contract relation rejected: item.change == \"retained\" && item.item_id != item.previous_item_id")}
				if item.change == "changed" && item.item_id == item.previous_item_id {_invalid: error("contract relation rejected: item.change == \"changed\" && item.item_id == item.previous_item_id")}
			}
		}
		for retired in _input.retired {
			if !list.Contains(_previousIDs, retired.previous_item_id) {_invalid: error("contract relation rejected: !list.Contains(_previousIDs, retired.previous_item_id)")}
		}
	}
}

_goalCandidates: [for item in _generatedItems if item.route == "goal-candidate" {item.item_id}]
_lensIndex: [for lensName in _input.lenses {close({
	lens: lensName
	item_ids: [for item in _generatedItems if item.lens == lensName {item.item_id}]
})
}]
_openItems: [for item in _generatedItems if item.state != "aligned" {item.item_id}]
_status: *"aligned" | "open"
if len(_openItems) > 0 {_status: "open"}

_document: #Document & {
	account: {
		revision:    _revision
		subject:     _input.subject
		boundary:    _input.boundary
		cutoff:      _input.cutoff
		source_refs: _input.source_refs
		lenses:      _input.lenses
		lens_index:  _lensIndex
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
	schema:   "k4-observe-document/v2"
	bindings: _bindings
	document: _document
})

_existing: #Envelope & context.existing & {bindings: _bindings}
_existingIDs: [for item in _existing.document.account.items {item.item_id}]
_expectedExistingIDs: [for item in _existing.document.account.items {
	"item-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(close({
		lens:           item.lens
		epistemic_kind: item.epistemic_kind
		state:          item.state
		statement:      item.statement
		evidence_refs:  item.evidence_refs
		route:          item.route
		route_ref:      item.route_ref
	})))), 0, 16))"
}]
_expectedCandidates: [for item in _existing.document.account.items if item.route == "goal-candidate" {item.item_id}]
_expectedLensIndex: [for lensName in _existing.document.account.lenses {close({
	lens: lensName
	item_ids: [for item in _existing.document.account.items if item.lens == lensName {item.item_id}]
})
}]
_existingOpen: [for item in _existing.document.account.items if item.state != "aligned" {item.item_id}]
_existingEvidence: list.Concat(list.Concat([
	[for item in _existing.document.account.items {item.evidence_refs}],
	[for item in _existing.document.account.retired {item.evidence_refs}],
]))
_existingChangeEvidence: list.Concat(list.Concat([
	[for item in _existing.document.account.items if item.change != "retained" {item.evidence_refs}],
	[for item in _existing.document.account.retired {item.evidence_refs}],
]))

_validateChecks: {
	_idsUnique: list.UniqueItems(_existingIDs) & true
	for index, item in _existing.document.account.items {
		if item.item_id != _expectedExistingIDs[index] {_invalid: error("contract relation rejected: item.item_id != _expectedExistingIDs[index]")}
		if !list.Contains(_existing.document.account.lenses, item.lens) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.lenses, item.lens)")}
		if item.route == "external" && item.route_ref == null {_invalid: error("contract relation rejected: item.route == \"external\" && item.route_ref == null")}
		if item.route != "external" && item.route_ref != null {_invalid: error("contract relation rejected: item.route != \"external\" && item.route_ref != null")}
		for ref in item.evidence_refs {
			if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.source_refs, ref)")}
		}
		if item.change != "retained" {
			if len([for ref in item.evidence_refs if list.Contains(_existing.document.account.delta.evidence_refs, ref) {ref}]) == 0 {_invalid: error("contract relation rejected: len([for ref in item.evidence_refs if list.Contains(_existing.document.account.delta.evidence_refs, ref) {ref}]) == 0")}
		}
	}
	for lens in _existing.document.account.lenses {
		if len([for item in _existing.document.account.items if item.lens == lens {item}]) == 0 {_invalid: error("contract relation rejected: len([for item in _existing.document.account.items if item.lens == lens {item}]) == 0")}
	}
	for retired in _existing.document.account.retired {
		for ref in retired.evidence_refs {
			if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.source_refs, ref)")}
			if !list.Contains(_existing.document.account.delta.evidence_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.delta.evidence_refs, ref)")}
		}
	}
	for ref in _existing.document.account.source_refs {
		if !list.Contains(_existingEvidence, ref) {_invalid: error("contract relation rejected: !list.Contains(_existingEvidence, ref)")}
	}
	for ref in _existing.document.account.delta.evidence_refs {
		if !list.Contains(_existing.document.account.source_refs, ref) {_invalid: error("contract relation rejected: !list.Contains(_existing.document.account.source_refs, ref)")}
		if !list.Contains(_existingChangeEvidence, ref) {_invalid: error("contract relation rejected: !list.Contains(_existingChangeEvidence, ref)")}
	}
	if _existing.document.observation.goal_candidate_ids != _expectedCandidates {_invalid: error("contract relation rejected: _existing.document.observation.goal_candidate_ids != _expectedCandidates")}
	if _existing.document.account.lens_index != _expectedLensIndex {_invalid: error("contract relation rejected: _existing.document.account.lens_index != _expectedLensIndex")}
	if len(_existingOpen) > 0 && _existing.document.observation.status != "open" {_invalid: error("contract relation rejected: len(_existingOpen) > 0 && _existing.document.observation.status != \"open\"")}
	if len(_existingOpen) == 0 && _existing.document.observation.status != "aligned" {_invalid: error("contract relation rejected: len(_existingOpen) == 0 && _existing.document.observation.status != \"aligned\"")}
	if _previous.value == null {
		if _existing.document.account.revision != 0 {_invalid: error("contract relation rejected: _existing.document.account.revision != 0")}
		if _existing.document.observation.mode != "bootstrap" {_invalid: error("contract relation rejected: _existing.document.observation.mode != \"bootstrap\"")}
		if len(_existing.document.account.retired) != 0 {_invalid: error("contract relation rejected: len(_existing.document.account.retired) != 0")}
		for item in _existing.document.account.items {
			if item.change != "added" {_invalid: error("contract relation rejected: item.change != \"added\"")}
			if item.previous_item_id != null {_invalid: error("contract relation rejected: item.previous_item_id != null")}
		}
	}
	if _previous.value != null {
		if _existing.document.account.revision != _previous.value.document.account.revision+1 {_invalid: error("contract relation rejected: _existing.document.account.revision != _previous.value.document.account.revision+1")}
		if _existing.document.observation.mode != "iterate" {_invalid: error("contract relation rejected: _existing.document.observation.mode != \"iterate\"")}
		if _existing.document.account.subject != _previous.value.document.account.subject {_invalid: error("document subject must equal the previous Account subject for iterate")}
		if _existing.document.account.boundary != _previous.value.document.account.boundary {_invalid: error("document boundary must equal the previous Account boundary for iterate")}
		_previousIDs: [for item in _previous.value.document.account.items {item.item_id}]
		_usedPrevious: list.Concat([
			[for item in _existing.document.account.items if item.previous_item_id != null {item.previous_item_id}],
			[for item in _existing.document.account.retired {item.previous_item_id}],
		])
		_usedPreviousUnique: list.UniqueItems(_usedPrevious) & true
		if len(_usedPrevious) != len(_previousIDs) {_invalid: error("contract relation rejected: len(_usedPrevious) != len(_previousIDs)")}
		for previousID in _previousIDs {
			if !list.Contains(_usedPrevious, previousID) {_invalid: error("contract relation rejected: !list.Contains(_usedPrevious, previousID)")}
		}
		for item in _existing.document.account.items {
			if item.change == "added" && item.previous_item_id != null {_invalid: error("contract relation rejected: item.change == \"added\" && item.previous_item_id != null")}
			if item.change != "added" && item.previous_item_id == null {_invalid: error("contract relation rejected: item.change != \"added\" && item.previous_item_id == null")}
			if item.previous_item_id != null {
				if !list.Contains(_previousIDs, item.previous_item_id) {_invalid: error("contract relation rejected: !list.Contains(_previousIDs, item.previous_item_id)")}
				if item.change == "retained" && item.item_id != item.previous_item_id {_invalid: error("contract relation rejected: item.change == \"retained\" && item.item_id != item.previous_item_id")}
				if item.change == "changed" && item.item_id == item.previous_item_id {_invalid: error("contract relation rejected: item.change == \"changed\" && item.item_id == item.previous_item_id")}
			}
		}
		for retired in _existing.document.account.retired {
			if !list.Contains(_previousIDs, retired.previous_item_id) {_invalid: error("contract relation rejected: !list.Contains(_previousIDs, retired.previous_item_id)")}
		}
	}
}
validate: _validateChecks & _existing
