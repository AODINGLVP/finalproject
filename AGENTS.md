# Project Guidance for Coding Agents

## Project Purpose

This repository is a graduation project: a Godot 4.6 visual behavior-tree editor plugin with a runtime system that can drive 2D NPC behavior.

The active Godot project is:

```text
testgame/testgame
```

The distributable plugin template is:

```text
visual_scripting/addons/behavior_tree_editor
```

Changes to the active plugin must be synchronized to the matching files in the distributable template.

## Supervisor Meeting Requirements

The source meeting transcript is stored locally at `contact/7.13.docx`. The `contact` directory is intentionally ignored by Git, so the durable requirements are summarized here.

The supervisor's explicit direction from the 2026-07-13 meeting was:

1. Complete the basic behavior-tree system before expanding the game demo.
2. Support enough node behavior to make real decisions, including sequences, selectors, loops, random choices, and parallel execution.
3. Keep the project focused on behavior trees rather than spending excessive time on character art or animation.
4. Improve the editor or runtime in a way that is meaningfully different from existing systems such as Unreal Engine's behavior-tree editor.
5. Address the large-graph readability problem. The supervisor specifically discussed trees with more than about 50 nodes becoming difficult to fit on screen and understand.
6. Investigate focus-and-context techniques similar to the macOS Dock, where the node near the pointer becomes larger while surrounding nodes remain compact.
7. Consider subtree expand/collapse, compact boxes, color, shape, and alternative layouts as visual encodings.
8. Find research papers about tree editors, visual programming, and readable interfaces for large graphs.
9. Evaluate the chosen improvement quantitatively. Build comparisons and measure whether the new method is actually better.
10. Maintain a sufficiently complex demo to prove that NPC behavior is genuinely controlled by the behavior-tree runtime.

The supervisor presented editor usability, runtime/API efficiency, and cache-aware execution as possible innovation directions. The current project has chosen large-tree editor usability as its main innovation direction.

## Current Implemented State

The project currently includes:

- Visual creation, deletion, connection, disconnection, drag movement, context menus, undo, and redo.
- `.tres` behavior-tree resource save/load and structural validation.
- `Root`, `Sequence`, `Selector`, `Random Selector`, `Parallel`, `Repeat`, `Action`, `Condition`, `Wait`, and `Decorator` resources.
- Left-to-right child execution order based on horizontal node position.
- Runtime `SUCCESS`, `FAILURE`, and `RUNNING` semantics with composite execution memory.
- Actor method calls from Action and Condition nodes.
- Dictionary blackboard data and comparison operators.
- Blackboard, cooldown, time-limit, invert, force-result, and repeat Decorator behavior.
- Live Debug active-path highlighting, inactive-branch dimming, and failure annotations inside the Godot editor.
- Compact cards, semantic zoom, fisheye, subtree collapse/focus, search, minimap, fit-to-view, breadcrumbs, multi-column layout, stable layout, orthogonal edges, and edge bundling.
- A basic test game and a more complex arena covering patrol, detection, chase, directional attacks, last-known-position search, retreat, healing, pickups, and hazards.

Latest verified automated results:

| Suite | Result |
| --- | ---: |
| Runtime and resource tests | 153/153 |
| Editor GUI tests | 250/250 |
| Basic game integration | 13/13 |
| Complex arena integration | 34/34 |
| Real GPU visual regression | 124/124 |
| Total core automated assertions | 574/574 |

Additional verified suites: human-study material validation `91/91`, human-study GPU visual `22/22`, runtime profile `511/511`, package validation `53/53`, 180 playable-tree display observations, and 126 raw runtime timing observations.

The final report is generated from the current CSV baseline. It records 17 core and 4 controlled-study real GPU screenshots, fisheye maximum `1.20x`, and enhanced minimap size `230x150`.

Second-phase verified additions:

- Blackboard Schema key picker, strict reference validation, reference locations, and unused-key analysis.
- Exact per-Tick topology signatures covering same-size reorder, parent, Decorator ownership, and node-instance changes.
- Version `0.9.0` distributable ZIP with MIT license, SHA-256 manifest, and clean-install validation.

## Development Task Table

Tasks are ordered by recommended graduation-project priority. Do not start lower-priority visual experiments before the missing core behavior-tree nodes and report consistency are addressed.

