extends CanvasLayer
class_name GenPanel

## GenPanel – in-game panel for tweaking and re-generating the puzzle.
##
## Provides SpinBox / OptionButton controls for every GameConfig parameter,
## grouped into sections (Core, Sampling, Noise, Constraint sizing, Constraint
## type probabilities).  "Generate" starts a new game with the chosen config;
## "Reset" unassigns all placed dominoes without regenerating the grid.
## The panel is toggled via a gear-icon button in the top-right corner of the HUD.

const PANEL_WIDTH    := 340
const LABEL_MIN_W    := 110
const SECTION_COLOR  := Color(0.55, 0.78, 1.0, 1.0)
const CONTROL_FONT_SIZE := 12
const BUTTON_FONT_SIZE := 14

# Core
var _seed_spin        : SpinBox
var _map_size_spin    : SpinBox
var _domino_spin      : SpinBox

# Sampling
var _dot_algo_opt       : OptionButton
var _path_branch_spin   : SpinBox
var _p_equal_tile_spin  : SpinBox

# Noise
var _noise_section      : VBoxContainer
var _noise_type_opt     : OptionButton
var _fractal_type_opt   : OptionButton
var _freq_spin          : SpinBox
var _octaves_spin       : SpinBox
var _lacunarity_spin    : SpinBox
var _gain_spin          : SpinBox

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
	# Load config from save state if available; otherwise apply defaults
	if SaveManager.has_save:
		var saved := SaveManager.load_config()
		_apply_config_to_controls(saved if saved != null else GameConfig.new())
	else:
		_apply_config_to_controls(GameConfig.new())

# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
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

	# Title — icon + label row, centred horizontally
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 6)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_icon := TextureRect.new()
	title_icon.texture = load("res://assets/icons/icon_gear.svg")
	title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_icon.custom_minimum_size = Vector2(18, 18)
	title_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_icon.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	title_row.add_child(title_icon)
	var title := Label.new()
	title.text = "Generation Config"
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color.WHITE)
	title_row.add_child(title)
	outer.add_child(title_row)
	outer.add_child(HSeparator.new())

	# Scrollable content
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.add_theme_constant_override("margin_left", 15)
	scroll.add_child(scroll_margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	scroll_margin.add_child(content)

	# ── Core ──────────────────────────────────────────────────────────────────
	content.add_child(_section_header("Core"))

	_seed_spin = _make_spinbox(0, 999999, 1)
	content.add_child(_row("Seed", _seed_spin))

	_map_size_spin = _make_spinbox(5, 100, 1)
	content.add_child(_row("Map Size", _map_size_spin))

	_domino_spin = _make_spinbox(1, 500, 1)
	content.add_child(_row("Dominos", _domino_spin))

	# ── Sampling ──────────────────────────────────────────────────────────────
	content.add_child(_section_header("Sampling"))

	_dot_algo_opt = _make_option([
		["sample_1 (random)",     GameConfig.DotSamplingAlgorithm.DOT_SAMPLE_1],
		["sample_2 (noise-map)",  GameConfig.DotSamplingAlgorithm.DOT_SAMPLE_2],
	])
	content.add_child(_row("Dot Value", _dot_algo_opt))

	_path_branch_spin = _make_spinbox(0.0, 1.0, 0.05)
	_path_branch_spin.custom_arrow_step = 0.1
	content.add_child(_row("P(Branch Path)", _path_branch_spin))

	_p_equal_tile_spin = _make_spinbox(0.0, 1.0, 0.05)
	_p_equal_tile_spin.custom_arrow_step = 0.1
	content.add_child(_row("P(Equal Tile)", _p_equal_tile_spin))

	# ── Noise ─────────────────────────────────────────────────────────────────
	_noise_section = VBoxContainer.new()
	_noise_section.add_theme_constant_override("separation", 5)
	content.add_child(_noise_section)
	_noise_section.add_child(_section_header("Noise"))

	_noise_type_opt = _make_option([
		["Simplex Smooth",  FastNoiseLite.TYPE_SIMPLEX_SMOOTH],
		["Simplex",         FastNoiseLite.TYPE_SIMPLEX],
		["Perlin",          FastNoiseLite.TYPE_PERLIN],
		["Cellular",        FastNoiseLite.TYPE_CELLULAR],
		["Value",           FastNoiseLite.TYPE_VALUE],
		["Value Cubic",     FastNoiseLite.TYPE_VALUE_CUBIC],
	])
	_noise_section.add_child(_row("Noise Type", _noise_type_opt))

	_fractal_type_opt = _make_option([
		["FBm",         FastNoiseLite.FRACTAL_FBM],
		["Ridged",      FastNoiseLite.FRACTAL_RIDGED],
		["Ping-Pong",   FastNoiseLite.FRACTAL_PING_PONG],
		["None",        FastNoiseLite.FRACTAL_NONE],
	])
	_noise_section.add_child(_row("Fractal Type", _fractal_type_opt))

	_freq_spin = _make_spinbox(0.001, 1.0, 0.001)
	_freq_spin.custom_arrow_step = 0.005
	_noise_section.add_child(_row("Frequency", _freq_spin))

	_octaves_spin = _make_spinbox(1, 8, 1)
	_noise_section.add_child(_row("Octaves", _octaves_spin))

	_lacunarity_spin = _make_spinbox(0.1, 8.0, 0.1)
	_lacunarity_spin.custom_arrow_step = 0.5
	_noise_section.add_child(_row("Lacunarity", _lacunarity_spin))

	_gain_spin = _make_spinbox(0.0, 1.0, 0.05)
	_gain_spin.custom_arrow_step = 0.1
	_noise_section.add_child(_row("Gain", _gain_spin))

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

	_skip_prob_pair     = _slider_row("P(Skip)",      0.0, 1.0, 0.25); content.add_child(_skip_prob_pair[2])
	_skip_max_size_spin = _make_spinbox(0, 6, 1)
	content.add_child(_row("Skip Max Size", _skip_max_size_spin))

	content.add_child(_section_header("Type Probabilities"))

	_prob_equal_pair   = _slider_row("P(Equal)",  0.0, 1.0, 0.30); content.add_child(_prob_equal_pair[2])
	_prob_neq_pair     = _slider_row("P(≠)",      0.0, 1.0, 0.15); content.add_child(_prob_neq_pair[2])
	_prob_less_pair    = _slider_row("P(<)",       0.0, 1.0, 0.10); content.add_child(_prob_less_pair[2])
	_prob_greater_pair = _slider_row("P(>)",       0.0, 1.0, 0.10); content.add_child(_prob_greater_pair[2])

	# ── Action buttons ────────────────────────────────────────────────────────
	outer.add_child(HSeparator.new())

	# Small utility row: Reset Defaults | Copy Config
	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 6)
	outer.add_child(util_row)

	var reset_defaults_btn := Button.new()
	reset_defaults_btn.text = "Defaults"
	reset_defaults_btn.icon = load("res://assets/icons/icon_reset.svg")
	# reset_defaults_btn.add_theme_constant_override("icon_max_width", 12)
	reset_defaults_btn.focus_mode = Control.FOCUS_NONE
	reset_defaults_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_defaults_btn.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	reset_defaults_btn.pressed.connect(_on_reset_defaults_pressed)
	MusicManager.setup_button(reset_defaults_btn)
	util_row.add_child(reset_defaults_btn)

	var copy_btn := Button.new()
	copy_btn.text = "Copy"
	copy_btn.icon = load("res://assets/icons/icon_copy.svg")
	# copy_btn.add_theme_constant_override("icon_max_width", 12)
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_btn.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	copy_btn.pressed.connect(_on_copy_config_pressed)
	MusicManager.setup_button(copy_btn)
	util_row.add_child(copy_btn)

	var gen_btn := Button.new()
	gen_btn.text = "Generate"
	gen_btn.icon = load("res://assets/icons/icon_dice.svg")
	# gen_btn.add_theme_constant_override("icon_max_width", 15)
	gen_btn.focus_mode = Control.FOCUS_NONE
	gen_btn.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE + 1)
	gen_btn.custom_minimum_size = Vector2(0, 42)
	gen_btn.pressed.connect(_on_generate_pressed)
	MusicManager.setup_button(gen_btn,
		Color(0.10, 0.35, 0.18, 0.92),
		Color(0.15, 0.52, 0.25, 0.97))
	outer.add_child(gen_btn)

# ── Helpers ──────────────────────────────────────────────────────────────────

func _section_header(text: String) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", SECTION_COLOR)
	
	margin.add_child(lbl)
	return margin

func _make_spinbox(min_val: float, max_val: float, step: float) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.step = step
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Match label font size so both sides of each row look uniform
	sb.get_line_edit().add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	return sb

