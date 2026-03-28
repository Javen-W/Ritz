extends CanvasLayer
class_name OptionsMenu

## OptionsMenu – modal overlay for display / audio / render settings.
## Can be attached to any scene; toggled with show_options() / hide_options().
## All changes are immediately persisted to user://options.json via SaveManager.
## Available resolutions are defined in SaveManager.RESOLUTIONS (single source of truth).

signal closed

const TITLE_FONT_SIZE := 22
const LABEL_FONT_SIZE  := 13
const HEADER_COLOR     := Color(0.55, 0.78, 1.0, 1.0)
const SILENCE_DB       := -80.0   # dB value used for "fully muted" (below audible range)

# Volume controls
var _master_slider : HSlider
var _bgm_slider    : HSlider
var _sfx_slider    : HSlider

# Display controls
var _fullscreen_check : CheckBox
var _resolution_opt   : OptionButton
var _vsync_check      : CheckBox

# Render controls
var _msaa_opt : OptionButton


func _ready() -> void:
	layer = 200   # topmost
	_build_ui()
	visible = false


# ── UI construction ─────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Load saved options once; fall back to current engine state if missing.
	var opts := SaveManager.load_options()

	# Full-screen dark backdrop — clicking it closes the menu
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	backdrop.gui_input.connect(_on_backdrop_input)

	# Centred panel
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	# Title — icon + label row, centred horizontally
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 6)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_icon := TextureRect.new()
	title_icon.texture = load("res://assets/icons/icon_gear.svg")
	title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_icon.custom_minimum_size = Vector2(20, 20)
	title_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_icon.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	title_row.add_child(title_icon)
	var title := Label.new()
	title.text = "Options"
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", Color.WHITE)
	title_row.add_child(title)
	outer.add_child(title_row)
	outer.add_child(HSeparator.new())

	# ── Audio ────────────────────────────────────────────────────────────────
	outer.add_child(_section_label("Audio"))

	var master_db := float(opts.get("master_volume_db",
			AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))))
	var bgm_db := float(opts.get("bgm_volume_db", MusicManager.bgm_volume_db))
	var sfx_db := float(opts.get("sfx_volume_db", MusicManager.sfx_volume_db))

	_master_slider = _add_slider_row(outer, "Master Volume", 0.0, 1.0, db_to_linear(master_db))
	_master_slider.value_changed.connect(_on_master_volume_changed)

	_bgm_slider = _add_slider_row(outer, "Music Volume", 0.0, 1.0, db_to_linear(bgm_db))
	_bgm_slider.value_changed.connect(_on_bgm_volume_changed)

	_sfx_slider = _add_slider_row(outer, "SFX Volume", 0.0, 1.0, db_to_linear(sfx_db))
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	# ── Display ──────────────────────────────────────────────────────────────
	outer.add_child(HSeparator.new())
	outer.add_child(_section_label("Display"))

	# Window management APIs don't work in the Godot editor's embedded player or
	# in web/HTML5 builds (the browser controls the window).
	# Disable those controls and show a note so the user isn't confused.
	var embedded := OS.has_feature("editor") or OS.has_feature("web")

	var saved_res_idx := clampi(int(opts.get("resolution_idx", 0)), 0, SaveManager.RESOLUTIONS.size() - 1)
	_resolution_opt = OptionButton.new()
	_resolution_opt.focus_mode = Control.FOCUS_NONE
	_resolution_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for res in SaveManager.RESOLUTIONS:
		_resolution_opt.add_item("%dx%d" % [res[0], res[1]])
	_resolution_opt.select(saved_res_idx)           # set BEFORE connecting signal
	_resolution_opt.disabled = embedded
	_resolution_opt.item_selected.connect(_on_resolution_selected)
	outer.add_child(_row_with_label("Resolution", _resolution_opt))

	var saved_fullscreen := bool(opts.get("fullscreen",
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN))
	_fullscreen_check = CheckBox.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.focus_mode = Control.FOCUS_NONE
	_fullscreen_check.button_pressed = saved_fullscreen  # set BEFORE connecting signal
	_fullscreen_check.disabled = embedded
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	outer.add_child(_fullscreen_check)

	var saved_vsync := bool(opts.get("vsync",
			DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED))
	_vsync_check = CheckBox.new()
	_vsync_check.text = "V-Sync"
	_vsync_check.focus_mode = Control.FOCUS_NONE
	_vsync_check.button_pressed = saved_vsync           # set BEFORE connecting signal
	_vsync_check.disabled = embedded
	_vsync_check.toggled.connect(_on_vsync_toggled)
	outer.add_child(_vsync_check)

	if embedded:
		var note := Label.new()
		note.text = "  (i) Window settings apply in exported desktop builds only."
		note.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
		note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.55, 0.85))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outer.add_child(note)

	# ── Render ───────────────────────────────────────────────────────────────
	outer.add_child(HSeparator.new())
	outer.add_child(_section_label("Render"))

	var saved_msaa := clampi(int(opts.get("msaa", 0)), 0, 3)
	_msaa_opt = OptionButton.new()
	_msaa_opt.focus_mode = Control.FOCUS_NONE
	_msaa_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msaa_opt.add_item("MSAA Off", 0)
	_msaa_opt.add_item("MSAA 2×",  1)
	_msaa_opt.add_item("MSAA 4×",  2)
	_msaa_opt.add_item("MSAA 8×",  3)
	_msaa_opt.select(saved_msaa)                        # set BEFORE connecting signal
	_msaa_opt.item_selected.connect(_on_msaa_selected)
	outer.add_child(_row_with_label("Anti-aliasing", _msaa_opt))

	# ── Back button ──────────────────────────────────────────────────────────
	outer.add_child(HSeparator.new())
	var back_btn := Button.new()
	back_btn.text = "Close"
	back_btn.icon = load("res://assets/icons/icon_close.svg")
	back_btn.add_theme_constant_override("icon_max_width", 14)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.custom_minimum_size = Vector2(0, 38)
	back_btn.pressed.connect(hide_options)
	MusicManager.setup_button(back_btn)
	outer.add_child(back_btn)


