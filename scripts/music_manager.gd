extends Node

## MusicManager – autoload for classical background music (MP3 queue) and UI sound effects.
##
## BGM: Plays royalty-free classical pieces from assets/music/ in a shuffled endless
## queue without immediate repeats.  When a new track begins a brief "Now Playing"
## notification fades in at the top of the screen; long titles auto-scroll.
##
## SFX: Short synthesised beep tones for hover and click events.

const SAMPLE_RATE := 44100.0

# ── Classical BGM track list ─────────────────────────────────────────────────
# Each entry: { "path": "res://…", "title": "Display title" }
const SONGS: Array = [
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 01 - Prelude No. 1 in C major, BWV 846 (Kimiko Ishizaka).mp3",
		"title": "Bach – Prelude No. 1 in C major, BWV 846"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 02 - Fugue No. 1 in C major, BWV 846 (Kimiko Ishizaka).mp3",
		"title": "Bach – Fugue No. 1 in C major, BWV 846"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 04 - Fugue No. 2 in C minor, BWV 847 (Kimiko Ishizaka).mp3",
		"title": "Bach – Fugue No. 2 in C minor, BWV 847"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 05 - Prelude No. 3 in C-sharp major, BWV 848 (Kimiko Ishizaka).mp3",
		"title": "Bach – Prelude No. 3 in C\u266f major, BWV 848"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 06 - Fugue No. 3 in C-sharp major, BWV 848 (Kimiko Ishizaka).mp3",
		"title": "Bach – Fugue No. 3 in C\u266f major, BWV 848"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 08 - Fugue No. 4 in C-sharp minor, BWV 849 (Kimiko Ishizaka).mp3",
		"title": "Bach – Fugue No. 4 in C\u266f minor, BWV 849"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 09 - Prelude No. 5 in D major, BWV 850 (Kimiko Ishizaka).mp3",
		"title": "Bach – Prelude No. 5 in D major, BWV 850"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 11 - Prelude No. 6 in D minor, BWV 851 (Kimiko Ishizaka).mp3",
		"title": "Bach – Prelude No. 6 in D minor, BWV 851"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 12 - Fugue No. 6 in D minor, BWV 851 (Kimiko Ishizaka).mp3",
		"title": "Bach – Fugue No. 6 in D minor, BWV 851"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 13 - Prelude No. 7 in E-flat major, BWV 852 (Kimiko Ishizaka).mp3",
		"title": "Bach – Prelude No. 7 in E\u266d major, BWV 852"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 14 - Fugue No. 7 in E-flat major, BWV 852 (Kimiko Ishizaka).mp3",
		"title": "Bach – Fugue No. 7 in E\u266d major, BWV 852"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 16 - Fugue No. 8 in D-sharp minor, BWV 853 (Kimiko Ishizaka).mp3",
		"title": "Bach – Fugue No. 8 in D\u266f minor, BWV 853"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 17 - Prelude No. 9 in E major, BWV 854 (Kimiko Ishizaka).mp3",
		"title": "Bach – Prelude No. 9 in E major, BWV 854"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 18 - Fugue No. 9 in E major, BWV 854 (Kimiko Ishizaka).mp3",
		"title": "Bach – Fugue No. 9 in E major, BWV 854"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 20 - Fugue No. 10 in E minor, BWV 855 (Kimiko Ishizaka).mp3",
		"title": "Bach – Fugue No. 10 in E minor, BWV 855"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 22 - Fugue No. 11 in F major, BWV 856 (Kimiko Ishizaka).mp3",
		"title": "Bach – Fugue No. 11 in F major, BWV 856"
	},
	{
		"path": "res://assets/music/Classicals.de - Bach - The Well-Tempered Clavier, Book 1 - 23 - Prelude No. 12 in F minor, BWV 857 (Kimiko Ishizaka).mp3",
		"title": "Bach – Prelude No. 12 in F minor, BWV 857"
	},
]

