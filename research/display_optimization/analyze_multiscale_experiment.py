#!/usr/bin/env python3
"""Aggregate the controlled multiscale display and versioned drag experiments."""

from __future__ import annotations

import csv
import hashlib
import json
import math
import random
import statistics
import subprocess
from collections import defaultdict
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[2]
RESULTS = ROOT / "testgame" / "testgame" / "test_results"
REPORT_DIR = ROOT / "research" / "display_optimization"
TREE_SIZES = (31, 61, 121, 241, 364)
BOOTSTRAP_REPETITIONS = 10_000
BOOTSTRAP_SEED = 20_260_822
BEFORE_PLUGIN_COMMIT = "5d914ae"
OPTIMIZATION_COMMIT = "92fb21d"

DRAG_INPUTS = (
    RESULTS / "multiscale_drag_before_block1.csv",
    RESULTS / "multiscale_drag_optimized_block1.csv",
    RESULTS / "multiscale_drag_optimized_block2.csv",
    RESULTS / "multiscale_drag_before_block2.csv",
)
DISPLAY_RAW = RESULTS / "multiscale_display_raw.csv"
DISPLAY_SUMMARY = RESULTS / "multiscale_display_summary.csv"
DISPLAY_TRENDS = RESULTS / "multiscale_display_trends.csv"
PLAYABLE_SUMMARY = RESULTS / "complex_display_experiment_summary.csv"

DRAG_RAW_OUTPUT = RESULTS / "multiscale_drag_raw.csv"
DRAG_SUMMARY_OUTPUT = RESULTS / "multiscale_drag_summary.csv"
MANIFEST_OUTPUT = RESULTS / "multiscale_experiment_manifest.json"
REPORT_OUTPUT = REPORT_DIR / "multiscale_experiment_results.md"


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise FileNotFoundError(path)
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def nearest_rank(values: Iterable[float], proportion: float) -> float:
    ordered = sorted(values)
    if not ordered:
        raise ValueError("Cannot calculate a percentile for an empty sample")
    index = max(0, min(len(ordered) - 1, math.ceil(proportion * len(ordered)) - 1))
    return ordered[index]


def bootstrap_median_reduction(
    before: list[float], optimized: list[float], seed: int
) -> tuple[float, float]:
    rng = random.Random(seed)
    estimates: list[float] = []
    for _ in range(BOOTSTRAP_REPETITIONS):
        before_median = statistics.median(rng.choices(before, k=len(before)))
        optimized_median = statistics.median(rng.choices(optimized, k=len(optimized)))
        estimates.append((1.0 - optimized_median / before_median) * 100.0)
    return nearest_rank(estimates, 0.025), nearest_rank(estimates, 0.975)


def as_bool(value: str) -> bool:
    return value.strip().lower() == "true"


def number(value: str) -> float:
    return float(value)


def format_number(value: float, digits: int = 2) -> str:
    return f"{value:,.{digits}f}"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def git_output(*arguments: str) -> str:
    return subprocess.check_output(
        ["git", *arguments], cwd=ROOT, text=True, encoding="utf-8"
    ).strip()


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def load_and_validate_drag_rows() -> list[dict[str, str]]:
    combined: list[dict[str, str]] = []
    expected_versions = ("Before", "Optimized", "Optimized", "Before")
    expected_blocks = ("1", "1", "2", "2")
    for sequence_index, (path, expected_version, expected_block) in enumerate(
        zip(DRAG_INPUTS, expected_versions, expected_blocks), start=1
    ):
        rows = read_rows(path)
        if len(rows) != 50:
            raise ValueError(f"{path.name}: expected 50 rows, found {len(rows)}")
        if {row["version"] for row in rows} != {expected_version}:
            raise ValueError(f"{path.name}: unexpected version label")
        if {row["block"] for row in rows} != {expected_block}:
            raise ValueError(f"{path.name}: unexpected block label")
        if {int(row["tree_size"]) for row in rows} != set(TREE_SIZES):
            raise ValueError(f"{path.name}: incomplete tree-size set")
        for row in rows:
            if not as_bool(row["resource_synced"]):
                raise ValueError(f"{path.name}: final resource position was not synchronized")
            if not as_bool(row["order_preserved"]):
                raise ValueError(f"{path.name}: execution order changed during dragging")
            if number(row["moved_distance"]) <= 150.0:
                raise ValueError(f"{path.name}: drag distance did not reach the threshold")
            enriched = dict(row)
            enriched["source_file"] = path.name
            enriched["abba_sequence"] = str(sequence_index)
            combined.append(enriched)
    if len(combined) != 200:
        raise ValueError(f"Expected 200 drag observations, found {len(combined)}")
    return combined