func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "  " + text
	lbl.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	lbl.add_theme_color_override("font_color", HEADER_COLOR)
	return lbl


func _add_slider_row(parent: Control, lbl_text: String, min_v: float, max_v: float, def_v: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.01
	slider.value = def_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	parent.add_child(_row_with_label(lbl_text, slider))
	return slider


func _row_with_label(lbl_text: String, ctrl: Control) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	hbox.add_child(lbl)
	hbox.add_child(ctrl)
	return hbox


# ── Persistence ──────────────────────────────────────────────────────────────

## Collect all current control values and write them to user://options.json.
func _persist() -> void:
	if _master_slider == null:
		return  # UI not yet fully built
	var master_v := _master_slider.value
	var bgm_v    := _bgm_slider.value
	var sfx_v    := _sfx_slider.value
	var opts := {
		"master_volume_db": linear_to_db(master_v) if master_v > 0.0 else SILENCE_DB,
		"bgm_volume_db":    linear_to_db(bgm_v)    if bgm_v    > 0.0 else SILENCE_DB,
		"sfx_volume_db":    linear_to_db(sfx_v)    if sfx_v    > 0.0 else SILENCE_DB,
		"resolution_idx":   _resolution_opt.selected,
		"fullscreen":       _fullscreen_check.button_pressed,
		"vsync":            _vsync_check.button_pressed,
		"msaa":             _msaa_opt.selected,
	}
	SaveManager.save_options(opts)


# ── Visibility ───────────────────────────────────────────────────────────────

func show_options() -> void:
	visible = true
	MusicManager.play_sfx_click()


func hide_options() -> void:
	visible = false
	closed.emit()


# ── Event handlers ────────────────────────────────────────────────────────────

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_options()


func _on_master_volume_changed(value: float) -> void:
	var db := linear_to_db(value) if value > 0.0 else SILENCE_DB
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	_persist()


func _on_bgm_volume_changed(value: float) -> void:
	var db := linear_to_db(value) if value > 0.0 else SILENCE_DB
	MusicManager.set_bgm_volume(db)
	_persist()


func _on_sfx_volume_changed(value: float) -> void:
	var db := linear_to_db(value) if value > 0.0 else SILENCE_DB
	MusicManager.set_sfx_volume(db)
	_persist()


func _on_resolution_selected(idx: int) -> void:
	if idx < 0 or idx >= SaveManager.RESOLUTIONS.size():
		return
	# Only resize in windowed mode — in fullscreen the OS controls resolution.
	# Skip entirely in the editor's embedded player or web (window_set_size not supported).
	if not OS.has_feature("editor") and not OS.has_feature("web") \
			and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		var res: Array = SaveManager.RESOLUTIONS[idx]
		DisplayServer.window_set_size(Vector2i(res[0], res[1]))
		print("OptionsMenu: Resolution → %dx%d" % [res[0], res[1]])
	_persist()


func _on_fullscreen_toggled(pressed: bool) -> void:
	if not OS.has_feature("editor") and not OS.has_feature("web"):
		if pressed:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			# Re-apply the saved resolution when returning to windowed mode.
			var idx := _resolution_opt.selected
			if idx >= 0 and idx < SaveManager.RESOLUTIONS.size():
				var res: Array = SaveManager.RESOLUTIONS[idx]
				DisplayServer.window_set_size(Vector2i(res[0], res[1]))
	_persist()


func _on_vsync_toggled(pressed: bool) -> void:
	if not OS.has_feature("editor") and not OS.has_feature("web"):
		var mode := DisplayServer.VSYNC_ENABLED if pressed else DisplayServer.VSYNC_DISABLED
		DisplayServer.window_set_vsync_mode(mode)
	_persist()


func _on_msaa_selected(idx: int) -> void:
	var levels := [
		Viewport.MSAA_DISABLED,
		Viewport.MSAA_2X,
		Viewport.MSAA_4X,
		Viewport.MSAA_8X,
	]
	if idx < levels.size():
		get_viewport().msaa_2d = levels[idx]
	_persist()


# ── Helpers ──────────────────────────────────────────────────────────────────
