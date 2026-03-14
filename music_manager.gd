extends Node

## MusicManager – autoload that handles background music and UI sound effects.
## Background music uses an AudioStreamGenerator so no audio asset files are required.
## SFX use short pre-generated WAV blobs (beep tones).

const SAMPLE_RATE := 44100.0

# BGM
var _bgm_player: AudioStreamPlayer
var _bgm_gen: AudioStreamGenerator
var _bgm_time: float = 0.0
var _bgm_playing: bool = false

# SFX players
var _sfx_hover_player: AudioStreamPlayer
var _sfx_click_player: AudioStreamPlayer

# Volume settings (dB)
var bgm_volume_db: float = -14.0
var sfx_volume_db: float = -4.0

# Simple 2-oscillator ambient BGM (drone)
const BGM_FREQ_A: float = 110.0   # A2
const BGM_FREQ_B: float = 165.0   # E3 (perfect fifth above A2)
const BGM_FREQ_C: float = 130.81  # C3 (gentle minor third)


func _ready() -> void:
	_setup_bgm()
	_setup_sfx()
	play_bgm()


func _setup_bgm() -> void:
	_bgm_gen = AudioStreamGenerator.new()
	_bgm_gen.mix_rate = SAMPLE_RATE
	_bgm_gen.buffer_length = 0.2

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream = _bgm_gen
	_bgm_player.volume_db = bgm_volume_db
	_bgm_player.bus = "Master"
	add_child(_bgm_player)


func _setup_sfx() -> void:
	_sfx_hover_player = AudioStreamPlayer.new()
	_sfx_hover_player.volume_db = sfx_volume_db
	_sfx_hover_player.stream = _make_beep_wav(880.0, 0.06)  # brief high beep
	add_child(_sfx_hover_player)

	_sfx_click_player = AudioStreamPlayer.new()
	_sfx_click_player.volume_db = sfx_volume_db
	_sfx_click_player.stream = _make_beep_wav(440.0, 0.10)  # slightly lower click
	add_child(_sfx_click_player)


## Generate a short sine-wave beep as an AudioStreamWAV.
func _make_beep_wav(freq: float, duration: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env := 1.0 - float(i) / float(n)           # linear fade-out
		var v := int(16000.0 * sin(TAU * freq * t) * env)
		v = clampi(v, -32768, 32767)
		data[i * 2]     = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.stereo = false
	wav.data = data
	return wav


func _process(_delta: float) -> void:
	if _bgm_playing:
		_fill_bgm_buffer()


## Fill the BGM generator buffer with ambient drone samples.
func _fill_bgm_buffer() -> void:
	var pb := _bgm_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var avail := pb.get_frames_available()
	var step := 1.0 / SAMPLE_RATE
	for _i in range(avail):
		# Blend three sine oscillators with slight detuning for warmth.
		var s := (sin(TAU * BGM_FREQ_A * _bgm_time) * 0.15
				+ sin(TAU * BGM_FREQ_B * _bgm_time + 0.12) * 0.10
				+ sin(TAU * BGM_FREQ_C * _bgm_time + 0.55) * 0.08
				+ sin(TAU * BGM_FREQ_A * 2.0 * _bgm_time) * 0.04)
		pb.push_frame(Vector2(s, s))
		_bgm_time += step


## Play background music (idempotent).
func play_bgm() -> void:
	if not _bgm_playing:
		_bgm_player.play()
		_bgm_playing = true
		print("MusicManager: BGM started")


## Pause background music.
func stop_bgm() -> void:
	if _bgm_playing:
		_bgm_player.stop()
		_bgm_playing = false


func set_bgm_volume(db: float) -> void:
	bgm_volume_db = db
	_bgm_player.volume_db = db


func set_sfx_volume(db: float) -> void:
	sfx_volume_db = db
	_sfx_hover_player.volume_db = db
	_sfx_click_player.volume_db = db


func play_sfx_hover() -> void:
	if _sfx_hover_player and _sfx_hover_player.stream:
		_sfx_hover_player.play()


func play_sfx_click() -> void:
	if _sfx_click_player and _sfx_click_player.stream:
		_sfx_click_player.play()


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
	normal_sb.content_margin_left  = 12.0
	normal_sb.content_margin_right = 12.0
	normal_sb.content_margin_top   = 8.0
	normal_sb.content_margin_bottom = 8.0

	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = hover_color
	hover_sb.set_corner_radius_all(R)
	hover_sb.border_width_left   = 2
	hover_sb.border_width_right  = 2
	hover_sb.border_width_top    = 2
	hover_sb.border_width_bottom = 2
	hover_sb.border_color = Color(0.55, 0.75, 1.0, 0.85)
	hover_sb.content_margin_left  = 12.0
	hover_sb.content_margin_right = 12.0
	hover_sb.content_margin_top   = 8.0
	hover_sb.content_margin_bottom = 8.0

	var pressed_sb := StyleBoxFlat.new()
	pressed_sb.bg_color = hover_color.darkened(0.15)
	pressed_sb.set_corner_radius_all(R)
	pressed_sb.content_margin_left  = 12.0
	pressed_sb.content_margin_right = 12.0
	pressed_sb.content_margin_top   = 8.0
	pressed_sb.content_margin_bottom = 8.0

	btn.add_theme_stylebox_override("normal",   normal_sb)
	btn.add_theme_stylebox_override("hover",    hover_sb)
	btn.add_theme_stylebox_override("pressed",  pressed_sb)
	btn.add_theme_stylebox_override("focus",    hover_sb)
