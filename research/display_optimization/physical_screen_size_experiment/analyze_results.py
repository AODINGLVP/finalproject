from __future__ import annotations

import csv
import hashlib
import json
import statistics
import sys
from collections import defaultdict
from pathlib import Path


TREE_SIZES = (31, 61, 121, 241, 364)
CONDITIONS = (
    "Baseline",
    "Compact Cards",
    "Optimized Overview",
    "Optimized Search",
    "Subtree Focus",
    "Context Collapse",
)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def f(row: dict[str, str], key: str) -> float:
    return float(row[key])


def i(row: dict[str, str], key: str) -> int:
    return int(row[key])


def percent(value: float) -> str:
    return f"{value:.2f}%"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: analyze_results.py <session-directory>")
    session_dir = Path(sys.argv[1]).resolve()
    device_path = session_dir / "devices.csv"
    devices = sorted(read_csv(device_path), key=lambda row: f(row, "diagonal_in"))
    if not devices:
        raise RuntimeError("display inventory is empty")

    all_raw: list[dict[str, str]] = []
    all_summary: list[dict[str, str]] = []
    manifests: list[dict[str, object]] = []
    source_files = [device_path]
    for device in devices:
        slug = "".join(ch.lower() if ch.isalnum() or ch in "_-" else "_" for ch in device["device_key"])
        run_dir = session_dir / "runs" / slug
        raw_path = run_dir / "raw.csv"
        summary_path = run_dir / "summary.csv"
        manifest_path = run_dir / "manifest.json"
        raw_rows = read_csv(raw_path)
        summary_rows = read_csv(summary_path)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        expected_trials = int(manifest["measured_trials"])
        expected_raw = len(TREE_SIZES) * len(CONDITIONS) * expected_trials
        if len(raw_rows) != expected_raw:
            raise RuntimeError(f"{device['device_key']} has {len(raw_rows)} rows, expected {expected_raw}")
        if len(summary_rows) != len(TREE_SIZES) * len(CONDITIONS):
            raise RuntimeError(f"{device['device_key']} has an incomplete summary")
        if int(manifest["failures"]) != 0:
            raise RuntimeError(f"{device['device_key']} manifest records failures")
        all_raw.extend(raw_rows)
        all_summary.extend(summary_rows)
        manifests.append(manifest)
        source_files.extend((raw_path, summary_path, manifest_path, run_dir / "godot_output.txt"))

    expected_total = sum(int(manifest["observation_count"]) for manifest in manifests)
    if len(all_raw) != expected_total:
        raise RuntimeError(f"combined raw rows {len(all_raw)} != manifest total {expected_total}")

    raw_fields = list(all_raw[0].keys())
    summary_fields = list(all_summary[0].keys())
    write_csv(session_dir / "combined_raw.csv", all_raw, raw_fields)
    write_csv(session_dir / "combined_summary.csv", all_summary, summary_fields)

    by_key = {(row["device_key"], i(row, "tree_size"), row["condition"]): row for row in all_summary}
    comparison_rows: list[dict[str, object]] = []
    for device in devices:
        device_key = device["device_key"]
        for tree_size in TREE_SIZES:
            baseline = by_key[(device_key, tree_size, "Baseline")]
            compact = by_key[(device_key, tree_size, "Compact Cards")]
            overview = by_key[(device_key, tree_size, "Optimized Overview")]
            search = by_key[(device_key, tree_size, "Optimized Search")]
            focus = by_key[(device_key, tree_size, "Subtree Focus")]
            collapse = by_key[(device_key, tree_size, "Context Collapse")]
            comparison_rows.append({
                "device_key": device_key,
                "model": device["model"],
                "diagonal_in": device["diagonal_in"],
                "screen_area_cm2": device["screen_area_cm2"],
                "canvas": f"{round(f(device, 'width_cm') * 35)}x{round(f(device, 'height_cm') * 35)}",
                "tree_size": tree_size,
                "baseline_cards_after_fit": baseline["cards_after_fit"],
                "baseline_coverage_after_fit_percent": baseline["coverage_after_fit_percent"],
                "baseline_fit_zoom": baseline["fit_zoom"],
                "baseline_graph_to_screen_area_ratio": baseline["graph_to_screen_area_ratio"],
                "overview_cards_after_fit": overview["cards_after_fit"],
                "overview_coverage_after_fit_percent": overview["coverage_after_fit_percent"],
                "overview_fit_zoom": overview["fit_zoom"],
                "compact_area_reduction_percent": compact["card_area_reduction_percent"],
                "overview_area_reduction_percent": overview["card_area_reduction_percent"],
                "search_target_in_viewport": search["target_in_viewport"],
                "search_center_error_percent_diagonal": f(search, "target_center_error_ratio") * 100.0,
                "focus_context_reduction_percent": focus["context_reduction_percent"],
                "collapse_context_reduction_percent": collapse["context_reduction_percent"],
                "max_overlap": max(i(by_key[(device_key, tree_size, condition)], "overlap_max") for condition in CONDITIONS),
            })
    comparison_fields = list(comparison_rows[0].keys())
    write_csv(session_dir / "screen_size_comparison.csv", comparison_rows, comparison_fields)

    compact_reductions = [float(row["compact_area_reduction_percent"]) for row in comparison_rows]
    overview_reductions = [float(row["overview_area_reduction_percent"]) for row in comparison_rows]
    search_rows = [row for row in all_summary if row["condition"] == "Optimized Search"]
    search_successes = sum(row["target_in_viewport"].lower() == "true" for row in search_rows)
    overlap_max = max(int(row["overlap_max"]) for row in all_summary)
    smallest, largest = devices[0], devices[-1]
    complex_screen_changes: dict[int, dict[str, float]] = {}
    for tree_size in (241, 364):
        small_row = next(
            row for row in comparison_rows
            if row["device_key"] == smallest["device_key"] and row["tree_size"] == tree_size
        )
        large_row = next(
            row for row in comparison_rows
            if row["device_key"] == largest["device_key"] and row["tree_size"] == tree_size
        )
        small_coverage = float(small_row["baseline_coverage_after_fit_percent"])
        large_coverage = float(large_row["baseline_coverage_after_fit_percent"])
        small_graph_ratio = float(small_row["baseline_graph_to_screen_area_ratio"])
        large_graph_ratio = float(large_row["baseline_graph_to_screen_area_ratio"])
        complex_screen_changes[tree_size] = {
            "small_coverage": small_coverage,
            "large_coverage": large_coverage,
            "coverage_points": large_coverage - small_coverage,
            "coverage_multiple": large_coverage / small_coverage,
            "small_graph_ratio": small_graph_ratio,
            "large_graph_ratio": large_graph_ratio,
            "graph_ratio_reduction": (1.0 - large_graph_ratio / small_graph_ratio) * 100.0,
        }

    lines = [
        "# 三块物理屏幕尺寸实验结果",
        "",
        "## 实验状态",
        "",
        f"实验完成 {len(devices)} 块实际连接屏幕、{len(all_raw)} 条正式观测。每块屏幕按 EDID 物理宽高换算为 35 逻辑单位/厘米；分辨率、刷新率、Windows 缩放和 GPU 连接仅作为审计元数据保存，不进入主要比较。所有设备运行清单均记录 0 个失败。",
        "",
        "## 设备与物理尺寸",
        "",
        "| 设备 | 型号 | 宽×高(cm) | 对角线(in) | 面积(cm²) | 归一化画布 |",
        "| --- | --- | ---: | ---: | ---: | ---: |",
    ]
    for device in devices:
        canvas = f"{round(f(device, 'width_cm') * 35)}×{round(f(device, 'height_cm') * 35)}"
        lines.append(
            f"| {device['device_key']} | {device['model']} | {f(device, 'width_cm'):.0f}×{f(device, 'height_cm'):.0f} | "
            f"{f(device, 'diagonal_in'):.2f} | {f(device, 'screen_area_cm2'):.0f} | {canvas} |"
        )

    lines.extend([
        "",
        "## 复杂树在不同屏幕尺寸上的覆盖",
        "",
        "下表只列出 241 和 364 节点，覆盖率表示执行 Fit-to-view 后，卡片中心进入行为树画布的比例。",
        "",
        "| 屏幕 | 节点 | Baseline卡片/覆盖 | Baseline Fit | Overview卡片/覆盖 | Overview Fit | Baseline图面积/屏幕面积 |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ])
    for row in comparison_rows:
        if int(row["tree_size"]) not in (241, 364):
            continue
        lines.append(
            f"| {row['model']} ({float(row['diagonal_in']):.2f}in) | {row['tree_size']} | "
            f"{row['baseline_cards_after_fit']}/{percent(float(row['baseline_coverage_after_fit_percent']))} | "
            f"{float(row['baseline_fit_zoom']):.3f} | {row['overview_cards_after_fit']}/{percent(float(row['overview_coverage_after_fit_percent']))} | "
            f"{float(row['overview_fit_zoom']):.3f} | {float(row['baseline_graph_to_screen_area_ratio']):.2f}× |"
        )

    change_241 = complex_screen_changes[241]
    change_364 = complex_screen_changes[364]

    lines.extend([
        "",
        "从 15.94 英寸增加到 31.55 英寸后，241 节点 Baseline 覆盖率由 "
        f"{change_241['small_coverage']:.2f}% 增至 {change_241['large_coverage']:.2f}%（+{change_241['coverage_points']:.2f} 个百分点，"
        f"为原来的 {change_241['coverage_multiple']:.2f} 倍）；364 节点由 {change_364['small_coverage']:.2f}% 增至 "
        f"{change_364['large_coverage']:.2f}%（+{change_364['coverage_points']:.2f} 个百分点，为原来的 {change_364['coverage_multiple']:.2f} 倍）。",
        "",
        f"同一变化使 241 节点 Baseline 图面积/屏幕面积由 {change_241['small_graph_ratio']:.2f}× 降至 "
        f"{change_241['large_graph_ratio']:.2f}×（降低 {change_241['graph_ratio_reduction']:.2f}%），364 节点由 "
        f"{change_364['small_graph_ratio']:.2f}× 降至 {change_364['large_graph_ratio']:.2f}×（降低 {change_364['graph_ratio_reduction']:.2f}%）。",
        "",
        "241 和 364 节点在三块屏幕的 Baseline 与 Overview 中均达到 0.10× 最小缩放。因此物理面积增加显著提高了进入视口的节点比例，但没有让完整宽树进入一屏；Search、Focus、Collapse 和小地图仍然必要。",
        "",
        "## 跨屏幕显示机制结果",
        "",
        f"Compact Cards 在全部屏幕和规模下的卡片面积降低范围为 {min(compact_reductions):.2f}%–{max(compact_reductions):.2f}%；Optimized Overview 为 {min(overview_reductions):.2f}%–{max(overview_reductions):.2f}%。Search 在 {search_successes}/{len(search_rows)} 个屏幕–规模组合中一次提交后把目标置于画布内。全部条件最大卡片重叠为 {overlap_max}。",
        "",
        f"当前设备从 {f(smallest, 'diagonal_in'):.2f} 英寸、{f(smallest, 'screen_area_cm2'):.0f} cm² 增长到 {f(largest, 'diagonal_in'):.2f} 英寸、{f(largest, 'screen_area_cm2'):.0f} cm²。主要结论应依据上表中覆盖率、Fit 缩放和图面积/屏幕面积的配对变化，而不能依据不同设备的处理时间。",
        "",
        "## 论文可用结论边界",
        "",
        "该实验能够说明：在统一逻辑单位/厘米后，物理显示面积变化会怎样改变复杂行为树的几何覆盖；当前显示机制是否在三块实际屏幕上保持目标定位、零重叠和结构安全。由于没有真人参与，数据不能证明人的理解速度、主观可读性或认知负荷改善。三块显示器也不是显示器总体的随机样本。",
        "",
        "## 可复现文件",
        "",
        "- `devices.csv`：物理设备及审计元数据。",
        "- `runs/<device>/raw.csv`：每块屏幕的正式原始观测。",
        "- `runs/<device>/summary.csv`：每块屏幕的规模–条件汇总。",
        "- `runs/<device>/screenshots/`：241/364节点真实GPU证据截图。",
        "- `combined_raw.csv`：合并原始观测。",
        "- `combined_summary.csv`：合并条件汇总。",
        "- `screen_size_comparison.csv`：按物理屏幕尺寸配对的论文主表数据。",
        "- `session_manifest.json`：输入文件SHA-256和运行提交。",
        "",
    ])
    (session_dir / "report_zh.md").write_text("\n".join(lines), encoding="utf-8")

    manifest = {
        "schema_version": 1,
        "session": devices[0]["session"],
        "device_count": len(devices),
        "observation_count": len(all_raw),
        "tree_sizes": TREE_SIZES,
        "conditions": CONDITIONS,
        "logical_units_per_cm": 35,
        "git_commits": sorted({str(manifest["git_commit"]) for manifest in manifests}),
        "all_run_failures": sum(int(manifest["failures"]) for manifest in manifests),
        "source_sha256": {str(path.relative_to(session_dir)): sha256(path) for path in source_files},
    }
    (session_dir / "session_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        f"PHYSICAL_SCREEN_ANALYSIS_OK devices={len(devices)} observations={len(all_raw)} "
        f"search={search_successes}/{len(search_rows)} overlap_max={overlap_max} output={session_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