# ── BGM state ────────────────────────────────────────────────────────────────
const BGM_MAX_SKIP: int = 5   # max consecutive failed loads before giving up

var _bgm_player:      AudioStreamPlayer
var _bgm_queue:       Array[int] = []     # shuffled indices into SONGS
var _bgm_last_played: int        = -1     # prevents immediate repeat on reshuffle
var _bgm_streams:     Array      = []     # preloaded AudioStream for each SONGS entry

# ── SFX players ──────────────────────────────────────────────────────────────
var _sfx_hover_player:       AudioStreamPlayer
var _sfx_click_player:       AudioStreamPlayer
var _sfx_domino_pick_player: AudioStreamPlayer
var _sfx_domino_drop_player: AudioStreamPlayer

# ── Volume settings (dB) ─────────────────────────────────────────────────────
var bgm_volume_db: float = -6.0
var sfx_volume_db: float = -14.0

# ── "Now Playing" notification ────────────────────────────────────────────────
# Semi-translucent beige panel that fades in/out at the top of the screen.
# Long titles auto-scroll horizontally.

const NP_MAX_WIDTH:     float = 480.0   # maximum width of the notification panel
const NP_FONT_SIZE:     int   = 14
const NP_FADE_DURATION: float = 0.7     # seconds for each fade in/out
const NP_HOLD_DURATION: float = 5.5     # seconds the notification stays fully visible
const NP_SCROLL_SPEED:  float = 45.0    # pixels per second for long-title scrolling
const NP_SCROLL_PAUSE:  float = 1.2     # pause at each end of the scroll cycle
const NP_TOP_MARGIN:    float = 12.0    # distance from top of viewport
const NP_CANVAS_LAYER:  int   = 150     # above game UI (10) but below options menu (200)

# Node references for the "Now Playing" overlay
var _np_layer:         CanvasLayer
var _np_panel:         PanelContainer
var _np_clip:          Control           # clipping container for the label
var _np_label:         Label

# Notification state
var _np_visible:       bool  = false
var _np_tween:         Tween
var _np_scroll_pos:    float = 0.0      # current label x-offset (negative = scrolled right)
var _np_scroll_dir:    float = -1.0     # -1 = scrolling left, +1 = scrolling right
var _np_scroll_pause:  float = 0.0     # countdown for pause at each end
var _np_label_width:   float = 0.0
var _np_overflow:      float = 0.0     # how many pixels the label overflows the clip


func _ready() -> void:
	_setup_emoji_font()
	var opts := SaveManager.load_options()
	if opts.has("bgm_volume_db"):
		bgm_volume_db = float(opts["bgm_volume_db"])
	if opts.has("sfx_volume_db"):
		sfx_volume_db = float(opts["sfx_volume_db"])
	_setup_bgm()
	_setup_sfx()
	_setup_now_playing_ui()
	_advance_queue()
	if opts.has("master_volume_db"):
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Master"), float(opts["master_volume_db"]))


# ── Emoji font ────────────────────────────────────────────────────────────────

## Register a subset emoji font as a global fallback so that emoji characters
## (🎉 📋 🎲 ⚙) render correctly in all Labels on every platform, including
## the itch.io web export where Godot cannot fall back to a system emoji font.
func _setup_emoji_font() -> void:
	const EMOJI_PATH := "res://assets/fonts/NotoColorEmoji.ttf"
	if not FileAccess.file_exists(EMOJI_PATH):
		push_warning("MusicManager: emoji font not found at %s" % EMOJI_PATH)
		return
	var emoji_font := FontFile.new()
	emoji_font.set_data(FileAccess.get_file_as_bytes(EMOJI_PATH))
	# Append to the engine's fallback font so emoji glyphs are tried last,
	# after the primary font fails to find a glyph.
	var base := ThemeDB.fallback_font
	if base:
		var fbs: Array[Font] = base.fallbacks
		fbs.append(emoji_font)
		base.fallbacks = fbs
	else:
		ThemeDB.fallback_font = emoji_font


