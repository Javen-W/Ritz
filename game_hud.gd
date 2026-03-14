extends CanvasLayer
class_name GameHUD

# Loading overlay nodes
var _loading_overlay: ColorRect
var _loading_title: Label
var _loading_status: Label

# Bottom-left timer display
var _timer_label: Label

# Win popup nodes
var _win_overlay: ColorRect
var _win_message_label: Label

# Spinner animation
const SPINNER_CHARS: Array = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
const SPINNER_INTERVAL: float = 0.08
const HUD_LAYER: int = 100
const SUCCESS_COLOR := Color(0.2, 0.95, 0.3, 1.0)
var _spinner_idx: int = 0
var _spinner_time: float = 0.0

# Internal elapsed time (tracks Active state duration for display)
var _elapsed: float = 0.0
var _is_timing: bool = false


func _ready() -> void:
	layer = HUD_LAYER
	_build_loading_overlay()
	_build_timer_display()
	_build_win_popup()

	GameSignalbus.game_state_changed.connect(_on_game_state_changed)
	GameSignalbus.generation_update.connect(_on_generation_update)
	GameSignalbus.game_won.connect(_on_game_won)

# --------------------------------------------------------------
# Build loading overlay (shown during GENERATING state)
# --------------------------------------------------------------
func _build_loading_overlay() -> void:
	_loading_overlay = ColorRect.new()
	_loading_overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	_loading_overlay.anchor_right = 1.0
	_loading_overlay.anchor_bottom = 1.0
	_loading_overlay.visible = true
	add_child(_loading_overlay)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_loading_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	_loading_title = Label.new()
	_loading_title.text = "⠋  Generating game..."
	_loading_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_title.add_theme_font_size_override("font_size", 32)
	_loading_title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_loading_title)

	_loading_status = Label.new()
	_loading_status.text = "Starting..."
	_loading_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_status.add_theme_font_size_override("font_size", 18)
	_loading_status.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
	vbox.add_child(_loading_status)

# --------------------------------------------------------------
# Build timer label (bottom-left corner, shown during ACTIVE / FINISHED)
# --------------------------------------------------------------
func _build_timer_display() -> void:
	_timer_label = Label.new()
	_timer_label.anchor_left   = 0.0
	_timer_label.anchor_right  = 0.0
	_timer_label.anchor_top    = 1.0
	_timer_label.anchor_bottom = 1.0
	_timer_label.offset_left   = 16.0
	_timer_label.offset_right  = 220.0
	_timer_label.offset_top    = -56.0
	_timer_label.offset_bottom = -12.0
	_timer_label.text = "00:00"
	_timer_label.add_theme_font_size_override("font_size", 28)
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	_timer_label.visible = false
	add_child(_timer_label)

# --------------------------------------------------------------
# Build win popup (shown on FINISHED state)
# --------------------------------------------------------------
func _build_win_popup() -> void:
	_win_overlay = ColorRect.new()
	_win_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_win_overlay.anchor_right = 1.0
	_win_overlay.anchor_bottom = 1.0
	_win_overlay.visible = false
	add_child(_win_overlay)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_win_overlay.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   52)
	margin.add_theme_constant_override("margin_right",  52)
	margin.add_theme_constant_override("margin_top",    36)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "🎉  Puzzle Complete!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", SUCCESS_COLOR)
	vbox.add_child(title)

	_win_message_label = Label.new()
	_win_message_label.text = "Completed in 00:00"
	_win_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_message_label.add_theme_font_size_override("font_size", 26)
	_win_message_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_win_message_label)

# --------------------------------------------------------------
# Per-frame updates: spinner animation + timer countdown
# --------------------------------------------------------------
func _process(delta: float) -> void:
	# Animate the loading spinner
	if _loading_overlay.visible:
		_spinner_time += delta
		if _spinner_time >= SPINNER_INTERVAL:
			_spinner_time -= SPINNER_INTERVAL
			_spinner_idx = (_spinner_idx + 1) % SPINNER_CHARS.size()
			_loading_title.text = SPINNER_CHARS[_spinner_idx] + "  Generating game..."

	# Advance internal timer during the Active state
	if _is_timing:
		_elapsed += delta
		_refresh_timer_label()

# --------------------------------------------------------------
# Helpers
# --------------------------------------------------------------
func _refresh_timer_label() -> void:
	var total_secs := int(_elapsed)
	var mins := total_secs / 60
	var secs := total_secs % 60
	_timer_label.text = "%02d:%02d" % [mins, secs]

# --------------------------------------------------------------
# Signal handlers
# --------------------------------------------------------------
func _on_game_state_changed(state: int) -> void:
	match state:
		Game.GameState.GENERATING:
			_loading_overlay.visible = true
			_timer_label.visible = false
			_win_overlay.visible = false
			_is_timing = false
			_elapsed = 0.0

		Game.GameState.ACTIVE:
			_loading_overlay.visible = false
			_timer_label.visible = true
			_timer_label.add_theme_color_override("font_color", Color.WHITE)
			_win_overlay.visible = false
			_is_timing = true
			_elapsed = 0.0

		Game.GameState.FINISHED:
			_is_timing = false
			_loading_overlay.visible = false
			_timer_label.visible = true
			_timer_label.add_theme_color_override("font_color", SUCCESS_COLOR)
			# Win popup is shown by _on_game_won; just make sure overlay is hidden here
			_win_overlay.visible = false

func _on_generation_update(message: String) -> void:
	if _loading_status:
		_loading_status.text = message

func _on_game_won() -> void:
	# Freeze the final timer value and display the win popup.
	_refresh_timer_label()
	var total_secs := int(_elapsed)
	var mins := total_secs / 60
	var secs := total_secs % 60
	_win_message_label.text = "Completed in %02d:%02d" % [mins, secs]
	_win_overlay.visible = true
