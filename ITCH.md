# Ritz — itch.io Publication Info

Copy and paste each section into the corresponding field on the itch.io project page.

---

## 1. Short Description (Tagline)

> A procedural domino puzzle where every board is different and every placement counts.

---

## 2. Description

**Ritz** is a single-player logic puzzle game that fuses the classic feel of dominoes with constraint-satisfaction brain teasers — and generates a completely fresh board every time you play.

---

### How It Works

A grid of tiles is procedurally laid out across the board. Each tile shows a pip value between **0 and 6**, just like a real domino face. Pairs of adjacent tiles are bonded together into dominoes, and groups of tiles on the board are marked with **mathematical constraints** — rules that must hold true when the board is complete.

Your job: drag every domino from the side panel and drop it onto its matching pair of tiles on the board. The domino locks in when the pip values on both halves match the tiles underneath. **Every constraint must be satisfied at the same time for you to win.**

---

### Constraints

Coloured overlays highlight constraint groups on the board. A small badge at the corner of each group tells you the rule that applies:

| Badge | Rule |
|-------|------|
| `12`  | **SUM** — tiles in this group must add up to exactly 12 |
| `=`   | **EQUAL** — all tiles must share the same value |
| `!=`  | **NOT EQUAL** — no two tiles may share the same value |
| `<15` | **LESS THAN** — total must be less than 15 |
| `>3`  | **GREATER THAN** — total must be greater than 3 |

Constraints are generated from the actual tile values, so **every puzzle is always solvable** — but finding the arrangement that satisfies all constraints at once is the challenge.

---

### Controls

| Action | Input |
|--------|-------|
| Pick up / drag a domino | Click and drag |
| Rotate a domino | Double-click |
| Pan the camera | Arrow keys |
| Reset camera | Space |
| Reset all dominoes | Reset button (HUD) |
| Return to main menu | Escape |

---

### Features

- 🎲 **Fully procedural** — tile layout, pip values, domino pairings, and constraints are all generated from a seed, giving you a unique puzzle every time.
- 🧩 **Five constraint types** — SUM, EQUAL, NOT EQUAL, LESS THAN, and GREATER THAN keep every board feeling different.
- 💾 **Auto-save & resume** — progress is saved automatically after every placement. Pick up exactly where you left off, including your elapsed time.
- ⚙️ **Generation panel** — tweak the seed, grid size, domino count, noise parameters, and constraint probabilities at runtime to craft your own challenge.
- 🎬 **Animated board generation** — watch the board build itself tile by tile when a new game starts.
- 🖥️ **Resolution & display options** — choose from preset resolutions (1280×720 to 2560×1440), toggle fullscreen, and control V-Sync and music volume.

---

### About

Ritz was built with **Godot 4.5** (GDScript, GL Compatibility renderer). The pip patterns on dominoes are rendered entirely on the GPU via a custom GLSL shader — no sprite atlas required.

---

## 3. Tags

```
puzzle, domino, logic-puzzle, procedural-generation, constraint-satisfaction, singleplayer, godot, relaxing, brain-teaser, math
```
