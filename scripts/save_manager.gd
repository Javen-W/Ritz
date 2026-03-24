extends Node

const SAVE_PATH    := "user://save_state.json"
const OPTIONS_PATH := "user://options.json"
const APP_VERSION  := "1.0"

# Available resolutions — single source of truth; OptionsMenu references SaveManager.RESOLUTIONS.
const RESOLUTIONS: Array = [[1280, 720], [1600, 900], [1920, 1080], [2560, 1440]]

var has_save: bool = false


func _ready() -> void:
	has_save = FileAccess.file_exists(SAVE_PATH)
	print("SaveManager: has_save=%s" % str(has_save))
	_apply_saved_display_settings()


func save_state(config: GameConfig, placements: Array, elapsed_time: float = 0.0) -> void:
	var data := {
		"version":      APP_VERSION,
		"config":       _config_to_dict(config),
		"placements":   placements,
		"elapsed_time": elapsed_time,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		has_save = true
		print("SaveManager: State saved (%d placements)" % placements.size())
	else:
		push_error("SaveManager: Failed to write save file (error %d)" % FileAccess.get_open_error())


func load_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var result = JSON.parse_string(text)
	if result == null or not result is Dictionary:
		push_warning("SaveManager: Failed to parse save file — discarding")
		clear_save()
		return {}
	var data := result as Dictionary
	# Version check: discard saves from incompatible versions
	if data.get("version", "") != APP_VERSION:
		push_warning("SaveManager: Save version '%s' != '%s' — discarding" % [
			data.get("version", "?"), APP_VERSION])
		clear_save()
		return {}
	# Require both config and placements keys
	if not data.has("config") or not data.has("placements"):
		var missing := ([] as Array)
		if not data.has("config"):    missing.append("config")
		if not data.has("placements"): missing.append("placements")
		push_warning("SaveManager: Save missing required fields [%s] — discarding" % ", ".join(missing))
		clear_save()
		return {}
	return data


func load_config() -> GameConfig:
	var data := load_state()
	if data.is_empty() or not data.has("config"):
		return null
	return _dict_to_config(data["config"] as Dictionary)


func load_placements() -> Array:
	var data := load_state()
	if data.is_empty() or not data.has("placements"):
		return []
	return data["placements"] as Array


func load_elapsed_time() -> float:
	var data := load_state()
	if data.is_empty():
		return 0.0
	return float(data.get("elapsed_time", 0.0))


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			var err := dir.remove("save_state.json")
			if err != OK:
				push_error("SaveManager: Failed to remove save file (error %d)" % err)
				return
	has_save = false
	print("SaveManager: Save state cleared")


func _config_to_dict(cfg: GameConfig) -> Dictionary:
	return {
		"seed":                     cfg.seed,
		"map_size":                 cfg.map_size,
		"number_dominos":           cfg.number_dominos,
		"dot_sampling_algorithm":   cfg.dot_sampling_algorithm,
		"tile_path_branch_prob":    cfg.tile_path_branch_prob,
		"p_equal_tile":             cfg.p_equal_tile,
		"noise_type":               cfg.noise_type,
		"noise_frequency":          cfg.noise_frequency,
		"noise_octaves":            cfg.noise_octaves,
		"fractal_type":             cfg.fractal_type,
		"fractal_lacunarity":       cfg.fractal_lacunarity,
		"fractal_gain":             cfg.fractal_gain,
		"constraint_group_mean":    cfg.constraint_group_mean,
		"constraint_group_std":     cfg.constraint_group_std,
		"constraint_group_min":     cfg.constraint_group_min,
		"constraint_group_max":     cfg.constraint_group_max,
		"constraint_skip_prob":     cfg.constraint_skip_prob,
		"constraint_skip_max_size": cfg.constraint_skip_max_size,
		"prob_equal":               cfg.prob_equal,
		"prob_not_equal":           cfg.prob_not_equal,
		"prob_less_than":           cfg.prob_less_than,
		"prob_greater_than":        cfg.prob_greater_than,
	}


func _dict_to_config(d: Dictionary) -> GameConfig:
	var cfg := GameConfig.new()
	cfg.seed                   = int(d.get("seed",                   777))
	cfg.map_size               = int(d.get("map_size",               30))
	cfg.number_dominos         = int(d.get("number_dominos",         10))
	cfg.dot_sampling_algorithm = int(d.get("dot_sampling_algorithm", 0))
	cfg.tile_path_branch_prob  = float(d.get("tile_path_branch_prob",  0.5))
	cfg.p_equal_tile           = float(d.get("p_equal_tile",           0.5))
	cfg.noise_type             = int(d.get("noise_type",             FastNoiseLite.TYPE_SIMPLEX_SMOOTH))
	cfg.noise_frequency        = float(d.get("noise_frequency",        0.05))
	cfg.noise_octaves          = int(d.get("noise_octaves",          3))
	cfg.fractal_type           = int(d.get("fractal_type",           FastNoiseLite.FRACTAL_FBM))
	cfg.fractal_lacunarity     = float(d.get("fractal_lacunarity",     2.0))
	cfg.fractal_gain           = float(d.get("fractal_gain",           0.5))
	cfg.constraint_group_mean  = float(d.get("constraint_group_mean",  2.5))
	cfg.constraint_group_std   = float(d.get("constraint_group_std",   1.5))
	cfg.constraint_group_min   = int(d.get("constraint_group_min",   1))
	cfg.constraint_group_max   = int(d.get("constraint_group_max",   6))
	cfg.constraint_skip_prob   = float(d.get("constraint_skip_prob",   0.25))
	cfg.constraint_skip_max_size = int(d.get("constraint_skip_max_size", 1))
	cfg.prob_equal             = float(d.get("prob_equal",             0.30))
	cfg.prob_not_equal         = float(d.get("prob_not_equal",         0.15))
	cfg.prob_less_than         = float(d.get("prob_less_than",         0.10))
	cfg.prob_greater_than      = float(d.get("prob_greater_than",      0.10))
	return cfg


# ── Options persistence ───────────────────────────────────────────────────────

func save_options(opts: Dictionary) -> void:
	var file := FileAccess.open(OPTIONS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(opts))
		file.close()
	else:
		push_error("SaveManager: Failed to write options file (error %d)" % FileAccess.get_open_error())


func load_options() -> Dictionary:
	if not FileAccess.file_exists(OPTIONS_PATH):
		return {}
	var file := FileAccess.open(OPTIONS_PATH, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var result = JSON.parse_string(text)
	if result == null or not result is Dictionary:
		return {}
	return result as Dictionary


## Apply saved display / render settings early (called from _ready).
## Audio settings are applied by MusicManager which runs immediately after.
## Skipped when running in the Godot editor's embedded player (window APIs unsupported).
func _apply_saved_display_settings() -> void:
	var opts := load_options()
	if opts.is_empty():
		return
	# Window management APIs are not supported in the editor's embedded player.
	if not OS.has_feature("editor"):
		# Fullscreen
		if bool(opts.get("fullscreen", false)):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		# VSync
		var vsync_mode := DisplayServer.VSYNC_ENABLED if bool(opts.get("vsync", true)) else DisplayServer.VSYNC_DISABLED
		DisplayServer.window_set_vsync_mode(vsync_mode)
		# Resolution (only in windowed mode)
		if not bool(opts.get("fullscreen", false)):
			var res_idx := int(opts.get("resolution_idx", 0))
			if res_idx >= 0 and res_idx < RESOLUTIONS.size():
				var res: Array = RESOLUTIONS[res_idx]
				DisplayServer.window_set_size(Vector2i(res[0], res[1]))
	# MSAA works in all modes — deferred so the root viewport is fully initialized
	var msaa_idx := int(opts.get("msaa", 0))
	call_deferred("_apply_msaa", msaa_idx)


func _apply_msaa(idx: int) -> void:
	var levels := [
		Viewport.MSAA_DISABLED,
		Viewport.MSAA_2X,
		Viewport.MSAA_4X,
		Viewport.MSAA_8X,
	]
	if idx >= 0 and idx < levels.size():
		get_viewport().msaa_2d = levels[idx]
		print("SaveManager: MSAA restored → index %d" % idx)