def summarize_drag(rows: list[dict[str, str]]) -> list[dict[str, object]]:
    grouped: dict[tuple[int, str], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[(int(row["tree_size"]), row["version"])].append(row)

    summary: list[dict[str, object]] = []
    for tree_size in TREE_SIZES:
        before_rows = grouped[(tree_size, "Before")]
        optimized_rows = grouped[(tree_size, "Optimized")]
        if len(before_rows) != 20 or len(optimized_rows) != 20:
            raise ValueError(f"{tree_size}: expected 20 observations per version")
        before = [number(row["total_ms"]) for row in before_rows]
        optimized = [number(row["total_ms"]) for row in optimized_rows]
        before_median = statistics.median(before)
        optimized_median = statistics.median(optimized)
        reduction = (1.0 - optimized_median / before_median) * 100.0
        ci_low, ci_high = bootstrap_median_reduction(
            before, optimized, BOOTSTRAP_SEED + tree_size
        )
        before_blocks = {
            block: statistics.median(
                number(row["total_ms"]) for row in before_rows if row["block"] == block
            )
            for block in ("1", "2")
        }
        optimized_blocks = {
            block: statistics.median(
                number(row["total_ms"])
                for row in optimized_rows
                if row["block"] == block
            )
            for block in ("1", "2")
        }
        summary.append(
            {
                "tree_size": tree_size,
                "rendered_cards": int(before_rows[0]["rendered_cards"]),
                "decorators": int(before_rows[0]["decorators"]),
                "n_before": len(before),
                "n_optimized": len(optimized),
                "before_median_ms": before_median,
                "before_q1_ms": nearest_rank(before, 0.25),
                "before_q3_ms": nearest_rank(before, 0.75),
                "before_p95_ms": nearest_rank(before, 0.95),
                "optimized_median_ms": optimized_median,
                "optimized_q1_ms": nearest_rank(optimized, 0.25),
                "optimized_q3_ms": nearest_rank(optimized, 0.75),
                "optimized_p95_ms": nearest_rank(optimized, 0.95),
                "median_reduction_percent": reduction,
                "bootstrap_ci_low_percent": ci_low,
                "bootstrap_ci_high_percent": ci_high,
                "before_median_ms_per_step": before_median / 240.0,
                "optimized_median_ms_per_step": optimized_median / 240.0,
                "before_block1_median_ms": before_blocks["1"],
                "before_block2_median_ms": before_blocks["2"],
                "optimized_block1_median_ms": optimized_blocks["1"],
                "optimized_block2_median_ms": optimized_blocks["2"],
                "resource_sync_pass_rate_percent": 100.0,
                "order_preservation_pass_rate_percent": 100.0,
            }
        )
    return summary


def report_markdown(
    drag_summary: list[dict[str, object]],
    display_trends: list[dict[str, str]],
    playable: list[dict[str, str]],
    engine: str,
    renderer: str,
    gpu: str,
) -> str:
    positive_sizes = sum(
        float(row["median_reduction_percent"]) > 0.0 for row in drag_summary
    )
    no_major_regression = all(
        float(row["median_reduction_percent"]) >= -5.0 for row in drag_summary
    )
    acceptance = positive_sizes >= 4 and no_major_regression
    largest = drag_summary[-1]

    drag_lines = [
        "| 资源节点 | 画布卡片 | 旧版 Median [Q1, Q3] ms | 优化版 Median [Q1, Q3] ms | 中位数降低 | Bootstrap 95% 区间 |",
        "| ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in drag_summary:
        drag_lines.append(
            "| {tree_size} | {rendered_cards} | {before_median_ms:.2f} [{before_q1_ms:.2f}, {before_q3_ms:.2f}] | "
            "{optimized_median_ms:.2f} [{optimized_q1_ms:.2f}, {optimized_q3_ms:.2f}] | "
            "{median_reduction_percent:.2f}% | [{bootstrap_ci_low_percent:.2f}%, {bootstrap_ci_high_percent:.2f}%] |".format(**row)
        )

    display_lines = [
        "| 资源节点 | 画布卡片 | Compact 面积降低 | Overview 面积降低 | Search 弱化 | Focus 卡片降低 | Collapse 卡片降低 | 最大重叠 |",
        "| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in display_trends:
        display_lines.append(
            f"| {row['tree_size']} | {row['baseline_cards']} | "
            f"{float(row['compact_area_reduction_percent']):.2f}% | "
            f"{float(row['overview_area_reduction_percent']):.2f}% | "
            f"{float(row['search_dimming_percent']):.2f}% | "
            f"{float(row['focus_card_reduction_percent']):.2f}% | "
            f"{float(row['collapse_card_reduction_percent']):.2f}% | "
            f"{row['overlap_max']} |"
        )

    playable_by_condition = {row["condition"]: row for row in playable}
    playable_overview = playable_by_condition.get("Optimized Overview", {})
    playable_focus = playable_by_condition.get("Subtree Focus", {})
    playable_collapse = playable_by_condition.get("Context Collapse", {})

    return f"""# 多规模行为树显示优化实验结果

## 实验状态

实验已在 {engine}、{renderer}、{gpu}、1600×900 固定 SubViewport 上完成。受控显示实验覆盖 31、61、121、241 和 364 个资源节点，六种条件各预热 3 次并正式重复 30 次，共 900 条观测。版本化拖拽实验按 A1–B1–B2–A2 顺序执行；每个版本、每个规模有 20 次正式观测，共 200 条，另有每规模每区块 1 次不计入统计的热身。

旧插件实现来自提交 `{BEFORE_PLUGIN_COMMIT}`，拖拽优化由提交 `{OPTIMIZATION_COMMIT}` 引入。两版使用同一确定性树生成器、同一 240 步输入路径和同一硬件。所有 200 次拖拽均满足最终资源位置同步、移动距离阈值与执行顺序保持。

## 受控显示结果

{chr(10).join(display_lines)}

Compact Cards 在不隐藏画布卡片的情况下，把总卡片面积降低 61.09%–61.35%；Compact 与 Semantic Zoom 组成的 Overview 把总卡片面积降低 90.27%–90.34%。Search 在不同规模下弱化 96.15%–99.67% 的非目标卡片并把唯一目标定位到画布内。所有规模和所有条件的卡片重叠数均为 0，实验结束后保存位置与横向执行顺序未改变。由于 GraphEdit 的最小缩放为 0.10×，121 节点及以上的 Baseline 和 Overview 均达到该下限，因此“面积减少”不能被误写为“大树一定能完整放入一屏”。

## 同任务拖拽前后对照

{chr(10).join(drag_lines)}

预设判据为：至少 4/5 个节点规模的中位拖拽时间降低，且没有任一规模回退超过 5%。本次结果为 {positive_sizes}/5 个规模降低、显著回退检查为 `{'通过' if no_major_regression else '未通过'}`，因此总体判据 `{'通过' if acceptance else '未通过'}`。在最大 364 节点规模，中位总处理时间由 {float(largest['before_median_ms']):.2f} ms 降至 {float(largest['optimized_median_ms']):.2f} ms，降低 {float(largest['median_reduction_percent']):.2f}%（bootstrap 95% 区间 {float(largest['bootstrap_ci_low_percent']):.2f}%–{float(largest['bootstrap_ci_high_percent']):.2f}%）。

Bootstrap 区间使用固定种子 `{BOOTSTRAP_SEED}`，分别在同规模的旧版和优化版 20 次观测内进行 {BOOTSTRAP_REPETITIONS:,} 次有放回重采样。它描述本机重复测量的不确定性，不代表跨硬件或真人主观流畅度的总体推断。

## 可玩 241 节点树的生态校验

同一套显示机制还在实际驱动复杂竞技场敌人的 241 节点资源上独立测试。该树包含 202 张画布卡片和 39 个附加 Decorator；Overview 面积降低 {float(playable_overview.get('card_area_reduction_percent', 0.0)):.2f}%，Focus 显示 {playable_focus.get('rendered_cards', '未记录')} 张卡片，Collapse 显示 {playable_collapse.get('rendered_cards', '未记录')} 张卡片，所有条件最大重叠为 0。该证据用于说明受控树结果能够在真实项目资源上复现，不把可玩树当作独立随机样本。

## 论文可直接使用的结果段

为评估大规模行为树显示与交互优化，实验采用同一确定性生成器构造 31、61、121、241 和 364 节点的受控树。六种显示条件在真实 GPU 渲染下分别进行 3 次预热和 30 次正式重复，共获得 900 条显示观测。与 Baseline 相比，Compact Cards 在不隐藏节点的情况下将卡片总面积降低 61.09%–61.35%，Overview 将其降低 90.27%–90.34%；Search 弱化 96.15%–99.67% 的非目标卡片，Focus 与 Collapse 则随规模限制当前上下文。全部条件均保持零卡片重叠、保存位置不变和执行顺序不变。另以优化前提交 `{BEFORE_PLUGIN_COMMIT}` 和当前实现执行 A1–B1–B2–A2 版本对照，每个规模、每个版本记录 20 次相同的 240 步拖拽。{positive_sizes}/5 个规模的中位处理时间下降；364 节点下由 {float(largest['before_median_ms']):.2f} ms 降至 {float(largest['optimized_median_ms']):.2f} ms，降低 {float(largest['median_reduction_percent']):.2f}%。这些结果支持“插件在不同树规模下可量化地降低视觉密度，并在同任务版本对照中减少大图拖拽处理时间”，但几何代理与自动计时不能单独证明真人理解、可读性或主观流畅度改善。

## 限制与允许的结论

- 允许表述：显示开关在五个规模上产生了可测量且一致的面积、上下文和搜索呈现变化；旧版与优化版的固定拖拽处理时间存在所报告差异。
- 不允许表述：面积降低自动证明开发者理解更快，或自动测试等价于真人可用性实验。
- 时间结果来自一台 Windows 笔记本、一个 Godot 版本和一个渲染后端；其他硬件需复测。
- 同一规模的重复观测共享固定树和输入轨迹，bootstrap 区间不能外推为行为树总体或人群总体置信区间。
- 121 节点以上 fit-to-view 达到 0.10× 下限，面积指标应与 Search、Focus、Collapse 的局部上下文指标共同解释。

## 可复现数据

- `testgame/testgame/test_results/multiscale_display_raw.csv`：900 条显示原始观测。
- `testgame/testgame/test_results/multiscale_display_summary.csv`：30 个规模–条件分组。
- `testgame/testgame/test_results/multiscale_display_trends.csv`：跨规模几何趋势。
- `testgame/testgame/test_results/multiscale_drag_raw.csv`：200 条 ABBA 拖拽原始观测。
- `testgame/testgame/test_results/multiscale_drag_summary.csv`：五个规模的版本统计。
- `testgame/testgame/test_results/multiscale_experiment_manifest.json`：提交、输入 SHA-256 与实验参数。
"""


def main() -> None:
    drag_rows = load_and_validate_drag_rows()
    drag_summary = summarize_drag(drag_rows)
    display_rows = read_rows(DISPLAY_RAW)
    display_summary = read_rows(DISPLAY_SUMMARY)
    display_trends = read_rows(DISPLAY_TRENDS)
    playable = read_rows(PLAYABLE_SUMMARY)
    if len(display_rows) != 900:
        raise ValueError(f"Expected 900 display observations, found {len(display_rows)}")
    if len(display_summary) != 30 or len(display_trends) != 5:
        raise ValueError("Display summary does not contain the expected 30 groups and 5 trends")
    if any(int(row["overlap_max"]) != 0 for row in display_trends):
        raise ValueError("A display condition contains overlapping cards")

    raw_fields = list(drag_rows[0].keys())
    write_csv(DRAG_RAW_OUTPUT, raw_fields, drag_rows)
    summary_fields = list(drag_summary[0].keys())
    write_csv(DRAG_SUMMARY_OUTPUT, summary_fields, drag_summary)

    first_drag = drag_rows[0]
    report = report_markdown(
        drag_summary,
        display_trends,
        playable,
        first_drag["engine_version"],
        first_drag["renderer"],
        first_drag["gpu"],
    )
    REPORT_OUTPUT.write_text(report, encoding="utf-8")

    input_paths = [*DRAG_INPUTS, DISPLAY_RAW, DISPLAY_SUMMARY, DISPLAY_TRENDS, PLAYABLE_SUMMARY]
    manifest = {
        "analysis_commit": git_output("rev-parse", "HEAD"),
        "before_plugin_commit": BEFORE_PLUGIN_COMMIT,
        "optimization_commit": OPTIMIZATION_COMMIT,
        "tree_sizes": list(TREE_SIZES),
        "display_conditions": 6,
        "display_warmups_per_group": 3,
        "display_repetitions_per_group": 30,
        "display_observations": len(display_rows),
        "drag_abba_order": ["Before-1", "Optimized-1", "Optimized-2", "Before-2"],
        "drag_steps": 240,
        "drag_warmups_per_size_block": 1,
        "drag_repetitions_per_size_version": 20,
        "drag_observations": len(drag_rows),
        "bootstrap_repetitions": BOOTSTRAP_REPETITIONS,
        "bootstrap_seed": BOOTSTRAP_SEED,
        "inputs": {
            str(path.relative_to(ROOT)).replace("\\", "/"): sha256(path)
            for path in input_paths
        },
    }
    MANIFEST_OUTPUT.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    reductions = [float(row["median_reduction_percent"]) for row in drag_summary]
    print(
        "MULTISCALE_ANALYSIS_OK "
        f"display={len(display_rows)} drag={len(drag_rows)} "
        f"positive_sizes={sum(value > 0.0 for value in reductions)}/5 "
        f"reduction_range={min(reductions):.2f}%..{max(reductions):.2f}%"
    )
    for row in drag_summary:
        print(
            "DRAG_RESULT "
            f"size={row['tree_size']} before={float(row['before_median_ms']):.2f}ms "
            f"optimized={float(row['optimized_median_ms']):.2f}ms "
            f"reduction={float(row['median_reduction_percent']):.2f}% "
            f"ci=[{float(row['bootstrap_ci_low_percent']):.2f}%,"
            f"{float(row['bootstrap_ci_high_percent']):.2f}%]"
        )


if __name__ == "__main__":
    main()
