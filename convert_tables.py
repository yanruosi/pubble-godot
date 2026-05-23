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
OUT_DIR = os.path.join(SCRIPT_DIR, "data")

# 表基名（不含扩展名） -> 输出 json 文件名、跳过的「表头后说明行」数量（见 data_src/00_表头约定.txt）
# skip_meta_rows：除第 1 行英文字段名外，再跳过后续几行（类型行+中文说明行=2）
TABLES = [
    # chapters：删列/缺列后果见 data_src/00_表头约定.txt「chapters 字段」；导出时 _validate_chapters_records 会告警。
    {
        "base": "chapters",
        "out": "chapters.json",
        "skip_meta_rows": 2,
        "int_cols": ["id", "order", "icon_id", "condition_id"],
        "float_cols": [],
    },
    {
        "base": "conditions",
        "out": "conditions.json",
        "skip_meta_rows": 2,
        "int_cols": ["id", "type", "param"],
        "float_cols": [],
        # 表里可有 editor_note 等策划列，不进游戏 JSON
        "export_cols": ["id", "type", "param", "txt"],
    },
    {
        "base": "levels",
        "out": "levels.json",
        "skip_meta_rows": 2,
        "int_cols": [
            "chapter_id",
            "order",
            "cheer_reward",
            "unlock_condition_id",
            "codex_unlock_id",
        ],
        "float_cols": [],
    },
    {
        "base": "bgm",
        "out": "bgm.json",
        "skip_meta_rows": 2,
        "int_cols": ["loop"],
        "float_cols": ["volume_linear"],
    },
    {
        "base": "effects",
        "out": "effects.json",
        "skip_meta_rows": 2,
        "int_cols": [],
        "float_cols": [],
    },
    {
        "base": "feed_posts",
        "out": "feed_posts.json",
        "skip_meta_rows": 2,
        "int_cols": ["chapter_id"],
        "float_cols": [],
    },
]

# 单关配表：data_src/levels/{level_id}/*.csv -> data/levels/{level_id}/*.json
LEVELS_PACK_SRC = os.path.join(SRC_DIR, "levels")
LEVELS_PACK_OUT = os.path.join(OUT_DIR, "levels")

LEVEL_PACK_TABLES = [
    {
        "base": "level",
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
        "out": "vocab.json",
        "skip_meta_rows": 2,
        "int_cols": [],
        "float_cols": [],
        "export_cols": None,
    },
    {
        "base": "hotspots",
        "out": "hotspots.json",
        "skip_meta_rows": 2,
        "int_cols": ["x", "y", "width", "height", "z_order", "once_only", "hide_question_only"],
        "float_cols": [],
        "export_cols": None,
    },
    {
        "base": "slots",
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


def _find_source_file(base: str, directory: str) -> str | None:
    # 同基名多格式并存时：优先用 .csv（策划最常改）；否则取最近修改的那个
    exts = [".csv", ".xlsx", ".xlsm", ".xls"]
    paths: list[str] = []
    for ext in exts:
        p = os.path.join(directory, base + ext)
        if os.path.isfile(p):
            paths.append(p)
    if not paths:
        return None
    csv_path = os.path.join(directory, base + ".csv")
    if csv_path in paths:
        return csv_path
    return max(paths, key=lambda p: os.path.getmtime(p))


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
            path = _find_source_file(entry["base"], pack_src)
            if not path:
                print(f"[跳过] {pack_id}/{entry['base']}.(csv|xlsx|xls) 不存在")
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

    path = src_path or _find_source_file(base, SRC_DIR)
    if not path:
        print(f"[跳过] 未找到表文件: {base}.(csv|xlsx|xls) 于 {SRC_DIR}")
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
    entry = next((t for t in TABLES if t["base"] == stem), None)
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
