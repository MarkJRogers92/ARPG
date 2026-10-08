class_name CampaignSave
extends RefCounted
## Separate campaign slot. Validated temporary writes and recoverable rotation.

static var path := "user://campaign.save"
## Tests only: "write" or "replace". Does not touch legacy saves.
static var fail_stage := ""
static var last_error := ""

static func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".previous") or FileAccess.file_exists(path + ".rollback")

## A save that Continue can open: present and not abandoned. Damaged files
## still count so the player sees the recovery message.
static func resumable() -> bool:
	if not exists(): return false
	var data := read()
	return data.is_empty() or data.get("phase", "") != "ABANDONED"

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

static func atomic_write(file_path: String, data: Dictionary, injected_failure := "", validator: Callable = Callable()) -> bool:
	var campaign_data := data.has("campaign_id")
	if not _valid_candidate(data, campaign_data, validator): return false
	var temp := file_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_var(data, false)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or read_variant(temp) != data: return false

	# Copy a valid prior checkpoint to the backup without moving or deleting
	# any committed/recovery candidate. A crash at every step still leaves
	# the prior state at a path understood by both campaign and profile load.
	var backup_source := ""
	var prior: Variant = null
	for suffix in ["", ".rollback", ".previous", ".bak"]:
		var candidate = read_variant(file_path + suffix)
		if _valid_candidate(candidate, campaign_data, validator):
			backup_source = file_path + suffix
			prior = candidate
			break
	var backup := file_path + ".bak"
	if backup_source != "" and backup_source != backup:
		var staged_backup := backup + ".tmp"
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(backup_source), ProjectSettings.globalize_path(staged_backup)) != OK: return false
		if read_variant(staged_backup) != prior: return false
		if not _preserve_invalid_target(backup, campaign_data, validator): return false
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(staged_backup), ProjectSettings.globalize_path(backup)) != OK: return false

	# Same-directory rename replaces the destination atomically. Never move
	# the primary out of the loader's reach before its replacement commits.
	if injected_failure == "replace": return false
	if not _preserve_invalid_target(file_path, campaign_data, validator): return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(file_path)) != OK: return false

	# A valid backup and new primary now exist. Remove only redundant valid
	# legacy recovery copies, so a later load prefers the current backup.
	# Damaged/unsupported files stay intact for inspection and recovery.
	if backup_source != "":
		for suffix in [".rollback", ".previous"]:
			if _valid_candidate(read_variant(file_path + suffix), campaign_data, validator):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path + suffix))
	return true

static func _valid_candidate(candidate: Variant, campaign_data: bool, validator: Callable) -> bool:
	if not candidate is Dictionary: return false
	if validator.is_valid(): return validator.call(candidate) == true
	return CampaignState.validate(candidate) == "" if campaign_data else true


## Preserve exact bytes of a damaged or unsupported file before overwriting
## its fixed path. A preservation failure aborts the entire replacement.
static func _preserve_invalid_target(file_path: String, campaign_data: bool, validator: Callable) -> bool:
	if not FileAccess.file_exists(file_path) or _valid_candidate(read_variant(file_path), campaign_data, validator): return true
	var original_hash := FileAccess.get_sha256(file_path)
	if original_hash == "": return false
	var preserved := file_path + ".corrupt-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	while FileAccess.file_exists(preserved): preserved += "-next"
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(file_path), ProjectSettings.globalize_path(preserved)) != OK: return false
	return FileAccess.get_sha256(preserved) == original_hash and FileAccess.get_sha256(file_path) == original_hash