# ── BGM ──────────────────────────────────────────────────────────────────────

func _setup_bgm() -> void:
	# Preload all audio streams once so there are no per-track load stalls during play
	# (important for web/HTML5 builds where synchronous disk I/O is unavailable).
	_bgm_streams.resize(SONGS.size())
	for i in range(SONGS.size()):
		var stream = load(SONGS[i]["path"])
		if stream == null:
			push_warning("MusicManager: Failed to preload '%s'" % SONGS[i]["path"])
		_bgm_streams[i] = stream

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = bgm_volume_db
	_bgm_player.bus = "Master"
	_bgm_player.finished.connect(_on_song_finished)
	add_child(_bgm_player)


## Build a fresh shuffled queue; avoid starting with the same track that just ended.
func _build_queue() -> void:
	_bgm_queue.clear()
	for i in range(SONGS.size()):
		_bgm_queue.append(i)
	_bgm_queue.shuffle()
	# Prevent immediate repeat: swap the first element away from _bgm_last_played.
	if _bgm_last_played >= 0 and _bgm_queue.size() > 1 and _bgm_queue[0] == _bgm_last_played:
		_bgm_queue.append(_bgm_queue.pop_front())


## Pick the next track from the queue and play it.
func _advance_queue(skip_count: int = 0) -> void:
	if _bgm_queue.is_empty():
		_build_queue()
	var idx: int = _bgm_queue.pop_front()
	var song: Dictionary = SONGS[idx]
	_play_song(idx, song["path"], song["title"], skip_count)


func _play_song(idx: int, path: String, title: String, skip_count: int = 0) -> void:
	var stream = _bgm_streams[idx]
	if stream == null:
		push_warning("MusicManager: Preloaded stream missing for '%s' — skipping" % path)
		if skip_count < BGM_MAX_SKIP:
			_advance_queue(skip_count + 1)
		else:
			push_error("MusicManager: Too many consecutive load failures — giving up")
		return
	# Only record this as the last-played track after confirming the stream is valid.
	_bgm_last_played = idx
	_bgm_player.stream = stream
	_bgm_player.play()
	print("MusicManager: Now playing — %s" % title)
	_show_now_playing(title)


func _on_song_finished() -> void:
	_advance_queue()


## Play background music (idempotent – does nothing if already playing).
func play_bgm() -> void:
	if not _bgm_player.playing:
		if _bgm_player.stream != null:
			_bgm_player.play()   # resume a track that was stopped mid-play
		else:
			_advance_queue()     # no track loaded yet – start from the queue


## Stop background music.
func stop_bgm() -> void:
	_bgm_player.stop()


func set_bgm_volume(db: float) -> void:
	bgm_volume_db = db
	_bgm_player.volume_db = db


# ── SFX ──────────────────────────────────────────────────────────────────────

func _setup_sfx() -> void:
	_sfx_hover_player = AudioStreamPlayer.new()
	_sfx_hover_player.volume_db = sfx_volume_db
	_sfx_hover_player.stream = _make_beep_wav(880.0, 0.06)
	add_child(_sfx_hover_player)

	_sfx_click_player = AudioStreamPlayer.new()
	_sfx_click_player.volume_db = sfx_volume_db
	_sfx_click_player.stream = _make_beep_wav(440.0, 0.10)
	add_child(_sfx_click_player)

	# Domino pick-up: bright mid-range pluck (distinct from button hover/click)
	_sfx_domino_pick_player = AudioStreamPlayer.new()
	_sfx_domino_pick_player.volume_db = sfx_volume_db
	_sfx_domino_pick_player.stream = _make_beep_wav(660.0, 0.07)
	add_child(_sfx_domino_pick_player)

	# Domino drop/place: lower, slightly longer thud
	_sfx_domino_drop_player = AudioStreamPlayer.new()
	_sfx_domino_drop_player.volume_db = sfx_volume_db
	_sfx_domino_drop_player.stream = _make_beep_wav(330.0, 0.12)
	add_child(_sfx_domino_drop_player)


