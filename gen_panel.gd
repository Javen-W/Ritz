extends CanvasLayer
class_name GenPanel

const PANEL_WIDTH    := 290
const LABEL_MIN_W    := 110
const SECTION_COLOR  := Color(0.55, 0.78, 1.0, 1.0)
const CONTROL_FONT_SIZE := 12

# Core
var _seed_spin        : SpinBox
var _map_size_spin    : SpinBox
var _domino_spin      : SpinBox

# Sampling
var _dot_mode_opt      : OptionButton
var _path_branch_spin  : SpinBox
var _dot_change_spin   : SpinBox

# Noise
var _noise_section   : VBoxContainer
var _freq_spin       : SpinBox
var _octaves_spin    : SpinBox

# Constraint group
var _grp_mean_spin : SpinBox
var _grp_std_spin  : SpinBox
var _grp_min_spin  : SpinBox
var _grp_max_spin  : SpinBox
var _skip_prob_pair     : Array   # [slider, value_label]
var _skip_max_size_spin : SpinBox

# Constraint type probabilities  [slider, value_label]
var _prob_equal_pair   : Array
var _prob_neq_pair     : Array
var _prob_less_pair    : Array
var _prob_greater_pair : Array

# ──────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 50   # above game world, below HUD (layer 100)
	_build_ui()
	_apply_config_to_controls(GameConfig.new())

# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Root control — full-screen so anchors work
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Panel body — always visible, anchored to right edge
	var panel_root := PanelContainer.new()
	panel_root.anchor_left   = 1.0
	panel_root.anchor_right  = 1.0
	panel_root.anchor_top    = 0.0
	panel_root.anchor_bottom = 1.0
	panel_root.offset_left   = -PANEL_WIDTH
	panel_root.offset_right  = 0
	root.add_child(panel_root)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel_root.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	# Title
	var title := Label.new()
	title.text = "⚙  Generation Config"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color.WHITE)
	outer.add_child(title)
	outer.add_child(HSeparator.new())

	# Scrollable content
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	scroll.add_child(content)

	# ── Core ────────────────────────────────────────────────────────────────
	content.add_child(_section_header("Core"))

	_seed_spin = _make_spinbox(0, 999999, 1)
	content.add_child(_row("Seed", _seed_spin))

	_map_size_spin = _make_spinbox(5, 100, 1)
	content.add_child(_row("Map Size", _map_size_spin))

	_domino_spin = _make_spinbox(1, 500, 1)
	content.add_child(_row("Dominos", _domino_spin))

	# ── Sampling ─────────────────────────────────────────────────────────────
	content.add_child(_section_header("Sampling"))

	_dot_mode_opt = OptionButton.new()
	_dot_mode_opt.focus_mode = Control.FOCUS_NONE
	_dot_mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dot_mode_opt.add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	_dot_mode_opt.add_item("Noise Retention", GameConfig.DotSamplingMode.NOISE_RETENTION)
	_dot_mode_opt.add_item("Noise Direct",    GameConfig.DotSamplingMode.NOISE_DIRECT)
	content.add_child(_row("Dot Value Mode", _dot_mode_opt))

	_path_branch_spin = _make_spinbox(0.0, 1.0, 0.05)
	_path_branch_spin.custom_arrow_step = 0.1
	content.add_child(_row("Path Branch P", _path_branch_spin))

	_dot_change_spin = _make_spinbox(0.0, 1.0, 0.05)
	_dot_change_spin.custom_arrow_step = 0.1
	content.add_child(_row("Dot Change P", _dot_change_spin))

	# ── Noise ─────────────────────────────────────────────────────────────────
	_noise_section = VBoxContainer.new()
	_noise_section.add_theme_constant_override("separation", 5)
	content.add_child(_noise_section)
	_noise_section.add_child(_section_header("Noise"))

	_freq_spin = _make_spinbox(0.001, 1.0, 0.001)
	_freq_spin.custom_arrow_step = 0.005
	_noise_section.add_child(_row("Frequency", _freq_spin))

	_octaves_spin = _make_spinbox(1, 8, 1)
	_noise_section.add_child(_row("Octaves", _octaves_spin))

	# ── Constraints ───────────────────────────────────────────────────────────
	content.add_child(_section_header("Constraints"))

	_grp_mean_spin = _make_spinbox(1.0, 6.0, 0.5)
	content.add_child(_row("Group Mean", _grp_mean_spin))

	_grp_std_spin = _make_spinbox(0.1, 3.0, 0.1)
	content.add_child(_row("Group Std", _grp_std_spin))

	_grp_min_spin = _make_spinbox(1, 6, 1)
	content.add_child(_row("Group Min", _grp_min_spin))

	_grp_max_spin = _make_spinbox(1, 6, 1)
	content.add_child(_row("Group Max", _grp_max_spin))

	_skip_prob_pair     = _slider_row("Skip Prob",     0.0, 1.0, 0.25); content.add_child(_skip_prob_pair[2])
	_skip_max_size_spin = _make_spinbox(0, 6, 1)
	content.add_child(_row("Skip Max Size", _skip_max_size_spin))

	content.add_child(_section_header("Type Probabilities"))

	_prob_equal_pair   = _slider_row("P(Equal)",  0.0, 1.0, 0.30); content.add_child(_prob_equal_pair[2])
	_prob_neq_pair     = _slider_row("P(≠)",      0.0, 1.0, 0.15); content.add_child(_prob_neq_pair[2])
	_prob_less_pair    = _slider_row("P(<)",       0.0, 1.0, 0.10); content.add_child(_prob_less_pair[2])
	_prob_greater_pair = _slider_row("P(>)",       0.0, 1.0, 0.10); content.add_child(_prob_greater_pair[2])

	# ── Generate button ───────────────────────────────────────────────────────
	outer.add_child(HSeparator.new())

	var gen_btn := Button.new()
	gen_btn.text = "🎲  Generate"
	gen_btn.focus_mode = Control.FOCUS_NONE
	gen_btn.add_theme_font_size_override("font_size", 15)
	gen_btn.custom_minimum_size = Vector2(0, 42)
	gen_btn.pressed.connect(_on_generate_pressed)
	outer.add_child(gen_btn)