| Priority | Task | Current state | Agent can implement | Acceptance criteria |
| --- | --- | --- | --- | --- |
| P0 | Add `Parallel` composite | Completed and verified | Yes | Editor creation, resource validation, runtime policies, RUNNING memory, interruption/reset behavior, unit tests, and demo usage all pass |
| P0 | Add `Random Selector` composite | Completed and verified | Yes | Seedable/deterministic tests, runtime selection memory, editor support, save/load, and example tree pass |
| P0 | Add explicit `Loop/Repeat` node | Completed and verified | Yes | Counted and infinite repeat modes work as a first-class node; RUNNING/reset tests pass |
| P0 | Add `Wait` task | Completed and verified | Yes | Duration parameter, elapsed-time memory, restart/reset, save/load, editor configuration, and runtime tests pass |
| P0 | Regenerate reports and benchmark data | Completed and verified | Yes | Markdown, DOCX, PDF, Excel, and raw CSV agree with current code and verified test totals |
| P1 | Replace raw parameter JSON with typed controls | Completed and verified | Yes | Action method, Condition mode/key/operator/value, Decorator mode, duration, and node-specific fields can be edited without hand-written JSON |
| P1 | Add blackboard schema resource | Completed and verified | Yes | Typed keys, defaults, validation, tree binding, and persistence work without breaking existing trees |
| P1 | Add Live Debug blackboard panel | Completed and verified | Yes | Editor shows current values and types for the selected actor without adding an in-game overlay |
| P1 | Expand the demonstration behavior tree | Completed and verified | Yes | Demo exercises Parallel, random choice, Wait, repeat, blackboard checks, Decorators, and Action calls |
| P1 | Run a human comparison study | Protocol/template complete; participants pending | Partly | Playable 241-node tree, Live Debug fixture, protocol, counterbalancing, 216-row workbook, analysis pipeline, and visual tests are ready; user recruits 12 participants before analysis |
| P1 | Add reproducible screenshots/video script | Screenshot suite completed | Yes | Fixed 121/364-node trees, target Action/Decorator, search framing, and deterministic Live Debug path pass real GPU tests |
| P2 | Add shape/icon type encoding | Completed and verified | Yes | Independent switch, grayscale evidence and low-zoom identity pass |
| P2 | Remove the faint native GraphEdit helper edge | Completed and verified | Yes | Custom hit-testing preserves disconnect/undo/redo while one persistent edge is visible |
| P2 | Add runtime profiling and cache-aware execution experiment | Completed and verified | Yes | 126 observations cover fixed sizes and 1/10/50 NPC scaling; cache is switchable |
| P2 | Improve accessibility | Completed and verified | Yes | Colorblind-safe palette, keyboard search/navigation and tooltip coverage pass |

## Completed Work Order and Next Steps

The planned implementation sequence is complete: `Parallel`, `Random Selector`, `Repeat`, `Wait`, the complex demonstration tree, typed Inspector controls, Blackboard Schema/debug UI, complete automated and visual regression, benchmark regeneration, report generation, and clean-package validation have all passed their acceptance gates.

The remaining work depends on external input or release decisions:

1. Recruit 12 participants, conduct the prepared 216-trial human comparison study, and add real results to the dissertation. The protocol, workbook and analysis pipeline are complete; do not fabricate data.
2. Prepare the Godot Asset Library listing and final icon if public distribution is required.
3. Run a cross-version compatibility matrix only after the target Godot versions are selected and installed.

Service nodes are not required unless the user or supervisor explicitly changes the scope. Do not attempt to reproduce every Unreal Engine feature.

## Evaluation Plan

The editor innovation should be evaluated with both automated and human evidence.

Automated measurements should use fixed 31-, 121-, and 364-node trees and report:

- Visible node count and ratio.
- Card area and information-field reduction.
- Rebuild or switch latency.
- Search dimming count.
- Fisheye magnification and overlap count.
- Minimap coverage.
- Zero node-card overlaps and minimum parent-child spacing.

The human study should compare at least Baseline, Compact, Collapse, Fisheye, Search, and Minimap. Suggested tasks are locating an Action, identifying the active runtime path, and editing a Decorator. Record completion time, incorrect selections, zoom/pan count, and subjective readability/cognitive-load ratings.

Do not claim that reduced area automatically proves improved readability. Separate automated geometric results from human usability conclusions.

## Validation Commands

Run commands from the repository root. Treat nonzero exit codes, `ERROR:`, `SCRIPT ERROR:`, `FAIL:`, native crash traces, and leaks as failures even when the assertion summary looks successful.

```powershell
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_behavior_tree_tests.gd
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_editor_view_tests.gd
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_game_integration_tests.gd
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_complex_arena_tests.gd
./Godot_v4.6-stable_win64_console.exe --rendering-method gl_compatibility --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_arena_smoke_test.gd
./Godot_v4.6-stable_win64_console.exe --rendering-method gl_compatibility --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_visual_regression_tests.gd
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --editor --quit-after 10
```

Visual regression must use a real rendering method, not `--headless`, because the Dummy renderer cannot read SubViewport textures.

## Repository Rules

- The plugin UI must remain English. Chinese is acceptable in dissertation and internal documentation.
- Use Godot 4.6-compatible GDScript and respect strict type inference.
- Keep the active plugin and `visual_scripting` template synchronized.
- Preserve left-to-right execution ordering for Sequence and other ordered composites.
- Every new node requires editor, resource validation, runtime, save/load, and automated test coverage.
- Every display optimization requires an independent switch and safe disable/reset behavior.
- Perform real visual inspection for graph-display changes; assertions alone are insufficient.
- Do not add a behavior-tree overlay to the running game. Runtime state belongs in the Godot editor plugin.
- Do not modify or delete `research/OIP.webp` unless explicitly requested.
- Do not revert unrelated dirty-worktree changes.
- Do not commit or push unless the user explicitly requests it.

## Dissertation Writing Rules

Before editing any dissertation content, read `docs/DISSERTATION_REQUIREMENTS.md` in full. It records the requirements extracted from the user-supplied University of Warwick template and the complete MSc Games Engineering dissertation workshop in `E:\course pdf\project\格式`. Dissertation structure, layout, evidence claims, tables, figures, citations and final checks must follow that document. Do not claim human-readability improvement from geometric or timing proxies, and never fabricate participant results.

## Git State

This repository is already initialized locally.

```text
Branch: main
Remote: origin -> https://github.com/AODINGLVP/finalproject.git
Latest known commit when this file was created: 59ae467 Fix behavior tree decorator display
```

The worktree contains substantial uncommitted project work. Inspect `git status` before editing and never discard changes that were not made for the current task.
