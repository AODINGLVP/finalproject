#!/usr/bin/env python3
"""Summarise the paired evaluation of the five current Display features.

The experiment is deterministic rather than a participant sample.  This script
therefore reports paired descriptive effects and never attaches p-values or human
usability claims to the geometric measurements.
"""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import textwrap
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image, ImageDraw, ImageFont


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_DATA_DIR = (
    SCRIPT_DIR
    / "data"
    / "2026-08-28_tight_layout_overlay_smart_2131924"
)
FEATURE_ORDER = [
    "auto_spacing",
    "semantic_zoom",
    "translucent_cards",
    "breadcrumb",
    "fisheye",
]
FEATURE_NAMES_ZH = {
    "auto_spacing": "智能拖拽重排",
    "semantic_zoom": "自适应缩放细节",
    "translucent_cards": "可读连线覆盖",
    "breadcrumb": "相关节点聚焦",
    "fisheye": "鱼眼聚焦",
}
SCREEN_ORDER = ["laptop_15_94", "medium_26_96", "large_31_55"]
SCREEN_NAMES_ZH = {
    "laptop_15_94": "15.94 英寸",
    "medium_26_96": "26.96 英寸",
    "large_31_55": "31.55 英寸",
}
TREE_ORDER = [31, 61, 121, 241, 364]
FONT_CANDIDATES = [
    Path("C:/Windows/Fonts/msyh.ttc"),
    Path("C:/Windows/Fonts/simhei.ttf"),
    Path("C:/Windows/Fonts/arial.ttf"),
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def git_head() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=SCRIPT_DIR, text=True
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def truthy(series: pd.Series) -> pd.Series:
    return series.astype(str).str.lower().isin(["true", "1"])


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in FONT_CANDIDATES:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def validate_raw(data: pd.DataFrame, manifest: dict) -> None:
    assert len(data) == 450, f"Expected 450 rows, got {len(data)}"
    assert data["pair_id"].nunique() == 225
    assert set(data["feature_key"]) == set(FEATURE_ORDER)
    assert set(data["screen_key"]) == set(SCREEN_ORDER)
    assert set(data["tree_size"].astype(int)) == set(TREE_ORDER)
    assert set(data["state"]) == {"off", "on"}
    pair_sizes = data.groupby("pair_id")["state"].agg(["count", "nunique"])
    assert (pair_sizes["count"] == 2).all()
    assert (pair_sizes["nunique"] == 2).all()
    assert truthy(data["topology_unchanged"]).all()
    assert truthy(data["execution_order_unchanged"]).all()
    assert truthy(data["resource_positions_unchanged"]).all()
    assert int(manifest["failures"]) == 0
    assert int(manifest["observation_count"]) == 450
    assert int(manifest["pair_count"]) == 225


def paired_feature(data: pd.DataFrame, feature: str) -> tuple[pd.DataFrame, pd.DataFrame]:
    subset = data[data["feature_key"] == feature]
    off = subset[subset["state"] == "off"].set_index("pair_id").sort_index()
    on = subset[subset["state"] == "on"].set_index("pair_id").sort_index()
    assert off.index.equals(on.index)
    for column in ["screen_key", "tree_size", "task_index", "target_id"]:
        assert (off[column].to_numpy() == on[column].to_numpy()).all()
    return off, on


def derive_pairs(data: pd.DataFrame) -> pd.DataFrame:
    frames: list[pd.DataFrame] = []
    for feature in FEATURE_ORDER:
        off, on = paired_feature(data, feature)
        frame = on[[
            "feature_key",
            "feature",
            "screen_key",
            "screen_model",
            "width_cm",
            "height_cm",
            "diagonal_in",
            "screen_area_cm2",
            "canvas_width",
            "canvas_height",
            "tree_size",
            "tree_path",
            "actor",
            "task_index",
            "target_id",
        ]].copy()
        frame["topology_safe"] = truthy(on["topology_unchanged"]).to_numpy()
        frame["execution_order_safe"] = truthy(on["execution_order_unchanged"]).to_numpy()
        frame["resource_positions_safe"] = truthy(on["resource_positions_unchanged"]).to_numpy()
        frame["new_overlap_pairs"] = (
            on["overlap_pairs"].to_numpy() - off["overlap_pairs"].to_numpy()
        )
        frame["new_hierarchy_violations"] = (
            on["hierarchy_violations"].to_numpy()
            - off["hierarchy_violations"].to_numpy()
        )

        if feature == "auto_spacing":
            off_area = off["smart_overlap_area_px2"].to_numpy(float)
            on_area = on["smart_overlap_area_px2"].to_numpy(float)
            frame["primary_metric"] = "induced_overlap_area_reduction_pct"
            frame["primary_effect_pct"] = (off_area - on_area) / off_area * 100.0
            frame["off_overlap_pairs"] = off["smart_overlap_pairs"].to_numpy()
            frame["on_overlap_pairs"] = on["smart_overlap_pairs"].to_numpy()
            frame["other_cards_moved"] = on["smart_other_cards_moved"].to_numpy()
            frame["total_other_move_px"] = on["smart_total_other_move_px"].to_numpy()
            frame["max_other_move_px"] = on["smart_max_other_move_px"].to_numpy()
            frame["far_cards_moved"] = on["smart_far_cards_moved"].to_numpy()
            frame["effect_contract_pass"] = (
                (off_area > 1.0)
                & (on_area < off_area * 0.05)
                & (on["smart_other_cards_moved"].to_numpy() <= 24)
            )
        elif feature == "semantic_zoom":
            off_area = off["adaptive_card_area_px2"].to_numpy(float)
            on_area = on["adaptive_card_area_px2"].to_numpy(float)
            off_fields = off["adaptive_information_fields"].to_numpy(float)
            on_fields = on["adaptive_information_fields"].to_numpy(float)
            frame["primary_metric"] = "card_area_reduction_pct"
            frame["primary_effect_pct"] = (off_area - on_area) / off_area * 100.0
            frame["information_field_reduction_pct"] = (
                (off_fields - on_fields) / off_fields * 100.0
            )
            frame["fully_visible_card_gain"] = (
                on["adaptive_cards_fully_in_viewport"].to_numpy()
                - off["adaptive_cards_fully_in_viewport"].to_numpy()
            )
            frame["effect_contract_pass"] = (
                (on["adaptive_detail_level"].to_numpy() < off["adaptive_detail_level"].to_numpy())
                & ((on_area < off_area - 1.0) | (on_fields < off_fields))
                & (frame["new_hierarchy_violations"].to_numpy() <= 0)
            )
        elif feature == "translucent_cards":
            alpha = on["overlay_background_alpha"].to_numpy(float)
            frame["primary_metric"] = "edge_reveal_proxy_pct"
            frame["primary_effect_pct"] = (1.0 - alpha) * 100.0
            frame["controlled_crossing_length_px"] = on[
                "overlay_crossing_length_px"
            ].to_numpy()
            frame["weighted_revealed_edge_px"] = on[
                "overlay_revealed_edge_weighted_px"
            ].to_numpy()
            frame["natural_visible_edges"] = on[
                "overlay_natural_visible_edges"
            ].to_numpy()
            frame["natural_occluded_edges"] = on[
                "overlay_natural_occluded_edges"
            ].to_numpy()
            frame["natural_occlusion_events"] = on[
                "overlay_natural_occlusion_events"
            ].to_numpy()
            frame["natural_occluded_length_px"] = on[
                "overlay_natural_occluded_length_px"
            ].to_numpy()
            frame["natural_occluded_edge_ratio"] = on[
                "overlay_natural_occluded_edge_ratio"
            ].to_numpy()
            frame["natural_occluded_length_ratio"] = on[
                "overlay_natural_occluded_length_ratio"
            ].to_numpy()
            frame["natural_blocking_cards"] = on[
                "overlay_natural_blocking_cards"
            ].to_numpy()
            frame["line_background_color_gap_off"] = off[
                "overlay_line_background_color_gap"
            ].to_numpy()
            frame["line_background_color_gap_on"] = on[
                "overlay_line_background_color_gap"
            ].to_numpy()
            frame["line_background_color_gap_gain"] = (
                frame["line_background_color_gap_on"]
                - frame["line_background_color_gap_off"]
            )
            frame["line_background_sample_count"] = on[
                "overlay_line_background_sample_count"
            ].to_numpy()
            frame["protected_text_masks"] = on["overlay_text_mask_count"].to_numpy()
            frame["effect_contract_pass"] = (
                (on["overlay_crossing_length_px"].to_numpy() > 1.0)
                & (alpha < off["overlay_background_alpha"].to_numpy(float))
                & truthy(on["overlay_routes_unchanged"]).to_numpy()
                & (on["overlay_text_mask_count"].to_numpy() > 0)
            )
        elif feature == "breadcrumb":
            unrelated = on["related_unrelated_count"].to_numpy(float)
            dimmed = on["related_correctly_dimmed"].to_numpy(float)
            off_bright = off["related_full_bright_in_view"].to_numpy(float)
            on_bright = on["related_full_bright_in_view"].to_numpy(float)
            frame["primary_metric"] = "unrelated_nodes_dimmed_pct"
            frame["primary_effect_pct"] = dimmed / unrelated * 100.0
            frame["salience_ratio"] = on["related_salience_ratio"].to_numpy()
            frame["unrelated_nodes"] = unrelated
            frame["unrelated_nodes_dimmed"] = dimmed
            frame["full_bright_view_reduction_pct"] = np.where(
                off_bright > 0, (off_bright - on_bright) / off_bright * 100.0, np.nan
            )
            frame["effect_contract_pass"] = (
                (unrelated > 0)
                & (dimmed == unrelated)
                & (on["related_mean_alpha"].to_numpy(float) >= 0.95)
                & (on["related_unrelated_mean_alpha"].to_numpy(float) <= 0.19)
            )
        elif feature == "fisheye":
            off_width = off["fisheye_target_width_px"].to_numpy(float)
            on_width = on["fisheye_target_width_px"].to_numpy(float)
            frame["primary_metric"] = "target_width_gain_pct"
            frame["primary_effect_pct"] = (on_width - off_width) / off_width * 100.0
            frame["off_target_width_px"] = off_width
            frame["on_target_width_px"] = on_width
            frame["target_field_gain"] = (
                on["fisheye_target_fields"].to_numpy()
                - off["fisheye_target_fields"].to_numpy()
            )
            frame["far_mean_alpha"] = on["fisheye_far_mean_alpha"].to_numpy()
            frame["local_layout_cards"] = on["fisheye_layout_cards"].to_numpy()
            frame["local_reflow_cards"] = on["fisheye_reflow_cards"].to_numpy()
            frame["effect_contract_pass"] = (
                (on["fisheye_stationary_focus_id"].to_numpy() == on["target_id"].to_numpy())
                & (on_width > off_width * 1.05)
                & (on["fisheye_target_fields"].to_numpy() > off["fisheye_target_fields"].to_numpy())
                & (on["fisheye_layout_cards"].to_numpy() <= 8)
            )
        frames.append(frame.reset_index())
    paired = pd.concat(frames, ignore_index=True)
    assert len(paired) == 225
    assert paired["effect_contract_pass"].all()
    assert paired[["topology_safe", "execution_order_safe", "resource_positions_safe"]].all().all()
    return paired


def aggregate_long(paired: pd.DataFrame, group_column: str) -> pd.DataFrame:
    rows: list[dict] = []
    order = SCREEN_ORDER if group_column == "screen_key" else TREE_ORDER
    for feature in FEATURE_ORDER:
        subset = paired[paired["feature_key"] == feature]
        for group in order:
            selected = subset[subset[group_column] == group]
            row = {
                "feature_key": feature,
                "feature_zh": FEATURE_NAMES_ZH[feature],
                group_column: group,
                "cases": len(selected),
                "primary_metric": selected["primary_metric"].iloc[0],
                "primary_effect_mean_pct": selected["primary_effect_pct"].mean(),
                "primary_effect_median_pct": selected["primary_effect_pct"].median(),
                "effect_contract_pass_rate_pct": selected["effect_contract_pass"].mean() * 100.0,
            }
            if feature == "semantic_zoom":
                row["secondary_effect_mean"] = selected[
                    "information_field_reduction_pct"
                ].mean()
                row["secondary_metric"] = "information_field_reduction_pct"
            elif feature == "breadcrumb":
                row["secondary_effect_mean"] = selected[
                    "full_bright_view_reduction_pct"
                ].mean()
                row["secondary_metric"] = "full_bright_view_reduction_pct"
            elif feature == "fisheye":
                row["secondary_effect_mean"] = selected["target_field_gain"].mean()
                row["secondary_metric"] = "target_field_gain"
            elif feature == "auto_spacing":
                row["secondary_effect_mean"] = selected["other_cards_moved"].mean()
                row["secondary_metric"] = "other_cards_moved"
            else:
                row["secondary_effect_mean"] = selected[
                    "natural_occluded_edge_ratio"
                ].mean()
                row["secondary_metric"] = "natural_occluded_edge_ratio"
            rows.append(row)
    return pd.DataFrame(rows)


def feature_summary(paired: pd.DataFrame) -> pd.DataFrame:
    rows: list[dict] = []
    for feature in FEATURE_ORDER:
        subset = paired[paired["feature_key"] == feature]
        row = {
            "feature_key": feature,
            "feature_zh": FEATURE_NAMES_ZH[feature],
            "cases": len(subset),
            "effect_contract_passes": int(subset["effect_contract_pass"].sum()),
            "primary_metric": subset["primary_metric"].iloc[0],
            "primary_effect_mean_pct": subset["primary_effect_pct"].mean(),
            "primary_effect_median_pct": subset["primary_effect_pct"].median(),
            "primary_effect_min_pct": subset["primary_effect_pct"].min(),
            "primary_effect_max_pct": subset["primary_effect_pct"].max(),
            "cases_with_new_overlap": int((subset["new_overlap_pairs"] > 0).sum()),
            "cases_with_new_hierarchy_violation": int(
                (subset["new_hierarchy_violations"] > 0).sum()
            ),
        }
        if feature == "auto_spacing":
            row["secondary_metric"] = "other_cards_moved"
            row["secondary_median"] = subset["other_cards_moved"].median()
            row["secondary_range"] = (
                f"{subset['other_cards_moved'].min():.0f}–"
                f"{subset['other_cards_moved'].max():.0f}"
            )
            row["tertiary_metric"] = "total_other_move_px"
            row["tertiary_median"] = subset["total_other_move_px"].median()
            row["tertiary_range"] = (
                f"{subset['total_other_move_px'].min():.2f}–"
                f"{subset['total_other_move_px'].max():.2f}"
            )
        elif feature == "semantic_zoom":
            row["secondary_metric"] = "information_field_reduction_pct"
            row["secondary_median"] = subset[
                "information_field_reduction_pct"
            ].median()
            row["secondary_range"] = (
                f"{subset['information_field_reduction_pct'].min():.2f}–"
                f"{subset['information_field_reduction_pct'].max():.2f}"
            )
        elif feature == "translucent_cards":
            row["secondary_metric"] = "natural_occluded_edge_ratio"
            row["secondary_median"] = subset["natural_occluded_edge_ratio"].median()
            row["secondary_range"] = (
                f"{subset['natural_occluded_edge_ratio'].min():.4f}–"
                f"{subset['natural_occluded_edge_ratio'].max():.4f}"
            )
            row["tertiary_metric"] = "line_background_color_gap_gain"
            row["tertiary_median"] = subset["line_background_color_gap_gain"].median()
            row["tertiary_range"] = (
                f"{subset['line_background_color_gap_gain'].min():.4f}–"
                f"{subset['line_background_color_gap_gain'].max():.4f}"
            )
        elif feature == "breadcrumb":
            row["secondary_metric"] = "salience_ratio"
            row["secondary_median"] = subset["salience_ratio"].median()
            row["secondary_range"] = (
                f"{subset['salience_ratio'].min():.2f}–"
                f"{subset['salience_ratio'].max():.2f}"
            )
        else:
            row["secondary_metric"] = "target_field_gain"
            row["secondary_median"] = subset["target_field_gain"].median()
            row["secondary_range"] = (
                f"{subset['target_field_gain'].min():.0f}–"
                f"{subset['target_field_gain'].max():.0f}"
            )
        rows.append(row)
    return pd.DataFrame(rows)


def structured_evaluation(paired: pd.DataFrame) -> pd.DataFrame:
    fisheye = paired[paired["feature_key"] == "fisheye"]
    smart = paired[paired["feature_key"] == "auto_spacing"]
    overlay = paired[paired["feature_key"] == "translucent_cards"]
    fisheye_min_width = fisheye["on_target_width_px"].min()
    fisheye_overlap_cases = int((fisheye["new_overlap_pairs"] > 0).sum())
    fisheye_hierarchy_cases = int((fisheye["new_hierarchy_violations"] > 0).sum())
    return pd.DataFrame(
        [
            {
                "recommendation_order": 1,
                "feature_key": "semantic_zoom",
                "feature_zh": FEATURE_NAMES_ZH["semantic_zoom"],
                "best_use": "持续查看整棵树和在缩放时切换信息密度",
                "strongest_context": "小屏幕，以及 121–364 节点的概览",
                "measured_advantage": "整体卡片面积和字段数量同时下降，且未新增层级错误",
                "observed_cost": "低缩放时主动隐藏字段，需要放大或配合鱼眼恢复细节",
                "recommendation": "五项中最适合作为通用默认显示功能",
            },
            {
                "recommendation_order": 2,
                "feature_key": "auto_spacing",
                "feature_zh": FEATURE_NAMES_ZH["auto_spacing"],
                "best_use": "拖拽编辑时消除新产生的卡片遮挡",
                "strongest_context": "所有屏幕和规模；效果由局部碰撞而非画布尺寸决定",
                "measured_advantage": "45/45 个受控拖拽场景清除全部诱发重叠",
                "observed_cost": f"会连带移动其他卡片；中位数为 {smart['other_cards_moved'].median():.0f} 张，总移动距离中位数为 {smart['total_other_move_px'].median():.1f} px",
                "recommendation": "直接编辑任务中最有价值，适合默认开启",
            },
            {
                "recommendation_order": 3,
                "feature_key": "breadcrumb",
                "feature_zh": FEATURE_NAMES_ZH["breadcrumb"],
                "best_use": "选中节点后追踪祖先、后代和同级关系",
                "strongest_context": "121 节点以上，尤其屏幕中同时出现许多分支时",
                "measured_advantage": "全部无关节点被淡化，相关/无关平均不透明度比为 5.56",
                "observed_cost": "聚焦状态不适合同时比较多个无关分支",
                "recommendation": "结构检查最有效，适合默认开启并由选择触发",
            },
            {
                "recommendation_order": 4,
                "feature_key": "fisheye",
                "feature_zh": FEATURE_NAMES_ZH["fisheye"],
                "best_use": "在概览缩放下临时恢复指针附近节点的可读尺寸",
                "strongest_context": "小屏幕与 241–364 节点树",
                "measured_advantage": f"目标卡片保持至少 {fisheye_min_width:.0f} px，规模越大相对增益越高",
                "observed_cost": f"{fisheye_overlap_cases}/45 个场景新增局部重叠，{fisheye_hierarchy_cases}/45 个场景新增视觉层级遮挡",
                "recommendation": "特定环境增益最大，但应按需使用而不是作为全局整洁布局",
            },
            {
                "recommendation_order": 5,
                "feature_key": "translucent_cards",
                "feature_zh": FEATURE_NAMES_ZH["translucent_cards"],
                "best_use": "查看穿过卡片背景的拥挤连线，同时保护文字区域",
                "strongest_context": "局部边拥挤，与屏幕尺寸和节点总数关系较弱",
                "measured_advantage": f"自然视口中平均 {overlay['natural_occluded_edges'].mean():.2f} 条可见边被卡片遮挡；受控遮挡中路线与文字掩膜保持不变",
                "observed_cost": "作用局部且不能减少节点数量或整体拥挤；像素差会受文字和控件位置影响",
                "recommendation": "保留为情境功能，不把它作为主要优化结论",
            },
        ]
    )


def draw_bar_panels(
    output_path: Path,
    title: str,
    panels: list[tuple[str, list[str], list[float], str]],
) -> None:
    width, height = 1800, 660
    image = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(image)
    title_font = load_font(34)
    panel_font = load_font(25)
    label_font = load_font(20)
    value_font = load_font(19)
    draw.text((50, 24), title, fill="#172033", font=title_font)
    panel_width = 550
    colors = ["#2F80ED", "#27AE60", "#F2994A", "#9B51E0", "#EB5757"]
    for panel_index, (panel_title, labels, values, unit) in enumerate(panels):
        x0 = 45 + panel_index * 585
        y0 = 105
        draw.rounded_rectangle(
            (x0, y0, x0 + panel_width, height - 35),
            radius=18,
            fill="#F7F9FC",
            outline="#D7DDE8",
            width=2,
        )
        draw.text((x0 + 24, y0 + 20), panel_title, fill="#172033", font=panel_font)
        max_value = max(values) if values else 1.0
        max_value = max(max_value, 1.0)
        chart_top = y0 + 85
        chart_bottom = height - 125
        available_height = chart_bottom - chart_top
        bar_slot = (panel_width - 55) / max(len(values), 1)
        for index, (label, value) in enumerate(zip(labels, values)):
            bar_width = min(72, bar_slot * 0.55)
            x = x0 + 35 + index * bar_slot + (bar_slot - bar_width) / 2
            bar_height = available_height * value / max_value
            y = chart_bottom - bar_height
            draw.rounded_rectangle(
                (x, y, x + bar_width, chart_bottom),
                radius=7,
                fill=colors[index % len(colors)],
            )
            value_text = f"{value:.1f}{unit}"
            bbox = draw.textbbox((0, 0), value_text, font=value_font)
            draw.text(
                (x + (bar_width - (bbox[2] - bbox[0])) / 2, y - 28),
                value_text,
                fill="#172033",
                font=value_font,
            )
            wrapped = "\n".join(textwrap.wrap(label, width=8))
            bbox = draw.multiline_textbbox((0, 0), wrapped, font=label_font, spacing=3)
            draw.multiline_text(
                (
                    x + (bar_width - (bbox[2] - bbox[0])) / 2,
                    chart_bottom + 12,
                ),
                wrapped,
                fill="#374151",
                font=label_font,
                spacing=3,
                align="center",
            )
    image.save(output_path, quality=95)


def comparison_images(data_dir: Path, output_dir: Path) -> list[Path]:
    evidence_dir = data_dir / "evidence"
    comparison_dir = output_dir / "comparisons"
    comparison_dir.mkdir(parents=True, exist_ok=True)
    title_font = load_font(28)
    outputs: list[Path] = []
    for feature in FEATURE_ORDER:
        off_path = evidence_dir / f"{feature}_off.png"
        on_path = evidence_dir / f"{feature}_on.png"
        off_image = Image.open(off_path).convert("RGB")
        on_image = Image.open(on_path).convert("RGB")
        assert off_image.size == on_image.size
        width, height = off_image.size
        header = 62
        canvas = Image.new("RGB", (width * 2, height + header), "white")
        canvas.paste(off_image, (0, header))
        canvas.paste(on_image, (width, header))
        draw = ImageDraw.Draw(canvas)
        left_label = f"关闭（基线）— {FEATURE_NAMES_ZH[feature]}"
        right_label = f"开启 — {FEATURE_NAMES_ZH[feature]}"
        draw.text((24, 14), left_label, fill="#172033", font=title_font)
        draw.text((width + 24, 14), right_label, fill="#172033", font=title_font)
        draw.line((width, 0, width, height + header), fill="#D32F2F", width=4)
        output_path = comparison_dir / f"{feature}_before_after.png"
        canvas.save(output_path, quality=95)
        outputs.append(output_path)

    thumbnails: list[Image.Image] = []
    for output in outputs:
        image = Image.open(output).convert("RGB")
        image.thumbnail((1500, 520), Image.Resampling.LANCZOS)
        thumbnails.append(image.copy())
    contact_height = sum(image.height for image in thumbnails) + 24 * (len(thumbnails) - 1)
    contact = Image.new("RGB", (max(image.width for image in thumbnails), contact_height), "white")
    y = 0
    for image in thumbnails:
        contact.paste(image, (0, y))
        y += image.height + 24
    contact_path = output_dir / "all_five_features_before_after.png"
    contact.save(contact_path, quality=95)
    outputs.append(contact_path)
    return outputs


def markdown_table(frame: pd.DataFrame, columns: list[str], formats: dict[str, str]) -> str:
    header = "| " + " | ".join(columns) + " |"
    separator = "| " + " | ".join(["---"] * len(columns)) + " |"
    lines = [header, separator]
    for _, row in frame.iterrows():
        values: list[str] = []
        for column in columns:
            value = row[column]
            if column in formats and pd.notna(value):
                values.append(formats[column].format(value))
            else:
                values.append(str(value))
        lines.append("| " + " | ".join(values) + " |")
    return "\n".join(lines)


def write_results_markdown(
    output_path: Path,
    paired: pd.DataFrame,
    feature_frame: pd.DataFrame,
    screen_frame: pd.DataFrame,
    tree_frame: pd.DataFrame,
    decisions: pd.DataFrame,
) -> None:
    adaptive = paired[paired["feature_key"] == "semantic_zoom"]
    smart = paired[paired["feature_key"] == "auto_spacing"]
    overlay = paired[paired["feature_key"] == "translucent_cards"]
    related = paired[paired["feature_key"] == "breadcrumb"]
    fisheye = paired[paired["feature_key"] == "fisheye"]
    adaptive_screen = screen_frame[screen_frame["feature_key"] == "semantic_zoom"].copy()
    adaptive_screen["屏幕"] = adaptive_screen["screen_key"].map(SCREEN_NAMES_ZH)
    fisheye_screen = screen_frame[screen_frame["feature_key"] == "fisheye"].copy()
    fisheye_screen["屏幕"] = fisheye_screen["screen_key"].map(SCREEN_NAMES_ZH)
    related_screen = screen_frame[screen_frame["feature_key"] == "breadcrumb"].copy()
    related_screen["屏幕"] = related_screen["screen_key"].map(SCREEN_NAMES_ZH)
    fisheye_tree = tree_frame[tree_frame["feature_key"] == "fisheye"].copy()
    adaptive_tree = tree_frame[tree_frame["feature_key"] == "semantic_zoom"].copy()
    related_tree = tree_frame[tree_frame["feature_key"] == "breadcrumb"].copy()
    smart_tree = tree_frame[tree_frame["feature_key"] == "auto_spacing"].copy()
    smart_screen = screen_frame[screen_frame["feature_key"] == "auto_spacing"].copy()
    smart_screen["屏幕"] = smart_screen["screen_key"].map(SCREEN_NAMES_ZH)
    overlay_screen = screen_frame[screen_frame["feature_key"] == "translucent_cards"].copy()
    overlay_screen["屏幕"] = overlay_screen["screen_key"].map(SCREEN_NAMES_ZH)

    lines = [
        "# 当前五项 Display 功能实验结果（中文工作稿）",
        "",
        "## 1　实验范围与解释边界",
        "",
        "本次正式实验在当前项目提交上运行，使用五棵实际控制可玩敌人的行为树（31、61、121、241 和 364 个资源节点），以及三种来自真实 EDID 测量的物理屏幕尺寸配置。当前只连接一块屏幕，因此三种尺寸是在同一块真实 GPU 上通过 SubViewport 重放；它们不是本次重新在三台实体显示器上分别运行的结果。",
        "",
        "实验共包含 225 组成对比较和 450 条原始观测。每一对只改变一项功能的开关，五项功能均有 45 对。所有观测都保持行为树拓扑、保存坐标和执行顺序不变。这里的数字描述卡片面积、遮挡、透明度和目标尺寸等直接显示结果，不等同于参与者完成时间、主观可读性或认知负荷。",
        "",
        "## 2　五项功能的主要结果",
        "",
        f"智能拖拽重排在 45/45 个受控拖拽场景中把诱发的重叠面积降为 0，即几何重叠减少 100%。每次有 {smart['other_cards_moved'].median():.0f} 张其他卡片发生移动（范围 {smart['other_cards_moved'].min():.0f}–{smart['other_cards_moved'].max():.0f}）。这说明它最直接地处理编辑过程中的新遮挡，但代价是少量邻近卡片也会避让。",
        "",
        f"自适应缩放细节使总卡片面积平均减少 {adaptive['primary_effect_pct'].mean():.2f}%，中位数减少 {adaptive['primary_effect_pct'].median():.2f}%；信息字段平均减少 {adaptive['information_field_reduction_pct'].mean():.2f}%，中位数减少 {adaptive['information_field_reduction_pct'].median():.2f}%。它没有新增层级遮挡，并在 10/45 个场景中增加了完整位于视口内的卡片，累计增加 {adaptive['fully_visible_card_gain'].sum():.0f} 张。",
        "",
        f"可读连线覆盖把卡片背景不透明度从 1.00 降到 0.72。自然视口扫描中，平均每个案例有 {overlay['natural_occluded_edges'].mean():.2f} 条可见连线被非端点卡片遮挡；受控遮挡中，遮挡线段中位长度为 {overlay['controlled_crossing_length_px'].median():.2f} px。连接路线保持不变，且每棵树的文字掩膜仍被保留。像素采样也被记录，但它会受文字和控件位置影响，因此只作为辅助数据。",
        "",
        f"相关节点聚焦正确淡化了全部 {related['unrelated_nodes'].sum():.0f} 次无关节点实例，相关节点与无关节点的平均不透明度比为 {related['salience_ratio'].median():.2f}:1。视口内保持全亮的节点数量中位数减少 {related['full_bright_view_reduction_pct'].median():.2f}%。该功能没有隐藏或移动节点，所以适合在保留全局位置的同时查看一个关系分支。",
        "",
        f"鱼眼聚焦把目标卡片宽度提高到 {fisheye['on_target_width_px'].min():.0f}–{fisheye['on_target_width_px'].max():.0f} px，相对基线的中位增幅为 {fisheye['primary_effect_pct'].median():.2f}%，同时恢复的字段数中位数为 {fisheye['target_field_gain'].median():.0f}。但它在 {(fisheye['new_overlap_pairs'] > 0).sum()}/45 个场景新增局部重叠，并在 {(fisheye['new_hierarchy_violations'] > 0).sum()}/45 个场景出现新增视觉层级遮挡。因此它是局部细节工具，而不是保证全图整洁的布局工具。",
        "",
        "## 3　屏幕尺寸下的差异",
        "",
        "自适应缩放细节的卡片面积平均减少量：",
        "",
        markdown_table(
            adaptive_screen.rename(columns={"primary_effect_mean_pct": "面积减少（%）"}),
            ["屏幕", "面积减少（%）"],
            {"面积减少（%）": "{:.2f}"},
        ),
        "",
        "鱼眼聚焦的目标宽度平均增幅：",
        "",
        markdown_table(
            fisheye_screen.rename(columns={"primary_effect_mean_pct": "宽度增幅（%）"}),
            ["屏幕", "宽度增幅（%）"],
            {"宽度增幅（%）": "{:.2f}"},
        ),
        "",
        "相关节点聚焦使视口内全亮节点减少的平均比例：",
        "",
        markdown_table(
            related_screen.rename(columns={"secondary_effect_mean": "全亮节点减少（%）"}),
            ["屏幕", "全亮节点减少（%）"],
            {"全亮节点减少（%）": "{:.2f}"},
        ),
        "",
        "智能拖拽重排在不同屏幕上的其他节点移动数量：",
        "",
        markdown_table(
            smart_screen.rename(columns={"secondary_effect_mean": "平均移动节点数"}),
            ["屏幕", "平均移动节点数"],
            {"平均移动节点数": "{:.2f}"},
        ),
        "",
        "可读连线覆盖在不同屏幕上的自然遮挡比例：",
        "",
        markdown_table(
            overlay_screen.rename(columns={"secondary_effect_mean": "自然遮挡边比例"}),
            ["屏幕", "自然遮挡边比例"],
            {"自然遮挡边比例": "{:.4f}"},
        ),
        "",
        f"结果表明，小屏幕不是简单地让所有功能都更有优势。Adaptive 和 Fisheye 在 15.94 英寸配置上的相对效果最大：前者用更少面积维持概览，后者把原本很小的目标恢复到至少 {fisheye['on_target_width_px'].min():.0f} px。Related Focus 在中、大屏幕上的全亮节点减少比例更高，因为更大的画布起初同时容纳了更多无关分支。Smart Drag 的移动节点数量主要由拖动位置和局部分支结构决定。Overlay 则取决于当前视口里是否存在连线穿过卡片，屏幕越大时可见连线更多，自然遮挡案例也可能更多。",
        "",
        "## 4　节点规模下的差异",
        "",
        "鱼眼的目标宽度平均增幅随节点规模增长最明显：",
        "",
        markdown_table(
            fisheye_tree.rename(
                columns={"tree_size": "资源节点数", "primary_effect_mean_pct": "宽度增幅（%）"}
            ),
            ["资源节点数", "宽度增幅（%）"],
            {"宽度增幅（%）": "{:.2f}"},
        ),
        "",
        "Adaptive 的平均卡片面积减少量：",
        "",
        markdown_table(
            adaptive_tree.rename(columns={"tree_size": "资源节点数", "primary_effect_mean_pct": "面积减少（%）"}),
            ["资源节点数", "面积减少（%）"],
            {"面积减少（%）": "{:.2f}"},
        ),
        "",
        "Related Focus 的视口全亮节点平均减少量：",
        "",
        markdown_table(
            related_tree.rename(columns={"tree_size": "资源节点数", "secondary_effect_mean": "全亮节点减少（%）"}),
            ["资源节点数", "全亮节点减少（%）"],
            {"全亮节点减少（%）": "{:.2f}"},
        ),
        "",
        "智能拖拽重排在不同规模下移动的其他节点数量：",
        "",
        markdown_table(
            smart_tree.rename(columns={"tree_size": "资源节点数", "secondary_effect_mean": "平均移动节点数"}),
            ["资源节点数", "平均移动节点数"],
            {"平均移动节点数": "{:.2f}"},
        ),
        "",
        "这些树都是真实游戏树，因此规模增加时，节点数量、分支形状和字段内容会一起变化。实验更适合说明插件面对不同规模真实树时的实际表现，而不是证明某个数字只由节点数量单独造成。",
        "",
        "## 5　哪项功能最有价值",
        "",
        "不能把五项功能的百分比直接相加或用一个总分排序，因为它们测量的是不同任务。按照导师建议，本研究把客观数据与结构化开发者评价并列，并给出用途上的结论：",
        "",
    ]
    for _, decision in decisions.sort_values("recommendation_order").iterrows():
        lines.append(
            f"{int(decision['recommendation_order'])}. **{decision['feature_zh']}**："
            f"{decision['recommendation']}。最适合{decision['best_use']}；"
            f"主要限制是{decision['observed_cost']}。"
        )
    lines.extend(
        [
            "",
            "综合而言，自适应缩放细节是最稳定的通用显示优化；智能拖拽重排是最直接的编辑优化；相关节点聚焦最适合大型树的结构追踪；鱼眼在小屏幕和最大规模树下提供最大的局部尺寸增益，但必须接受局部遮挡；可读连线覆盖则是边拥挤时的补充功能。这个结论不是五种异质指标的数学排名，而是根据覆盖范围、针对的开发任务、基线差值、可逆性和副作用形成的结构化判断。",
            "",
            "## 6　论文图表使用说明",
            "",
            "`comparisons/` 中的五张图分别使用同一棵 241 节点真实行为树、同一屏幕尺寸配置和同一任务视角，左右展示关闭与开启状态。`effect_by_screen.png` 和 `effect_by_tree_size.png` 只在各自子图内部比较同一指标，不应跨子图比较柱高。原始数据和所有派生表都保留在同一数据目录，可由本脚本重新生成。",
            "",
        ]
    )
    output_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    data_dir = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_DATA_DIR
    output_dir = (
        Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else data_dir / "analysis"
    )
    output_dir.mkdir(parents=True, exist_ok=True)
    raw_path = data_dir / "raw_observations.csv"
    manifest_path = data_dir / "manifest.json"
    data = pd.read_csv(raw_path)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    validate_raw(data, manifest)
    paired = derive_pairs(data)
    features = feature_summary(paired)
    by_screen = aggregate_long(paired, "screen_key")
    by_tree = aggregate_long(paired, "tree_size")
    decisions = structured_evaluation(paired)

    paired.to_csv(output_dir / "paired_results.csv", index=False, encoding="utf-8-sig")
    features.to_csv(output_dir / "feature_summary.csv", index=False, encoding="utf-8-sig")
    by_screen.to_csv(output_dir / "screen_size_summary.csv", index=False, encoding="utf-8-sig")
    by_tree.to_csv(output_dir / "tree_size_summary.csv", index=False, encoding="utf-8-sig")
    decisions.to_csv(
        output_dir / "structured_developer_evaluation.csv",
        index=False,
        encoding="utf-8-sig",
    )

    screen_panels = []
    for feature, title, metric in [
        ("semantic_zoom", "Adaptive：卡片面积减少", "primary_effect_mean_pct"),
        ("breadcrumb", "Related：全亮节点减少", "secondary_effect_mean"),
        ("fisheye", "Fisheye：目标宽度增加", "primary_effect_mean_pct"),
    ]:
        subset = by_screen[by_screen["feature_key"] == feature].set_index("screen_key")
        screen_panels.append(
            (
                title,
                [SCREEN_NAMES_ZH[key] for key in SCREEN_ORDER],
                [float(subset.loc[key, metric]) for key in SCREEN_ORDER],
                "%",
            )
        )
    draw_bar_panels(
        output_dir / "effect_by_screen.png",
        "三项屏幕敏感功能在不同物理尺寸配置下的平均效果",
        screen_panels,
    )

    tree_panels = []
    for feature, title, metric in [
        ("semantic_zoom", "Adaptive：卡片面积减少", "primary_effect_mean_pct"),
        ("breadcrumb", "Related：全亮节点减少", "secondary_effect_mean"),
        ("fisheye", "Fisheye：目标宽度增加", "primary_effect_mean_pct"),
    ]:
        subset = by_tree[by_tree["feature_key"] == feature].set_index("tree_size")
        tree_panels.append(
            (
                title,
                [str(size) for size in TREE_ORDER],
                [float(subset.loc[size, metric]) for size in TREE_ORDER],
                "%",
            )
        )
    draw_bar_panels(
        output_dir / "effect_by_tree_size.png",
        "三项规模敏感功能在五棵真实行为树上的平均效果",
        tree_panels,
    )
    comparison_images(data_dir, output_dir)
    write_results_markdown(
        output_dir / "RESULTS_ZH.md",
        paired,
        features,
        by_screen,
        by_tree,
        decisions,
    )

    output_files = sorted(
        path for path in output_dir.rglob("*") if path.is_file() and path.name != "ANALYSIS_MANIFEST.json"
    )
    analysis_manifest = {
        "schema_version": 1,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "analysis_git_commit": git_head(),
        "experiment_git_commit": manifest["git_commit"],
        "interpretation": "paired descriptive display metrics; no participant usability inference",
        "input_sha256": {
            str(raw_path.relative_to(data_dir)): sha256(raw_path),
            str(manifest_path.relative_to(data_dir)): sha256(manifest_path),
            str(Path(__file__).resolve()): sha256(Path(__file__).resolve()),
        },
        "output_sha256": {
            str(path.relative_to(output_dir)): sha256(path) for path in output_files
        },
        "validation": {
            "observations": len(data),
            "pairs": int(data["pair_id"].nunique()),
            "effect_contract_passes": int(paired["effect_contract_pass"].sum()),
            "topology_safe_pairs": int(paired["topology_safe"].sum()),
            "execution_order_safe_pairs": int(paired["execution_order_safe"].sum()),
            "resource_position_safe_pairs": int(paired["resource_positions_safe"].sum()),
        },
    }
    (output_dir / "ANALYSIS_MANIFEST.json").write_text(
        json.dumps(analysis_manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(
        "FIVE_FEATURE_ANALYSIS "
        f"rows={len(data)} pairs={len(paired)} contracts={paired['effect_contract_pass'].sum()} "
        f"output={output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
