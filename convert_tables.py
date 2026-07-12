#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将 data_src 下的配表转为 Godot 使用的 res://data/*.json
支持：.csv / .xlsx / .xls（同一表基名多格式并存时，取「最近修改」的一个）

依赖：pip install pandas openpyxl
旧版 .xls 另需：pip install xlrd

用法：
  python convert_tables.py              # 转换配置里全部表
  python convert_tables.py 某路径.xlsx  # 只转换拖入/指定的文件
"""

from __future__ import annotations

import json
import os
import re
import sys
from typing import Any

import pandas as pd

# 项目目录（本脚本所在目录）
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(SCRIPT_DIR, "data_src")
GLOBAL_XLSX_DIR = os.path.join(SRC_DIR, "xlsx表")
OUT_DIR = os.path.join(SCRIPT_DIR, "data")

# 表基名（不含扩展名） -> 输出 json 文件名、跳过的「表头后说明行」数量（见 data_src/00_表头约定.txt）
# src：xlsx表/ 下的中文文件名（不含扩展名）；转表时读中文名，输出仍用 base 对应英文 json
# skip_meta_rows：除第 1 行英文字段名外，再跳过后续几行（类型行+中文说明行=2）
TABLES = [
    {
        "base": "chapters",
        "src": "章节表",
        "out": "chapters.json",
        "skip_meta_rows": 2,
        "int_cols": ["id", "order", "icon_id", "condition_id"],
        "float_cols": [],
    },
    {
        "base": "conditions",
        "src": "条件表",
        "out": "conditions.json",
        "skip_meta_rows": 2,
        "int_cols": ["id", "type", "param"],
        "float_cols": [],
        # 表里可有 editor_note 等策划列，不进游戏 JSON
        "export_cols": ["id", "type", "param", "txt"],
    },
    {
        "base": "levels",
        "src": "关卡表",
        "out": "levels.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "chapter_id",
            "order",
            "cheer_reward",
            "unlockconditionid",
            "codex_unlock_id",
            "grantstars",
            "grantfp",
            "grantintel",
            "unlockpostcount",
        ],
        "float_cols": [],
    },
    {
        "base": "bgm",
        "src": "背景音乐表",
        "out": "bgm.json",
        "skip_meta_rows": 2,
        "int_cols": ["loop"],
        "float_cols": ["volume_linear"],
    },
    {
        "base": "effects",
        "src": "特效表",
        "out": "effects.json",
        "skip_meta_rows": 2,
        "int_cols": [],
        "float_cols": [],
    },
    {
        "base": "feed_posts",
        "src": "艺人帖表",
        "out": "feed_posts.json",
        "skip_meta_rows": 2,
        "int_cols": ["type", "condition_id"],
        "float_cols": [],
    },
    {
        "base": "items",
        "src": "道具表",
        "out": "items.json",
        "skip_meta_rows": 2,
        "int_cols": ["itemid", "category", "stacklimit", "tradable", "winrateboost"],
        "float_cols": [],
    },
    {
        "base": "post_templates",
        "src": "投稿模板表",
        "out": "post_templates.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "posttype",
            "tabtype",
            "conditionid",
            "weightlow",
            "weightmid",
            "weighthigh",
            "durationsec",
            "maxparallel",
            "grantfp",
            "grantintel",
            "grantstars",
            "opiniondelta",
        ],
        "float_cols": [],
    },
    {
        "base": "activities",
        "src": "活动表",
        "out": "activities.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "category",
            "conditionid",
            "costfp",
            "costitemid",
            "costitemcount",
            "outputposttype1",
            "outputposttype2",
            "drawcount",
            "refreshmarket",
            "tutorialonly",
            "sort",
            "stexplow",
            "stexpmid",
            "stexphigh",
            "opinionlock",
            "winrate",
        ],
        "float_cols": [],
    },
    {
        "base": "activity_events",
        "src": "活动结算事件表",
        "out": "activity_events.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "activityid",
            "weightlow",
            "weightmid",
            "weighthigh",
        ],
        "float_cols": [],
    },
    {
        "base": "fan_levels",
        "src": "会员等级表",
        "out": "fan_levels.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "level",
            "costitemcategory",
            "costitemcount",
            "unlockconditionid",
        ],
        "float_cols": ["shopdiscount"],
    },
    {
        "base": "intel_levels",
        "src": "情报等级表",
        "out": "intel_levels.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "level",
            "thresholdintel",
            "unlockconditionid",
            "grantfp",
            "grantstars",
        ],
        "float_cols": [],
    },
    {
        "base": "station_levels",
        "src": "站子等级表",
        "out": "station_levels.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "level",
            "thresholdexp",
            "rewarditemid",
            "rewarditemcount",
            "idolkara",
        ],
        "float_cols": [],
    },
    {
        "base": "shop_offers",
        "src": "商城上架表",
        "out": "shop_offers.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "offerid",
            "currencytype",
            "price",
            "itemid",
            "conditionid",
            "stocklimit",
            "shoptab",
            "tutorialonly",
        ],
        "float_cols": [],
    },
    {
        "base": "hotsearch_pool",
        "src": "热搜文本池表",
        "out": "hotsearch_pool.json",
        "skip_meta_rows": 2,
        "int_cols": ["opiniontier", "weight"],
        "float_cols": [],
    },
    {
        "base": "market_catalog",
        "src": "中转站目录表",
        "out": "market_catalog.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "itemid",
            "tradetype",
            "pricelow",
            "pricemid",
            "pricehigh",
            "conditionid",
            "refreshonactivity",
        ],
        "float_cols": [],
    },
    {
        "base": "banner_config",
        "src": "banner_config",
        "out": "banner_config.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "tabtype",
            "activedurationsec",
            "activegranttype",
            "activegrantamt",
            "offlinedurationsec",
            "offlinemaxsec",
        ],
        "float_cols": [],
    },
    {
        "base": "opinion_config",
        "src": "舆论配置表",
        "out": "opinion_config.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "tierlowmax",
            "tiermidmax",
            "tierhighmin",
            "pauseat",
            "resumeat",
            "capat",
            "capresetto",
            "capinfluxcount",
        ],
        "float_cols": [],
    },
]

# 中文/英文文件名 -> TABLES 条目（供拖入单文件转表时使用）
TABLE_BY_STEM: dict[str, dict[str, Any]] = {}
for _entry in TABLES:
    TABLE_BY_STEM[_entry["base"]] = _entry
    if _entry.get("src"):
        TABLE_BY_STEM[_entry["src"]] = _entry

# 单关配表：data_src/levels/{level_id}/*.csv -> data/levels/{level_id}/*.json
LEVELS_PACK_SRC = os.path.join(SRC_DIR, "levels")
LEVELS_PACK_OUT = os.path.join(OUT_DIR, "levels")

LEVEL_PACK_TABLES = [
    {
        "base": "level",
        "src": "关卡配置表",
        "out": "level.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "vocab_total",
            "slot_count",
            "slot1_enabled",
            "slot2_enabled",
            "slot3_enabled",
            "slot4_enabled",
            "art_base_width",
            "art_base_height",
            "hint_free_count",
        ],
        "float_cols": [],
        "export_cols": None,
    },
    {
        "base": "vocab",
        "src": "词条表",
        "out": "vocab.json",
        "skip_meta_rows": 2,
        "int_cols": [],
        "float_cols": [],
        "export_cols": None,
    },
    {
        "base": "hotspots",
        "src": "热点表",
        "out": "hotspots.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "x",
            "y",
            "width",
            "height",
            "z_order",
            "once_only",
            "hide_question_only",
            "dismiss_on_outside_click",
            "coord_base_width",
            "coord_base_height",
        ],
        "float_cols": [],
        "export_cols": None,
    },
    {
        "base": "slots",
        "src": "槽位表",
        "out": "slots.json",
        "skip_meta_rows": 2,
        "int_cols": ["order", "required"],
        "float_cols": [],
        "export_cols": None,
    },
]

RESOURCE_PATH_COLS = frozenset({"scene_image", "icon", "asset"})

TYPE_ROW_TOKENS = frozenset(
    {"string", "str", "int", "integer", "float", "number", "double", "bool", "boolean"}
)


def _strip_cell(x: Any) -> str:
    if x is None or (isinstance(x, float) and pd.isna(x)):
        return ""
    return str(x).strip()


def _parse_int(v: Any) -> int:
    s = _strip_cell(v)
    if s == "":
        return 0
    try:
        f = float(s)
        if abs(f - round(f)) < 1e-9:
            return int(round(f))
        return int(f)
    except ValueError:
        return 0


def _parse_float(v: Any) -> float:
    s = _strip_cell(v)
    if s == "":
        return 0.0
    try:
        return float(s)
    except ValueError:
        return 0.0


def _normalize_resource_path(v: Any) -> str:
    path = _strip_cell(v).replace("\\", "/")
    if path == "" or path.startswith("res://") or path.startswith("user://"):
        return path

    project_root = SCRIPT_DIR.replace("\\", "/").rstrip("/")
    if path.startswith(project_root + "/"):
        return "res://" + path[len(project_root) + 1 :]
    return path


def _normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df.columns = [str(c).strip().lstrip("\ufeff") for c in df.columns]
    df = df.dropna(how="all")
    return df


def _read_csv(path: str, skip_meta_rows: int) -> pd.DataFrame:
    skiprows = list(range(1, 1 + skip_meta_rows)) if skip_meta_rows > 0 else None
    df = pd.read_csv(path, header=0, skiprows=skiprows, dtype=str, encoding="utf-8-sig")
    return _normalize_columns(df)


def _read_excel(path: str, skip_meta_rows: int) -> pd.DataFrame:
    skiprows = list(range(1, 1 + skip_meta_rows)) if skip_meta_rows > 0 else None
    ext = os.path.splitext(path)[1].lower()
    engine = None
    if ext == ".xlsx":
        engine = "openpyxl"
    elif ext == ".xls":
        engine = "xlrd"
    try:
        df = pd.read_excel(
            path,
            sheet_name=0,
            header=0,
            skiprows=skiprows,
            dtype=str,
            engine=engine,
        )
    except ImportError as e:
        need = "openpyxl（.xlsx）" if ext == ".xlsx" else "xlrd（.xls）"
        raise SystemExit(f"读取 Excel 失败，请安装: pip install pandas {need}\n{e}") from e
    return _normalize_columns(df)


def _load_dataframe(path: str, skip_meta_rows: int) -> pd.DataFrame:
    ext = os.path.splitext(path)[1].lower()
    if ext == ".csv":
        return _read_csv(path, skip_meta_rows)
    if ext in (".xlsx", ".xls", ".xlsm"):
        try:
            return _read_excel(path, skip_meta_rows)
        except Exception as e:
            # 常见误操作：把 CSV 另存为/重命名为 .xls，Excel 引擎会报 BOF 错误
            msg = str(e).lower()
            if ext == ".xls" and (
                "bof" in msg or "unsupported format" in msg or "corrupt" in msg
            ):
                print(f"[提示] {os.path.basename(path)} 按 Excel 读取失败，改按 CSV 解析（若为真 xls 请恢复扩展名或安装 xlrd）")
                return _read_csv(path, skip_meta_rows)
            raise
    raise ValueError(f"不支持的扩展名: {ext}")


def _guess_skip_meta_rows(path: str) -> int:
    """未在 TABLES 注册的文件：若第 2 行像「类型行」，则跳过 2 行说明。"""
    ext = os.path.splitext(path)[1].lower()
    line2 = ""
    try:
        if ext == ".csv":
            with open(path, encoding="utf-8-sig") as fh:
                fh.readline()
                line2 = fh.readline()
        else:
            df = pd.read_excel(path, sheet_name=0, header=None, nrows=2, dtype=str)
            if df.shape[0] >= 2:
                line2 = ",".join(_strip_cell(x) for x in df.iloc[1].tolist())
    except Exception:
        return 0
    parts = [p.strip().lower() for p in re.split(r",|\t", line2) if p.strip()]
    if not parts:
        return 0
    hits = sum(1 for p in parts if p in TYPE_ROW_TOKENS)
    if hits >= max(2, len(parts) // 2):
        return 2
    return 0


def _row_to_dict(
    row: pd.Series,
    int_cols: set[str],
    float_cols: set[str],
) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for col in row.index:
        key = str(col).strip()
        if key == "" or key.startswith("Unnamed"):
            continue
        val = row[col]
        if key in int_cols:
            out[key] = _parse_int(val)
        elif key in float_cols:
            out[key] = _parse_float(val)
        elif key in RESOURCE_PATH_COLS or key.endswith("_path"):
            out[key] = _normalize_resource_path(val)
        else:
            out[key] = _strip_cell(val)
    return out


def _filter_export_cols(obj: dict[str, Any], export_cols: list[str] | None) -> dict[str, Any]:
    if not export_cols:
        return obj
    ordered: dict[str, Any] = {}
    for key in export_cols:
        if key in obj:
            ordered[key] = obj[key]
    return ordered


def _dataframe_to_records(
    df: pd.DataFrame,
    int_cols: list[str],
    float_cols: list[str],
    export_cols: list[str] | None = None,
) -> list[dict[str, Any]]:
    ic = set(int_cols)
    fc = set(float_cols)
    records: list[dict[str, Any]] = []
    for _, row in df.iterrows():
        obj = _row_to_dict(row, ic, fc)
        obj = _filter_export_cols(obj, export_cols)
        if not any(str(v) != "" for v in obj.values() if not isinstance(v, (int, float))):
            if not any(isinstance(v, (int, float)) and v != 0 for v in obj.values()):
                continue
        records.append(obj)
    return records


def _validate_chapters_records(records: list[dict[str, Any]]) -> None:
    """导出后校验：缺列/删字段时给出与 Godot 逻辑一致的提示。"""
    if not records:
        print("[警告] chapters 导出 0 条记录")
        return
    for rec in records:
        rid = rec.get("id", "?")
        if "id" not in rec:
            print(f"[警告] chapters 记录缺少 id 字段: {rec}")
            continue
        try:
            iid = int(rec["id"])
        except (TypeError, ValueError):
            iid = 0
        if iid <= 0:
            print(f"[警告] chapters id 无效（需为正整数）: {rec}")
        if "order" not in rec:
            print(f"[警告] chapters id={rid} 缺少 order；主页卡牌排序可能不稳定")
        if "condition_id" not in rec:
            print(
                f"[警告] chapters id={rid} 导出缺少 condition_id（表头列缺失或未对齐）；"
                "选关页「解锁章节」将显示为「解锁章节」且不扣应援棒。"
            )


def _source_stems(entry: dict[str, Any]) -> list[str]:
    """优先中文文件名，再回退英文 base。"""
    stems: list[str] = []
    src = entry.get("src")
    if src:
        stems.append(str(src))
    stems.append(entry["base"])
    return stems


def _find_source_file_for_entry(entry: dict[str, Any], directory: str) -> str | None:
    # 全局表优先 data_src/xlsx表/；单关配表仍用传入 directory
    search_dirs = [directory]
    if directory == SRC_DIR and os.path.isdir(GLOBAL_XLSX_DIR):
        search_dirs = [GLOBAL_XLSX_DIR, SRC_DIR]
    exts = [".csv", ".xlsx", ".xlsm", ".xls"]
    for search_dir in search_dirs:
        for stem in _source_stems(entry):
            paths: list[str] = []
            for ext in exts:
                p = os.path.join(search_dir, stem + ext)
                if os.path.isfile(p):
                    paths.append(p)
            if not paths:
                continue
            csv_path = os.path.join(search_dir, stem + ".csv")
            if csv_path in paths:
                return csv_path
            return max(paths, key=lambda p: os.path.getmtime(p))
    return None


def _find_source_file(base: str, directory: str) -> str | None:
    entry = TABLE_BY_STEM.get(base)
    if entry is not None:
        return _find_source_file_for_entry(entry, directory)
    exts = [".csv", ".xlsx", ".xlsm", ".xls"]
    for search_dir in ([directory] if directory != SRC_DIR or not os.path.isdir(GLOBAL_XLSX_DIR)
                       else [GLOBAL_XLSX_DIR, SRC_DIR]):
        paths: list[str] = []
        for ext in exts:
            p = os.path.join(search_dir, base + ext)
            if os.path.isfile(p):
                paths.append(p)
        if not paths:
            continue
        csv_path = os.path.join(search_dir, base + ".csv")
        if csv_path in paths:
            return csv_path
        return max(paths, key=lambda p: os.path.getmtime(p))
    return None


def _ensure_dirs() -> None:
    os.makedirs(SRC_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)


def convert_level_packs() -> tuple[int, int]:
    """转换 data_src/levels/{level_id}/ 下各关四表。"""
    if not os.path.isdir(LEVELS_PACK_SRC):
        print(f"[跳过] 未找到单关配表目录: {LEVELS_PACK_SRC}")
        return 0, 0

    pack_ids = sorted(
        name
        for name in os.listdir(LEVELS_PACK_SRC)
        if os.path.isdir(os.path.join(LEVELS_PACK_SRC, name))
    )
    if not pack_ids:
        print(f"[跳过] {LEVELS_PACK_SRC} 下无子目录")
        return 0, 0

    total = 0
    ok = 0
    for pack_id in pack_ids:
        pack_src = os.path.join(LEVELS_PACK_SRC, pack_id)
        pack_out = os.path.join(LEVELS_PACK_OUT, pack_id)
        os.makedirs(pack_out, exist_ok=True)
        for entry in LEVEL_PACK_TABLES:
            total += 1
            out_path = os.path.join(pack_out, entry["out"])
            path = _find_source_file_for_entry(entry, pack_src)
            if not path:
                names = " / ".join(_source_stems(entry))
                print(f"[跳过] {pack_id}/{names}.(csv|xlsx|xls) 不存在")
                continue
            try:
                df = _load_dataframe(path, int(entry.get("skip_meta_rows", 0)))
            except Exception as e:
                print(f"[失败] 读取 {path}: {e}")
                continue
            records = _dataframe_to_records(
                df,
                list(entry.get("int_cols", [])),
                list(entry.get("float_cols", [])),
                entry.get("export_cols"),
            )
            with open(out_path, "w", encoding="utf-8") as fh:
                json.dump(records, fh, ensure_ascii=False, indent=2)
                fh.write("\n")
            print(
                f"[完成] levels/{pack_id}/{os.path.basename(path)} "
                f"-> {out_path} （{len(records)} 条）"
            )
            ok += 1
    return total, ok


def convert_one_entry(entry: dict[str, Any], src_path: str | None = None) -> bool:
    base = entry["base"]
    out_name = entry["out"]
    skip = int(entry.get("skip_meta_rows", 0))
    int_cols = list(entry.get("int_cols", []))
    float_cols = list(entry.get("float_cols", []))
    export_cols: list[str] | None = entry.get("export_cols")
    if export_cols is not None and len(export_cols) == 0:
        export_cols = None

    path = src_path or _find_source_file_for_entry(entry, SRC_DIR)
    if not path:
        names = " / ".join(_source_stems(entry))
        print(f"[跳过] 未找到表文件: {names}.(csv|xlsx|xls) 于 {GLOBAL_XLSX_DIR} 或 {SRC_DIR}")
        return False

    try:
        df = _load_dataframe(path, skip)
    except Exception as e:
        print(f"[失败] 读取 {path}: {e}")
        return False

    records = _dataframe_to_records(df, int_cols, float_cols, export_cols)
    if base == "chapters":
        _validate_chapters_records(records)
    out_path = os.path.join(OUT_DIR, out_name)
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(records, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    print(f"[完成] {os.path.basename(path)} -> {out_path} （{len(records)} 条）")
    return True


def convert_path(arg_path: str) -> bool:
    path = os.path.abspath(arg_path)
    if not os.path.isfile(path):
        print(f"[失败] 不是文件: {path}")
        return False

    stem = os.path.splitext(os.path.basename(path))[0]
    entry = TABLE_BY_STEM.get(stem)
    if entry is None:
        skip = _guess_skip_meta_rows(path)
        entry = {
            "base": stem,
            "out": stem + ".json",
            "skip_meta_rows": skip,
            "int_cols": [],
            "float_cols": [],
            "export_cols": None,
        }
        print(f"[提示] 未在 TABLES 注册，按 stem={stem} -> {entry['out']}，skip_meta_rows={skip}")

    return convert_one_entry(entry, src_path=path)


def main() -> None:
    _ensure_dirs()
    argv = [a for a in sys.argv[1:] if a.strip()]

    if argv:
        ok = 0
        for a in argv:
            if convert_path(a):
                ok += 1
        print(f"指定文件处理完毕：成功 {ok}/{len(argv)}")
        return

    total = 0
    ok = 0
    for entry in TABLES:
        total += 1
        if convert_one_entry(entry):
            ok += 1
    pack_total, pack_ok = convert_level_packs()
    total += pack_total
    ok += pack_ok
    print(f"全部处理结束：成功 {ok}/{total}")


if __name__ == "__main__":
    main()
