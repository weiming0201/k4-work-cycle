package manifest

import "list"

context: _

#Text:   string & !=""
#Digest: string & =~"^[0-9a-f]{64}$"
#File: close({
	path:   #Text
	sha256: #Digest
})
#Skill: close({
	name:     "k4-observe" | "k4-goal" | "k4-plan" | "k4-run" | "k4-finish"
	path:     #Text
	protocol: #Text
	entrypoints: [#Text, ...#Text] & list.UniqueItems()
})
#Input: close({
	extension_id:      "k4-work-cycle"
	extension_version: #Text
	semantic_entry:    "WORKFLOW.md"
	cue_version:       "v0.17.1"
	shared_tool:       "tools/stable-result"
	skills: [#Skill, #Skill, #Skill, #Skill, #Skill]
	files: [#File, ...#File]
})
#Document: #Input
#Envelope: close({
	schema:            "k4-work-cycle-manifest/v2"
	generated_unix_ms: uint
	content_sha256:    #Digest
	bindings: close({})
	document: #Document
})

_input: #Input & context.input
_skillNames: [for skill in _input.skills {skill.name}]
_skillNamesUnique: list.UniqueItems(_skillNames) & true
_sortedSkillNames: list.SortStrings(_skillNames)
_sortedSkillNames: ["k4-finish", "k4-goal", "k4-observe", "k4-plan", "k4-run"]
_filePaths: [for file in _input.files {file.path}]
_filePathsUnique: list.UniqueItems(_filePaths) & true
for file in _input.files {
	if file.path == "manifest.json" {_manifestCannotInventoryItself: _|_}
}

generate: close({
	schema: "k4-work-cycle-manifest/v2"
	bindings: close({})
	document: _input
})

_existing: #Envelope & context.existing & {bindings: close({})}
_existingSkillNames: [for skill in _existing.document.skills {skill.name}]
_existingSkillNamesUnique: list.UniqueItems(_existingSkillNames) & true
_sortedExistingSkillNames: list.SortStrings(_existingSkillNames)
_sortedExistingSkillNames: ["k4-finish", "k4-goal", "k4-observe", "k4-plan", "k4-run"]
_existingFilePaths: [for file in _existing.document.files {file.path}]
_existingFilePathsUnique: list.UniqueItems(_existingFilePaths) & true
for file in _existing.document.files {
	if file.path == "manifest.json" {_existingManifestInventoriesItself: _|_}
}

validate: _existing
