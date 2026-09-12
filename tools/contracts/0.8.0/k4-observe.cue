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
#SemanticItem: close({
	lens:           #ItemCore.lens
	epistemic_kind: #ItemCore.epistemic_kind
	state:          #ItemCore.state
	statement:      #ItemCore.statement
	evidence_refs:  #ItemCore.evidence_refs
	route:          #ItemCore.route
	route_ref:      *null | #Text
})
#Addition: close({
	reason: #Text
	item:   #SemanticItem
})
#Update: close({
	previous_item_id: #ItemID
	reason:           #Text
	item:             #SemanticItem
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
	schema:            "k4-observe-document/v2" | "k4-finish-document/v2" | "k4-finish-document/v3" | "k4-finish-document/v4"
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
#BootstrapInput: close({
	subject:  #Text
	boundary: #Text
	cutoff:   #Text
	delta:    #Delta
	additions: [#Addition, ...#Addition]
})
#IterationInput: close({
	cutoff: #Text
	delta:  #Delta
	updates: *[] | [...#Update]
	additions: *[] | [...#Addition]
	retirements: *[] | [...#Retired]
})

_rawInput: context.input
_previous: #Previous & context.bindings.previous_account
_bindings: close({previous_account: null | #Binding})
_mode:     "bootstrap" | "iterate"
_subject:  #Text
_boundary: #Text
_cutoff:   #Text
_delta:    #Delta
_updates: [...#Update]
_additions: [...#Addition]
_retirements: [...#Retired]
_previousItems: [...#Item]
_previousLenses: [...#Text]
if _previous.value == null {
	if _previous.binding != null {_invalid: error("contract relation rejected: _previous.binding != null")}
	_bindings: previous_account: null
	_input:    #BootstrapInput & _rawInput
	_mode:     "bootstrap"
	_subject:  _input.subject
	_boundary: _input.boundary
	_cutoff:   _input.cutoff
	_delta:    _input.delta
	_updates: []
	_additions: _input.additions
	_retirements: []
	_previousItems: []
	_previousLenses: []
}
if _previous.value != null {
	if _previous.binding == null {_invalid: error("contract relation rejected: _previous.binding == null")}
	_bindings: previous_account: _previous.binding
	_input:          #IterationInput & _rawInput
	_mode:           "iterate"
	_subject:        _previous.value.document.account.subject
	_boundary:       _previous.value.document.account.boundary
	_cutoff:         _input.cutoff
	_delta:          _input.delta
	_updates:        _input.updates
	_additions:      _input.additions
	_retirements:    _input.retirements
	_previousItems:  _previous.value.document.account.items
	_previousLenses: _previous.value.document.account.lenses
}

_updatedPreviousIDs: [for update in _updates {update.previous_item_id}]
_retiredPreviousIDs: [for retired in _retirements {retired.previous_item_id}]
_touchedPreviousIDs: list.Concat([_updatedPreviousIDs, _retiredPreviousIDs])

_continuedItems: [for previousItem in _previousItems if !list.Contains(_retiredPreviousIDs, previousItem.item_id) {
	_matchingUpdates: [for update in _updates if update.previous_item_id == previousItem.item_id {update}]
	if len(_matchingUpdates) == 0 {
		item_id:          previousItem.item_id
		lens:             previousItem.lens
		change:           "retained"
		previous_item_id: previousItem.item_id
		change_reason:    "Unmentioned by the semantic delta; prior item retained."
		epistemic_kind:   previousItem.epistemic_kind
		state:            previousItem.state
		statement:        previousItem.statement
		evidence_refs:    previousItem.evidence_refs
		route:            previousItem.route
		route_ref:        previousItem.route_ref
	}
	if len(_matchingUpdates) == 1 {
		_update: _matchingUpdates[0]
		_core: close({
			lens:           _update.item.lens
			epistemic_kind: _update.item.epistemic_kind
			state:          _update.item.state
			statement:      _update.item.statement
			evidence_refs:  _update.item.evidence_refs
			route:          _update.item.route
			route_ref:      _update.item.route_ref
		})
		item_id:          "item-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(_core))), 0, 16))"
		lens:             _update.item.lens
		change:           "changed"
		previous_item_id: previousItem.item_id
		change_reason:    _update.reason
		epistemic_kind:   _update.item.epistemic_kind
		state:            _update.item.state
		statement:        _update.item.statement
		evidence_refs:    _update.item.evidence_refs
		route:            _update.item.route
		route_ref:        _update.item.route_ref
	}
}]
_addedItems: [for addition in _additions {
	_core: close({
		lens:           addition.item.lens
		epistemic_kind: addition.item.epistemic_kind
		state:          addition.item.state
		statement:      addition.item.statement
		evidence_refs:  addition.item.evidence_refs
		route:          addition.item.route
		route_ref:      addition.item.route_ref
	})
	close({
		item_id:          "item-\(strings.SliceRunes(hex.Encode(sha256.Sum256(json.Marshal(_core))), 0, 16))"
		lens:             addition.item.lens
		change:           "added"
		previous_item_id: null
		change_reason:    addition.reason
		epistemic_kind:   addition.item.epistemic_kind
		state:            addition.item.state
		statement:        addition.item.statement
		evidence_refs:    addition.item.evidence_refs
		route:            addition.item.route
		route_ref:        addition.item.route_ref
	})
}]
_generatedItems: list.Concat([_continuedItems, _addedItems])
_itemIDs: [for item in _generatedItems {item.item_id}]
_allEvidenceRaw: list.Concat(list.Concat([
	[for item in _generatedItems {item.evidence_refs}],
	[for item in _retirements {item.evidence_refs}],
	[_delta.evidence_refs],
]))
_sourceRefs: [for index, ref in _allEvidenceRaw if len([for priorIndex, priorRef in _allEvidenceRaw if priorIndex < index && priorRef == ref {priorRef}]) == 0 {ref}]
_semanticChangeEvidence: list.Concat(list.Concat([
	[for item in _generatedItems if item.change != "retained" {item.evidence_refs}],
	[for item in _retirements {item.evidence_refs}],
]))
_lensNamesRaw: list.Concat([
	[for lensName in _previousLenses if len([for item in _generatedItems if item.lens == lensName {item}]) > 0 {lensName}],
	[for item in _generatedItems {item.lens}],
])
_lenses: [for index, lensName in _lensNamesRaw if len([for priorIndex, priorLens in _lensNamesRaw if priorIndex < index && priorLens == lensName {priorLens}]) == 0 {lensName}]
_revision: uint
if _previous.value == null {_revision: 0}
if _previous.value != null {_revision: _previous.value.document.account.revision + 1}

_generateChecks: {
	_itemIDsUnique:            list.UniqueItems(_itemIDs) & true
	_touchedPreviousIDsUnique: list.UniqueItems(_touchedPreviousIDs) & true
	if _previous.value != null && len(_updates)+len(_additions)+len(_retirements) == 0 {_invalid: error("semantic delta: at least one update, addition, or retirement is required")}
	for item in _generatedItems {
		if item.route == "external" && item.route_ref == null {_invalid: error("item.route_ref: required when route is external")}
		if item.route != "external" && item.route_ref != null {_invalid: error("item.route_ref: must be omitted unless route is external")}
		if item.change != "retained" && len([for ref in item.evidence_refs if list.Contains(_delta.evidence_refs, ref) {ref}]) == 0 {_invalid: error("delta.evidence_refs: every added or changed item must cite at least one delta evidence reference")}
		if item.change == "changed" && item.item_id == item.previous_item_id {_invalid: error("updates: new semantic item must differ from its predecessor")}
	}
	for retired in _retirements {
		for ref in retired.evidence_refs {
			if !list.Contains(_delta.evidence_refs, ref) {_invalid: error("retirements.evidence_refs: every retirement evidence reference must occur in delta.evidence_refs")}
		}
	}
	for ref in _delta.evidence_refs {
		if !list.Contains(_semanticChangeEvidence, ref) {_invalid: error("delta.evidence_refs: every reference must support an update, addition, or retirement")}
	}
	if _previous.value == null {
		if len(_additions) == 0 {_invalid: error("additions: bootstrap requires at least one observed item")}
	}
	if _previous.value != null {
		_previousIDs: [for item in _previous.value.document.account.items {item.item_id}]
		for touchedID in _touchedPreviousIDs {
			if !list.Contains(_previousIDs, touchedID) {_invalid: error("previous_item_id: does not identify a current predecessor item")}
		}
	}
}

_goalCandidates: [for item in _generatedItems if item.route == "goal-candidate" {item.item_id}]
_lensIndex: [for lensName in _lenses {close({
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
		subject:     _subject
		boundary:    _boundary
		cutoff:      _cutoff
		source_refs: _sourceRefs
		lenses:      _lenses
		lens_index:  _lensIndex
		delta:       _delta
		items:       _generatedItems
		retired:     _retirements
	}
	observation: {
		mode:               _mode
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
