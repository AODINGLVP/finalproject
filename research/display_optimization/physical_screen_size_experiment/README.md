# Physical Screen Size Experiment

This directory contains an append-only, real-GPU experiment for comparing the
behaviour-tree editor on physical displays of different sizes.

The primary factor is the EDID-reported physical display surface. Native
resolution, refresh rate, Windows scaling and GPU attachment are retained only
as audit metadata. They are not ranked and are not used as explanatory
variables in the primary analysis.

## Directory layout

- `PROTOCOL.md` freezes the experimental design and allowed claims.
- `capture_display_inventory.ps1` discovers connected displays and writes a
  session-specific `devices.csv`.
- `run_current_displays.ps1` runs the paired Godot experiment on every device
  in an inventory.
- `analyze_results.py` combines all completed device runs in one session.
- `data/<session>/devices.csv` records the physical hardware used.
- `data/<session>/runs/<device>/` contains raw CSV, summaries, screenshots and
  the unfiltered Godot log for one physical display.
- `data/<session>/combined_*.csv` and `report_zh.md` are regenerated analysis
  products.

When another monitor is connected, create a new session name instead of
overwriting an earlier session. This preserves a traceable history of physical
display measurements.

## Current protocol summary

- Physical canvas density: 35 logical units per centimetre in both axes.
- Resource sizes: 31, 61, 121, 241 and 364 nodes.
- Conditions: Baseline, Compact Cards, Optimized Overview, Optimized Search,
  Subtree Focus and Context Collapse.
- Per display: two unrecorded warm-ups and three measured repetitions.
- Primary evidence: viewport coverage, fit zoom, graph-to-screen area,
  target framing, context reduction, overlap safety and structural invariants.
- Timing is recorded for reproducibility but is not compared across displays.

See `PROTOCOL.md` before interpreting the results.
