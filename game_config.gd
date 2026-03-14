extends RefCounted
class_name GameConfig

## Selects the algorithm used to sample a NEW dot value (used when the equal-tile
## roll fails).  DOT_SAMPLE_1 = pure random; DOT_SAMPLE_2 = noise-mapped.
enum DotSamplingAlgorithm { DOT_SAMPLE_1, DOT_SAMPLE_2 }

# ── Core ──────────────────────────────────────────────────────────────────────
var seed: int = 777
var map_size: int = 30
var number_dominos: int = 10

# ── Tile path generation ──────────────────────────────────────────────────────
## Probability that the snake path branches from pos2 rather than pos1 each step.
var tile_path_branch_prob: float = 0.5

# ── Dot-value sampling ────────────────────────────────────────────────────────
var dot_sampling_algorithm: int = DotSamplingAlgorithm.DOT_SAMPLE_1

## Probability that a tile retains the previous tile's dot value (equal adjacent
## tiles).  Applied independently via rng.randf() before the sampling algorithm.
var p_equal_tile: float = 0.5

# ── FastNoiseLite parameters ──────────────────────────────────────────────────
var noise_type: int          = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
var noise_frequency: float   = 0.05
var noise_octaves: int       = 3
var fractal_type: int        = FastNoiseLite.FRACTAL_FBM
var fractal_lacunarity: float = 2.0
var fractal_gain: float      = 0.5

# ── Constraint group sizing (normal distribution, then clamped) ───────────────
var constraint_group_mean: float = 2.5
var constraint_group_std: float = 1.5
var constraint_group_min: int = 1
var constraint_group_max: int = 6

## Groups of size <= constraint_skip_max_size are skipped with this probability.
var constraint_skip_prob: float = 0.25
var constraint_skip_max_size: int = 1

# ── Constraint type probabilities ─────────────────────────────────────────────
# Evaluated in priority order; all are purely probability-based.
# EQUAL:        group.size() > 1 and rng.randf() < prob_equal
# NOT_EQUAL:    group.size() > 1 and all generated values differ and rng.randf() < prob_not_equal
# LESS_THAN:    group_sum <= 10 and rng.randf() < prob_less_than
# GREATER_THAN: group_sum > 0   and rng.randf() < prob_greater_than
# Else:         SUM (exact target)
var prob_equal: float = 0.30
var prob_not_equal: float = 0.15
var prob_less_than: float = 0.10
var prob_greater_than: float = 0.10
