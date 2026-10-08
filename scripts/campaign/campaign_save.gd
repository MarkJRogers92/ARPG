class_name CampaignSave
extends RefCounted
## Separate campaign slot. Validated temporary writes and recoverable rotation.

static var path := "user://campaign.save"
## Tests only: "write" or "replace". Does not touch legacy saves.
static var fail_stage := ""
static var last_error := ""

static func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".previous") or FileAccess.file_exists(path + ".rollback")

static func read() -> Dictionary:
	last_error = ""
	for suffix in ["", ".rollback", ".previous", ".bak"]:
		var data = read_variant(path + suffix)
		if data is Dictionary and CampaignState.validate(data) == "":
			return data.duplicate(true)
	if exists(): last_error = "Campaign save is damaged or from an unsupported version. Its files have been preserved."
	return {}

static func write(state: Dictionary) -> bool:
	last_error = CampaignState.validate(state)
	if last_error != "": return false
	if fail_stage == "write":
		last_error = "Campaign checkpoint could not be written. Retry after checking storage."
		return false
	if not atomic_write(path, state, fail_stage):
		last_error = "Campaign checkpoint could not be committed. Previous progress is preserved; retry."
		return false
	return true

static func read_variant(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path): return null
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null: return null
	# store_var begins with the encoded byte length. Reject damaged/truncated
	# prefixes without asking the engine to decode arbitrary junk.
	if file.get_length() < 8:
		file.close()
		return null
	var length := file.get_32()
	if length < 4 or length > 64 * 1024 * 1024 or length != file.get_length() - 4:
		file.close()
		return null
	file.seek(0)
	var data = file.get_var(false)
	var error := file.get_error()
	file.close()
	return data if error == OK else null

static func atomic_write(file_path: String, data: Dictionary, injected_failure := "") -> bool:
	var temp := file_path + ".tmp"
	var previous := file_path + ".rollback"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_var(data, false)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or read_variant(temp) != data: return false
	var absolute := ProjectSettings.globalize_path(file_path)
	var abs_previous := ProjectSettings.globalize_path(previous)
	var had_primary := FileAccess.file_exists(file_path)
	# Preserve a recovery candidate from a prior interrupted replacement.
	if had_primary:
		if FileAccess.file_exists(previous):
			# Never destroy the sole valid recovery candidate before commit.
			var preserved := previous + ".preserved-%d" % Time.get_ticks_usec()
			if DirAccess.rename_absolute(abs_previous, ProjectSettings.globalize_path(preserved)) != OK: return false
		if DirAccess.rename_absolute(absolute, abs_previous) != OK: return false
	if injected_failure == "replace" or DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), absolute) != OK:
		if had_primary: DirAccess.rename_absolute(abs_previous, absolute)
		return false
	# Primary is now verified and committed. A corrupt old primary must never
	# replace a good backup (campaign loader validates the old candidate).
	if had_primary:
		var old = read_variant(previous)
		var campaign_data := data.has("campaign_id")
		if old is Dictionary and (not campaign_data or CampaignState.validate(old) == ""):
			var backup := ProjectSettings.globalize_path(file_path + ".bak")
			if FileAccess.file_exists(file_path + ".bak"): DirAccess.remove_absolute(backup)
			DirAccess.rename_absolute(abs_previous, backup)
	return true