## Generate a short sine-wave beep as an AudioStreamWAV.
func _make_beep_wav(freq: float, duration: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t   := float(i) / SAMPLE_RATE
		var env := 1.0 - float(i) / float(n)
		var v   := int(16000.0 * sin(TAU * freq * t) * env)
		v = clampi(v, -32768, 32767)
		data[i * 2]     = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format   = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.stereo   = false
	wav.data     = data
	return wav


func set_sfx_volume(db: float) -> void:
	sfx_volume_db = db
	_sfx_hover_player.volume_db = db
	_sfx_click_player.volume_db = db
	_sfx_domino_pick_player.volume_db = db
	_sfx_domino_drop_player.volume_db = db


func play_sfx_hover() -> void:
	if _sfx_hover_player and _sfx_hover_player.stream:
		_sfx_hover_player.play()


func play_sfx_click() -> void:
	if _sfx_click_player and _sfx_click_player.stream:
		_sfx_click_player.play()


func play_sfx_domino_pick() -> void:
	if _sfx_domino_pick_player and _sfx_domino_pick_player.stream:
		_sfx_domino_pick_player.play()


func play_sfx_domino_drop() -> void:
	if _sfx_domino_drop_player and _sfx_domino_drop_player.stream:
		_sfx_domino_drop_player.play()


# ── "Now Playing" notification ────────────────────────────────────────────────

func _setup_now_playing_ui() -> void:
	_np_layer = CanvasLayer.new()
	_np_layer.layer = NP_CANVAS_LAYER   # above game content, below options menu (layer 200)
	add_child(_np_layer)

	# Panel background: semi-translucent beige, rounded corners
	_np_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.92, 0.82, 0.82)   # warm beige, semi-translucent
	sb.set_corner_radius_all(10)
	sb.content_margin_left   = 14.0
	sb.content_margin_right  = 14.0
	sb.content_margin_top    = 7.0
	sb.content_margin_bottom = 7.0
	_np_panel.add_theme_stylebox_override("panel", sb)
	_np_panel.modulate.a = 0.0   # start invisible
	_np_layer.add_child(_np_panel)

	# Clipping container: caps the width for long titles
	_np_clip = Control.new()
	_np_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_np_clip.custom_minimum_size = Vector2(0.0, 0.0)
	_np_panel.add_child(_np_clip)

	# Label: the actual "Now Playing: …" text
	_np_label = Label.new()
	_np_label.add_theme_font_size_override("font_size", NP_FONT_SIZE)
	_np_label.add_theme_color_override("font_color", Color(0.25, 0.18, 0.08, 1.0))
	_np_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_np_clip.add_child(_np_label)


## Display the "Now Playing" notification for the given song title.
func _show_now_playing(title: String) -> void:
	_np_label.text = "♪  Now Playing: %s" % title

	# Wait one frame for the label to compute its size, then position the panel.
	await get_tree().process_frame
	_position_now_playing_panel()

	# Reset scroll
	_np_scroll_pos   = 0.0
	_np_scroll_dir   = -1.0
	_np_scroll_pause = NP_SCROLL_PAUSE
	_np_label.position.x = 0.0

	# Restart the fade-in/hold/fade-out sequence.
	if _np_tween:
		_np_tween.kill()
	_np_visible = true
	_np_tween = create_tween()
	_np_tween.tween_property(_np_panel, "modulate:a", 1.0, NP_FADE_DURATION)
	_np_tween.tween_interval(_np_hold_seconds())
	_np_tween.tween_property(_np_panel, "modulate:a", 0.0, NP_FADE_DURATION)
	_np_tween.tween_callback(func() -> void: _np_visible = false)


## How long the notification stays fully visible (longer for scrolling titles).
func _np_hold_seconds() -> float:
	if _np_overflow > 0.0:
		return NP_HOLD_DURATION + (_np_overflow / NP_SCROLL_SPEED) * 2.0 + NP_SCROLL_PAUSE * 2.0
	return NP_HOLD_DURATION