# ── Helpers ──────────────────────────────────────────────────────────────────

func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "  " + text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", SECTION_COLOR)
	lbl.add_theme_constant_override("margin_top", 6)
	return lbl

func _make_spinbox(min_val: float, max_val: float, step: float) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.step = step
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Match the label font size so both sides of the row look uniform
	sb.get_line_edit().add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	return sb

func _row(label_text: String, ctrl: Control) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(LABEL_MIN_W, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	hbox.add_child(lbl)
	hbox.add_child(ctrl)
	return hbox

# Returns [slider, value_label, container_hbox]
func _slider_row(label_text: String, min_v: float, max_v: float, default_v: float) -> Array:
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.01
	slider.value = default_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % default_v
	val_lbl.custom_minimum_size = Vector2(38, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	slider.value_changed.connect(func(v: float) -> void: val_lbl.text = "%.2f" % v)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(LABEL_MIN_W, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	hbox.add_child(lbl)
	hbox.add_child(slider)
	hbox.add_child(val_lbl)
	return [slider, val_lbl, hbox]

# ── Config read / write ──────────────────────────────────────────────────────

func _read_config() -> GameConfig:
	var cfg := GameConfig.new()
	cfg.seed              = int(_seed_spin.value)
	cfg.map_size          = int(_map_size_spin.value)
	cfg.number_dominos    = int(_domino_spin.value)
	cfg.dot_sampling_mode = _dot_mode_opt.get_selected_id()
	cfg.tile_path_branch_prob = _path_branch_spin.value
	cfg.dot_change_threshold  = _dot_change_spin.value
	cfg.noise_frequency   = _freq_spin.value
	cfg.noise_octaves     = int(_octaves_spin.value)
	cfg.constraint_group_mean = _grp_mean_spin.value
	cfg.constraint_group_std  = _grp_std_spin.value
	cfg.constraint_group_min  = int(_grp_min_spin.value)
	cfg.constraint_group_max  = int(_grp_max_spin.value)
	cfg.constraint_skip_prob     = (_skip_prob_pair[0] as HSlider).value
	cfg.constraint_skip_max_size = int(_skip_max_size_spin.value)
	cfg.prob_equal        = (_prob_equal_pair[0]   as HSlider).value
	cfg.prob_not_equal    = (_prob_neq_pair[0]     as HSlider).value
	cfg.prob_less_than    = (_prob_less_pair[0]    as HSlider).value
	cfg.prob_greater_than = (_prob_greater_pair[0] as HSlider).value
	# Clamp dominos to fit inside the map
	var max_dominos := (cfg.map_size * cfg.map_size) / 2
	cfg.number_dominos = clampi(cfg.number_dominos, 1, max_dominos)
	return cfg

func _apply_config_to_controls(cfg: GameConfig) -> void:
	_seed_spin.value      = cfg.seed
	_map_size_spin.value  = cfg.map_size
	_domino_spin.value    = cfg.number_dominos
	_dot_mode_opt.select(cfg.dot_sampling_mode)
	_path_branch_spin.value   = cfg.tile_path_branch_prob
	_dot_change_spin.value    = cfg.dot_change_threshold
	_freq_spin.value      = cfg.noise_frequency
	_octaves_spin.value   = cfg.noise_octaves
	_grp_mean_spin.value  = cfg.constraint_group_mean
	_grp_std_spin.value   = cfg.constraint_group_std
	_grp_min_spin.value   = cfg.constraint_group_min
	_grp_max_spin.value   = cfg.constraint_group_max
	(_skip_prob_pair[0]     as HSlider).value = cfg.constraint_skip_prob
	_skip_max_size_spin.value = cfg.constraint_skip_max_size
	(_prob_equal_pair[0]   as HSlider).value = cfg.prob_equal
	(_prob_neq_pair[0]     as HSlider).value = cfg.prob_not_equal
	(_prob_less_pair[0]    as HSlider).value = cfg.prob_less_than
	(_prob_greater_pair[0] as HSlider).value = cfg.prob_greater_than

# ── Event handlers ────────────────────────────────────────────────────────────

func _on_generate_pressed() -> void:
	var game := get_tree().root.get_node("Game") as Game
	if not game:
		return
	if game.current_state == Game.GameState.GENERATING:
		print("GenPanel: Already generating — ignoring")
		return
	var cfg := _read_config()
	print("GenPanel: Requesting generation (seed=%d, map=%d, dominos=%d, mode=%d, branch_p=%.2f)" % [
		cfg.seed, cfg.map_size, cfg.number_dominos, cfg.dot_sampling_mode, cfg.tile_path_branch_prob
	])
	game.regenerate(cfg)
