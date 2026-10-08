class_name Controls
extends RefCounted
## Key rebinding. Each rebindable action's first keyboard key can be changed
## (other keys, like the arrow keys for moving, and the gamepad stay). Saved
## in the settings as {"keys": {action: physical keycode}} and applied to the
## InputMap at startup. Texts that name a key ("[E]  Open") ask tag() so
## they follow the player's bindings.

## The actions shown in the Controls panel, in order, with their labels.
const ACTIONS := [
	["move_up", "Move up"], ["move_down", "Move down"], ["move_left", "Move left"], ["move_right", "Move right"],
	["dash", "Dash"], ["interact", "Use"], ["army_stance", "Army stance"], ["inventory", "Inventory"],
	["skill_tree", "Skill tree"], ["reroll", "Reroll cards"], ["toggle_aim", "Mouse / auto aim"],
]

## Each action's first key as the project defines it, captured before any
## override (the InputMap outlives scene reloads).
static var _defaults := {}
## tag() results, kept until a binding changes (HUD texts ask every frame).
static var _tags := {}


## Applies the saved bindings to the InputMap.
static func apply() -> void:
	Landmarks.ensure_input()
	_capture_defaults()
	var keys: Dictionary = MetaProgress.setting("keys")
	for pair: Array in ACTIONS:
		var action: String = pair[0]
		var code: int = int(keys.get(action, _defaults.get(action, 0)))
		if code != 0:
			_set_first_key(action, code)


static func _capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for pair: Array in ACTIONS:
		var ev := _first_key(pair[0])
		if ev:
			_defaults[pair[0]] = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode


## Binds `action` to `code` (a physical keycode) and saves it. A key already
## used by another rebindable action is taken from it (swapped), so no two
## actions share a key.
static func rebind(action: String, code: int) -> void:
	_capture_defaults()
	var keys: Dictionary = MetaProgress.setting("keys").duplicate()
	var old := key_code(action)
	for pair: Array in ACTIONS:
		var other: String = pair[0]
		if other != action and key_code(other) == code:
			keys[other] = old
			_set_first_key(other, old)
	keys[action] = code
	_set_first_key(action, code)
	MetaProgress.set_setting("keys", keys)


static func reset() -> void:
	_capture_defaults()
	MetaProgress.set_setting("keys", {})
	for action: String in _defaults:
		_set_first_key(action, _defaults[action])


## The physical keycode of `action`'s first key (0 if it has none).
static func key_code(action: String) -> int:
	var ev := _first_key(action)
	if ev == null:
		return 0
	return ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode


## "E", "Space", "Tab"... for `action`'s first key.
static func key_name(action: String) -> String:
	var code := key_code(action)
	return OS.get_keycode_string(code) if code != 0 else "?"


## "[E]": how hints name the key for `action`.
static func tag(action: String) -> String:
	if not _tags.has(action):
		_tags[action] = "[%s]" % key_name(action)
	return _tags[action]


static func _first_key(action: String) -> InputEventKey:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev
	return null


static func _set_first_key(action: String, code: int) -> void:
	_tags.clear()
	if not InputMap.has_action(action):
		return
	var events := InputMap.action_get_events(action)
	var key := InputEventKey.new()
	key.physical_keycode = code as Key
	InputMap.action_erase_events(action)
	var placed := false
	for ev in events:
		if ev is InputEventKey and not placed:
			InputMap.action_add_event(action, key)
			placed = true
		else:
			InputMap.action_add_event(action, ev)
	if not placed:
		InputMap.action_add_event(action, key)
