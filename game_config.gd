extends RefCounted
class_name GameConfig

enum SamplingAlgorithm { NOISE_RETENTION, NOISE_DIRECT }

# ── Core ──────────────────────────────────────────────────────────────────────
var seed: int = 777
var map_size: int = 30
var number_dominos: int = 10

# ── Dot-value sampling ────────────────────────────────────────────────────────
var sampling_algorithm: int = SamplingAlgorithm.NOISE_RETENTION

# ── FastNoiseLite parameters ──────────────────────────────────────────────────
var noise_frequency: float = 0.05
var noise_octaves: int = 3

# ── Constraint group sizing (normal distribution, then clamped) ───────────────
var constraint_group_mean: float = 2.5
var constraint_group_std: float = 1.5
var constraint_group_min: int = 1
var constraint_group_max: int = 6

# ── Constraint type probabilities ─────────────────────────────────────────────
# Each is evaluated in order when its eligibility condition holds.
# EQUAL:        applied when all tiles in group share the same generated value
# NOT_EQUAL:    applied when all tiles differ
# LESS_THAN:    applied when group_sum <= 10
# GREATER_THAN: applied when group_sum > 0
# Else:         SUM constraint (exact target)
var prob_equal: float = 0.85
var prob_not_equal: float = 0.15
var prob_less_than: float = 0.10
var prob_greater_than: float = 0.10
