# Remaining Improvement Tasks

This list was re-audited against the 2026-07-13 supervisor meeting and the final verified `447/447` core regression. Each item is an independent development and validation task.

| Order | Task | Why it matters | Completion gate |
| --- | --- | --- | --- |
| 1 | Blackboard Schema Editor | Completed | Typed CRUD, validation, policy, undo/redo, persistence, GUI and GPU tests pass |
| 2 | Shape/Icon Type Encoding | Completed | Independent switch, grayscale evidence, low-zoom identity and reset tests pass |
| 3 | Accessibility Improvements | Completed | Colorblind-safe palette, Ctrl+F/F3 navigation, tooltips and reset tests pass |
| 4 | Single Connection Rendering | Completed | One visible edge, custom hit testing, disconnect/undo/redo and GPU inspection pass |
| 5 | Runtime Profiling and Safe Cache Experiment | Completed | 511/511 assertions and 126 observations cover 31/121/364 nodes, 1/10/50 NPCs, and same-size topology invalidation |
| 6 | Reproducible Evaluation Material | Completed | Formula workbook, 21 screenshots, raw CSV, commands, formula scan and visual QA pass |
| 7 | Blackboard Reference Assistance | Completed | Typed Schema picker, free entry, strict validation, reference locations, and unused-key analysis |
| 8 | Distributable Plugin Package | Completed | Versioned ZIP, MIT license, SHA-256 manifest, 53/53 checks, and clean Godot 4.6 install |

## External Follow-up

- Recruit 8-15 participants and conduct the prepared 270-trial human comparison. No participant data currently exists.
- Prepare the Asset Library listing, final icon, and cross-version Godot compatibility matrix only after the graduation submission scope is stable; the standalone 0.9.0 package is complete.
- Service nodes remain intentionally out of scope unless the supervisor changes the requirement.

After every task, run its focused tests and all directly affected existing suites. After all eight tasks, run the complete project regression again because a later editor or runtime change can regress an earlier task.

## Measured Runtime Result

On the final 2026-08-09 Windows/Godot 4.6 regression, the safe topology cache reduced median tick latency by 15.98%-26.46% for 31 nodes, 52.61%-56.02% for 121 nodes, and 76.65%-78.00% for 364 nodes. Exact per-Tick topology validation intentionally trades some small-tree speed for correct same-size mutation invalidation. These fixed-workload measurements are not cross-device guarantees. Raw evidence is in `testgame/testgame/test_results/runtime_profile.csv` and `research/display_optimization/behavior_tree_unattended_run_evidence.xlsx`.