## Position the notification panel centred at the top of the viewport.
func _position_now_playing_panel() -> void:
	var vp_size  := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	_np_label_width = _np_label.get_minimum_size().x

	# Clip width: the label's natural width capped at NP_MAX_WIDTH
	var clip_w := minf(_np_label_width, NP_MAX_WIDTH)
	_np_overflow = maxf(_np_label_width - NP_MAX_WIDTH, 0.0)

	_np_clip.custom_minimum_size = Vector2(clip_w, _np_label.get_minimum_size().y)
	_np_clip.size                = _np_clip.custom_minimum_size

	# Force panel to reflow (it wraps _np_clip)
	_np_panel.reset_size()

	# Centre horizontally, 12 px from top
	var panel_w := _np_panel.get_minimum_size().x
	_np_panel.set_position(Vector2((vp_size.x - panel_w) * 0.5, NP_TOP_MARGIN))
	_np_panel.size = _np_panel.get_minimum_size()


func _process(delta: float) -> void:
	if not _np_visible or _np_overflow <= 0.0:
		return
	# Horizontal auto-scroll for long titles.
	if _np_scroll_pause > 0.0:
		_np_scroll_pause -= delta
		return
	_np_scroll_pos += _np_scroll_dir * NP_SCROLL_SPEED * delta
	if _np_scroll_pos <= -_np_overflow:
		_np_scroll_pos   = -_np_overflow
		_np_scroll_dir   = 1.0
		_np_scroll_pause = NP_SCROLL_PAUSE
	elif _np_scroll_pos >= 0.0:
		_np_scroll_pos   = 0.0
		_np_scroll_dir   = -1.0
		_np_scroll_pause = NP_SCROLL_PAUSE
	_np_label.position.x = _np_scroll_pos


# ── Button helpers ────────────────────────────────────────────────────────────

## Attach hover + click sounds and a visual highlight style to a button.
func setup_button(btn: Button,
		normal_color: Color = Color(0.18, 0.20, 0.28, 0.92),
		hover_color:  Color = Color(0.28, 0.35, 0.55, 0.97)) -> void:
	_apply_button_style(btn, normal_color, hover_color)
	btn.mouse_entered.connect(play_sfx_hover)
	btn.pressed.connect(play_sfx_click)


## Apply StyleBox overrides that give the button a clean dark rounded look.
func _apply_button_style(btn: Button, normal_color: Color, hover_color: Color) -> void:
	const R := 6
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = normal_color
	normal_sb.set_corner_radius_all(R)
	normal_sb.content_margin_left   = 12.0
	normal_sb.content_margin_right  = 12.0
	normal_sb.content_margin_top    = 8.0
	normal_sb.content_margin_bottom = 8.0

	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = hover_color
	hover_sb.set_corner_radius_all(R)
	hover_sb.border_width_left   = 2
	hover_sb.border_width_right  = 2
	hover_sb.border_width_top    = 2
	hover_sb.border_width_bottom = 2
	hover_sb.border_color        = Color(0.55, 0.75, 1.0, 0.85)
	hover_sb.content_margin_left   = 12.0
	hover_sb.content_margin_right  = 12.0
	hover_sb.content_margin_top    = 8.0
	hover_sb.content_margin_bottom = 8.0

	var pressed_sb := StyleBoxFlat.new()
	pressed_sb.bg_color = hover_color.darkened(0.15)
	pressed_sb.set_corner_radius_all(R)
	pressed_sb.content_margin_left   = 12.0
	pressed_sb.content_margin_right  = 12.0
	pressed_sb.content_margin_top    = 8.0
	pressed_sb.content_margin_bottom = 8.0

	btn.add_theme_stylebox_override("normal",  normal_sb)
	btn.add_theme_stylebox_override("hover",   hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus",   hover_sb)