## Creates an OptionButton from an Array of [label, id] pairs.
func _make_option(items: Array) -> OptionButton:
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	for item in items:
		opt.add_item(item[0], item[1])
	# Fix popup item font size (popup is separate from the button itself)
	opt.get_popup().add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	return opt

## Selects the OptionButton item whose id matches target_id.
func _select_by_id(opt: OptionButton, target_id: int) -> void:
	for i in opt.item_count:
		if opt.get_item_id(i) == target_id:
			opt.select(i)
			return

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
## Build a labelled HSlider row and return it as [slider, value_label, hbox_container].
## Index 0 = HSlider (read .value to get current setting).
## Index 1 = Label that displays the current value as "%.2f".
## Index 2 = HBoxContainer – add this to the parent layout.
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
	cfg.dot_sampling_algorithm = _dot_algo_opt.get_selected_id()
	cfg.tile_path_branch_prob  = _path_branch_spin.value
	cfg.p_equal_tile           = _p_equal_tile_spin.value
	cfg.noise_type        = _noise_type_opt.get_selected_id()
	cfg.fractal_type      = _fractal_type_opt.get_selected_id()
	cfg.noise_frequency   = _freq_spin.value
	cfg.noise_octaves     = int(_octaves_spin.value)
	cfg.fractal_lacunarity = _lacunarity_spin.value
	cfg.fractal_gain      = _gain_spin.value
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
	_select_by_id(_dot_algo_opt, cfg.dot_sampling_algorithm)
	_path_branch_spin.value    = cfg.tile_path_branch_prob
	_p_equal_tile_spin.value   = cfg.p_equal_tile
	_select_by_id(_noise_type_opt, cfg.noise_type)
	_select_by_id(_fractal_type_opt, cfg.fractal_type)
	_freq_spin.value      = cfg.noise_frequency
	_octaves_spin.value   = cfg.noise_octaves
	_lacunarity_spin.value = cfg.fractal_lacunarity
	_gain_spin.value      = cfg.fractal_gain
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

## Public method called by Game to sync the panel controls with the active config,
## e.g. after loading a saved game or after generating a new game.
func apply_config(cfg: GameConfig) -> void:
	_apply_config_to_controls(cfg)

func _on_reset_defaults_pressed() -> void:
	_apply_config_to_controls(GameConfig.new())
	print("GenPanel: Controls reset to default values")

func _on_copy_config_pressed() -> void:
	var cfg := _read_config()
	var data := {
		"seed":                   cfg.seed,
		"map_size":               cfg.map_size,
		"number_dominos":         cfg.number_dominos,
		"dot_sampling_algorithm": cfg.dot_sampling_algorithm,
		"tile_path_branch_prob":  cfg.tile_path_branch_prob,
		"p_equal_tile":           cfg.p_equal_tile,
		"noise_type":             cfg.noise_type,
		"noise_frequency":        cfg.noise_frequency,
		"noise_octaves":          cfg.noise_octaves,
		"fractal_type":           cfg.fractal_type,
		"fractal_lacunarity":     cfg.fractal_lacunarity,
		"fractal_gain":           cfg.fractal_gain,
		"constraint_group_mean":  cfg.constraint_group_mean,
		"constraint_group_std":   cfg.constraint_group_std,
		"constraint_group_min":   cfg.constraint_group_min,
		"constraint_group_max":   cfg.constraint_group_max,
		"constraint_skip_prob":   cfg.constraint_skip_prob,
		"constraint_skip_max_size": cfg.constraint_skip_max_size,
		"prob_equal":             cfg.prob_equal,
		"prob_not_equal":         cfg.prob_not_equal,
		"prob_less_than":         cfg.prob_less_than,
		"prob_greater_than":      cfg.prob_greater_than,
	}
	DisplayServer.clipboard_set(JSON.stringify(data, "\t", false))
	print("GenPanel: Config copied to clipboard")

func _on_generate_pressed() -> void:
	var game := get_tree().root.get_node("Game") as Game
	if not game:
		return
	if game.current_state == Game.GameState.GENERATING:
		print("GenPanel: Already generating — ignoring")
		return
	var cfg := _read_config()
	print("GenPanel: Requesting generation (seed=%d, map=%d, dominos=%d, algo=%d, p_equal_tile=%.2f)" % [
		cfg.seed, cfg.map_size, cfg.number_dominos, cfg.dot_sampling_algorithm, cfg.p_equal_tile
	])
	game.regenerate(cfg)
