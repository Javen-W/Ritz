extends RefCounted
class_name GameConfig

## Selects the algorithm used to assign dot values to tiles during generation.
enum DotSamplingMode { NOISE_RETENTION, NOISE_DIRECT }

# ── Core ──────────────────────────────────────────────────────────────────────
var seed: int = 777
var map_size: int = 30
var number_dominos: int = 10

# ── Tile path generation ──────────────────────────────────────────────────────
## Probability that the snake path branches from pos2 rather than pos1 each step.
## 0 = always extend from pos1 (straighter), 1 = always extend from pos2 (curvier).
var tile_path_branch_prob: float = 0.5

# ── Dot-value sampling ────────────────────────────────────────────────────────
var dot_sampling_mode: int = DotSamplingMode.NOISE_RETENTION

## NOISE_RETENTION only: noise values below this threshold trigger a new random
## dot value; above it the previous value is retained.  Lower = more retention
## (more equal adjacent tiles); higher = more variety.
var dot_change_threshold: float = 0.5

# ── FastNoiseLite parameters ──────────────────────────────────────────────────
var noise_frequency: float = 0.05
var noise_octaves: int = 3

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
