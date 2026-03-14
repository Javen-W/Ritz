extends CanvasLayer
class_name OptionsMenu

## OptionsMenu – modal overlay for display / audio / render settings.
## Can be attached to any scene; toggled with show_options() / hide_options().

signal closed

const TITLE_FONT_SIZE := 22
const LABEL_FONT_SIZE  := 13
const HEADER_COLOR     := Color(0.55, 0.78, 1.0, 1.0)

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

# Available resolutions
const RESOLUTIONS: Array = [
	[1280, 720],
	[1600, 900],
	[1920, 1080],
	[2560, 1440],
]


func _ready() -> void:
	layer = 200   # topmost
	_build_ui()
	visible = false


# ── UI construction ─────────────────────────────────────────────────────────

func _build_ui() -> void:
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

	# Title
	var title := Label.new()
	title.text = "⚙  Options"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", Color.WHITE)
	outer.add_child(title)
	outer.add_child(HSeparator.new())

	# ── Audio ────────────────────────────────────────────────────────────────
	outer.add_child(_section_label("Audio"))

	_master_slider = _add_slider_row(outer, "Master Volume", 0.0, 1.0,
		db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))))
	_master_slider.value_changed.connect(_on_master_volume_changed)

	_bgm_slider = _add_slider_row(outer, "Music Volume", 0.0, 1.0, db_to_linear(MusicManager.bgm_volume_db))
	_bgm_slider.value_changed.connect(_on_bgm_volume_changed)

	_sfx_slider = _add_slider_row(outer, "SFX Volume", 0.0, 1.0, db_to_linear(MusicManager.sfx_volume_db))
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	# ── Display ──────────────────────────────────────────────────────────────
	outer.add_child(HSeparator.new())
	outer.add_child(_section_label("Display"))

	_resolution_opt = OptionButton.new()
	_resolution_opt.focus_mode = Control.FOCUS_NONE
	_resolution_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for res in RESOLUTIONS:
		_resolution_opt.add_item("%dx%d" % [res[0], res[1]])
	_resolution_opt.select(0)
	_resolution_opt.item_selected.connect(_on_resolution_selected)
	outer.add_child(_row_with_label("Resolution", _resolution_opt))

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.focus_mode = Control.FOCUS_NONE
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_fullscreen_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	outer.add_child(_fullscreen_check)

	_vsync_check = CheckBox.new()
	_vsync_check.text = "V-Sync"
	_vsync_check.focus_mode = Control.FOCUS_NONE
	_vsync_check.toggled.connect(_on_vsync_toggled)
	_vsync_check.button_pressed = (DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
	outer.add_child(_vsync_check)

	# ── Render ───────────────────────────────────────────────────────────────
	outer.add_child(HSeparator.new())
	outer.add_child(_section_label("Render"))

	_msaa_opt = OptionButton.new()
	_msaa_opt.focus_mode = Control.FOCUS_NONE
	_msaa_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msaa_opt.add_item("MSAA Off",   0)
	_msaa_opt.add_item("MSAA 2×",    1)
	_msaa_opt.add_item("MSAA 4×",    2)
	_msaa_opt.add_item("MSAA 8×",    3)
	_msaa_opt.select(0)
	_msaa_opt.item_selected.connect(_on_msaa_selected)
	outer.add_child(_row_with_label("Anti-aliasing", _msaa_opt))

	# ── Back button ──────────────────────────────────────────────────────────
	outer.add_child(HSeparator.new())
	var back_btn := Button.new()
	back_btn.text = "✕  Close"
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
	var db := linear_to_db(value) if value > 0.0 else -80.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)


func _on_bgm_volume_changed(value: float) -> void:
	var db := linear_to_db(value) if value > 0.0 else -80.0
	MusicManager.set_bgm_volume(db)


func _on_sfx_volume_changed(value: float) -> void:
	var db := linear_to_db(value) if value > 0.0 else -80.0
	MusicManager.set_sfx_volume(db)


func _on_resolution_selected(idx: int) -> void:
	if idx < 0 or idx >= RESOLUTIONS.size():
		return
	var res: Array = RESOLUTIONS[idx]
	DisplayServer.window_set_size(Vector2i(res[0], res[1]))
	get_tree().root.size = Vector2i(res[0], res[1])
	print("OptionsMenu: Resolution → %dx%d" % [res[0], res[1]])


func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_vsync_toggled(pressed: bool) -> void:
	var mode := DisplayServer.VSYNC_ENABLED if pressed else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


func _on_msaa_selected(idx: int) -> void:
	var levels := [
		Viewport.MSAA_DISABLED,
		Viewport.MSAA_2X,
		Viewport.MSAA_4X,
		Viewport.MSAA_8X,
	]
	if idx < levels.size():
		get_viewport().msaa_2d = levels[idx]


# ── Helpers ──────────────────────────────────────────────────────────────────
