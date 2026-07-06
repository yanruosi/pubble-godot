#!/usr/bin/env python3
"""M1 策划前置：创建 banner_config.xlsx，更新关卡/艺人帖/道具/商城/签售活动。"""
from __future__ import annotations

import json
import os
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
XLSX = ROOT / "data_src" / "xlsx表"
DATA = ROOT / "data"


def write_xlsx(name: str, rows: list[dict], columns: list[str]) -> None:
    path = XLSX / f"{name}.xlsx"
    df = pd.DataFrame(rows, columns=columns)
    # 类型行 + 中文说明行（与现有表约定一致）
    type_row = {c: "int" for c in columns}
    cn_row = {
        "tabtype": "页签类型",
        "activedurationsec": "在线满格秒数",
        "activegranttype": "满格奖励货币类型",
        "activegrantamt": "满格奖励数量",
        "offlinedurationsec": "离线折算秒数",
        "offlinemaxsec": "离线结算上限秒",
        "levelid": "关卡id",
        "grantstars": "通关星星",
        "grantfp": "通关积分",
        "grantintel": "通关情报",
        "post_id": "帖子id",
        "condition_id": "条件id",
        "itemid": "道具id",
        "name": "名称",
        "category": "类型",
        "stacklimit": "堆叠上限",
        "tradable": "可交易",
        "offerid": "上架id",
        "currencytype": "货币类型",
        "price": "价格",
        "stocklimit": "库存上限",
        "shoptab": "商城页签",
        "tutorialonly": "教程专用",
        "activityid": "活动id",
        "category": "活动类型",
        "conditionid": "条件id",
        "costfp": "消耗积分",
        "outputposttype1": "产出帖类型1",
        "drawcount": "抽取数量",
        "sort": "排序",
    }
    with pd.ExcelWriter(path, engine="openpyxl") as w:
        header = pd.DataFrame([{c: c for c in columns}])
        types = pd.DataFrame([{c: type_row.get(c, "str") for c in columns}])
        cn = pd.DataFrame([{c: cn_row.get(c, c) for c in columns}])
        body = df
        pd.concat([header, types, cn, body], ignore_index=True).to_excel(
            w, index=False, header=False
        )
    print(f"Wrote {path}")


def patch_levels_json() -> None:
    path = DATA / "levels.json"
    rows = json.loads(path.read_text(encoding="utf-8"))
    for row in rows:
        if row.get("levelid") == "ch1_l01":
            row["grantstars"] = 3
            row["grantfp"] = 80
            row["grantintel"] = 5
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Patched levels.json ch1_l01 grants")


def patch_feed_posts_json() -> None:
    path = DATA / "feed_posts.json"
    rows = json.loads(path.read_text(encoding="utf-8"))
    for row in rows:
        if row.get("post_id") == "ch1_1_post":
            row["condition_id"] = 4  # type5 intel >= 1
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Patched feed_posts.json condition_id")


def write_banner_json() -> None:
    rows = [
        {
            "tabtype": 0,
            "activedurationsec": 30,
            "activegranttype": 22,
            "activegrantamt": 10,
            "offlinedurationsec": 150,
            "offlinemaxsec": 28800,
        },
        {
            "tabtype": 903,
            "activedurationsec": 30,
            "activegranttype": 24,
            "activegrantamt": 5,
            "offlinedurationsec": 150,
            "offlinemaxsec": 28800,
        },
        {
            "tabtype": 904,
            "activedurationsec": 30,
            "activegranttype": 23,
            "activegrantamt": 1,
            "offlinedurationsec": 300,
            "offlinemaxsec": 28800,
        },
    ]
    (DATA / "banner_config.json").write_text(
        json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    cols = [
        "tabtype",
        "activedurationsec",
        "activegranttype",
        "activegrantamt",
        "offlinedurationsec",
        "offlinemaxsec",
    ]
    write_xlsx("banner_config", rows, cols)


def write_items_shop() -> None:
    items = [
        {
            "itemid": 1001,
            "name": "教程普通专辑",
            "category": 1,
            "stacklimit": 99,
            "tradable": 0,
        }
    ]
    (DATA / "items.json").write_text(
        json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    write_xlsx(
        "道具表",
        items,
        ["itemid", "name", "category", "stacklimit", "tradable"],
    )
    offers = [
        {
            "offerid": 1,
            "name": "教程专辑",
            "currencytype": 22,
            "price": 50,
            "itemid": 1001,
            "conditionid": 0,
            "stocklimit": 0,
            "shoptab": 1,
            "tutorialonly": 1,
        }
    ]
    (DATA / "shop_offers.json").write_text(
        json.dumps(offers, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    write_xlsx(
        "商城上架表",
        offers,
        [
            "offerid",
            "name",
            "currencytype",
            "price",
            "itemid",
            "conditionid",
            "stocklimit",
            "shoptab",
            "tutorialonly",
        ],
    )


def add_sign_activity() -> None:
    path = DATA / "activities.json"
    rows = json.loads(path.read_text(encoding="utf-8"))
    has_sign = any(int(r.get("category", 0)) == 3 for r in rows)
    if not has_sign:
        rows.append(
            {
                "activityid": "7",
                "name": "教程签售",
                "category": 3,
                "conditionid": 5,
                "costfp": 0,
                "costitemid": 0,
                "costitemcount": 0,
                "outputposttype1": 101,
                "outputposttype2": 0,
                "drawcount": 1,
                "refreshmarket": 0,
                "tutorialonly": 1,
                "sort": 7,
                "stexplow": 10,
                "stexpmid": 20,
                "stexphigh": 30,
                "opinionlock": 0,
            }
        )
        path.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
        print("Added tutorial sign activity to activities.json")


def main() -> None:
    write_banner_json()
    patch_levels_json()
    patch_feed_posts_json()
    write_items_shop()
    add_sign_activity()
    print("M1 data setup done.")


if __name__ == "__main__":
    main()
