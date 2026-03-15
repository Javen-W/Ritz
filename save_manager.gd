extends Node

const SAVE_PATH    := "user://save_state.json"
const APP_VERSION  := "1.0"

var has_save: bool = false


func _ready() -> void:
	has_save = FileAccess.file_exists(SAVE_PATH)
	print("SaveManager: has_save=%s" % str(has_save))


func save_state(config: GameConfig, placements: Array) -> void:
	var data := {
		"version":    APP_VERSION,
		"config":     _config_to_dict(config),
		"placements": placements,
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
