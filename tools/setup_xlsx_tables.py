#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：在 data_src/xlsx表/ 生成全部全局配表 xlsx。"""

from __future__ import annotations

import json
import os
import sys

try:
    from openpyxl import Workbook
except ImportError:
    sys.exit("请先安装: pip install openpyxl")

SCRIPT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XLSX_DIR = os.path.join(SCRIPT_DIR, "data_src", "xlsx表")
DATA_DIR = os.path.join(SCRIPT_DIR, "data")
DATA_SRC_DIR = os.path.join(SCRIPT_DIR, "data_src")


def write_table(filename: str, headers: list[str], types: list[str], cn: list[str], rows: list[list]) -> None:
    os.makedirs(XLSX_DIR, exist_ok=True)
    wb = Workbook()
    ws = wb.active
    ws.append(headers)
    ws.append(types)
    ws.append(cn)
    for row in rows:
        ws.append(row)
    path = os.path.join(XLSX_DIR, filename)
    wb.save(path)
    print(f"[完成] {path} ({len(rows)} 条数据)")


def load_json(name: str) -> list | dict:
    with open(os.path.join(DATA_DIR, name), encoding="utf-8") as fh:
        return json.load(fh)


def main() -> None:
    # --- 1. items ---
    write_table(
        "道具表.xlsx",
        ["itemid", "name", "category", "desc", "stacklimit", "icon", "modelicon", "tradable", "equipslot"],
        ["int", "string", "int", "string", "int", "string", "string", "int", "string"],
        [
            "全局唯一数字编号",
            "道具显示名",
            "类型：1普通专辑/2签售专/3小卡/4娃孙/5潮牌/6活动解锁道具/22饭圈积分/23星星/24情报点",
            "道具描述",
            "单格叠加上限；-1=无限",
            "art/icons 静态帧 id",
            "art/model 模型 id（预留）",
            "0/1 是否可进中转站",
            "空=不可穿戴；填娃孙/小卡/潮牌",
        ],
        [],
    )

    # --- 2. conditions (remove type=1) ---
    conditions = [c for c in load_json("conditions.json") if c.get("type") != 1]
    write_table(
        "条件表.xlsx",
        ["id", "type", "param", "txt", "editor_note"],
        ["int", "int", "int", "string", "string"],
        [
            "条件ID",
            "2章节/3上关通关/5情报等级/6粉丝等级/7持有道具",
            "类型对应参数",
            "未满足时展示文案",
            "策划备注（不进游戏）",
        ],
        [
            [c["id"], c["type"], c["param"], c["txt"], ""]
            for c in conditions
        ],
    )

    # --- 3. post_templates ---
    write_table(
        "投稿模板表.xlsx",
        [
            "postid", "posttype", "tabtype", "conditionid", "tier",
            "weightlow", "weightmid", "weighthigh", "uniquekey",
            "title", "text", "avatarpath", "imagepath",
            "durationsec", "maxparallel",
            "grantfp", "grantintel", "grantstars", "opiniondelta",
        ],
        [
            "string", "int", "int", "int", "string",
            "int", "int", "int", "string",
            "string", "string", "string", "string",
            "int", "int",
            "int", "int", "int", "int",
        ],
        [
            "投稿唯一 id",
            "投稿类型数字（枚举待填）",
            "903嫂子站/904我的站子/0广场",
            "进抽取池条件；0=无条件",
            "稀有度 A/B/C",
            "舆论负面档（0-50）抽取权重",
            "舆论正常档（50-80）权重",
            "舆论极好档（80-100）权重",
            "去重键，可空",
            "帖子标题",
            "帖子正文",
            "头像 res:// 路径",
            "配图 res:// 路径",
            "曝光时长秒；0=秒结算",
            "最大并行放置数",
            "收取给饭圈积分",
            "收取给情报点",
            "收取给星星",
            "玩家主动发帖时的舆论值变化（非主动帖填0）",
        ],
        [],
    )

    # --- 4. activities ---
    write_table(
        "活动表.xlsx",
        [
            "activityid", "name", "category", "conditionid",
            "costfp", "costitemid", "costitemcount",
            "outputposttype1", "outputposttype2", "drawcount",
            "refreshmarket", "tutorialonly", "sort",
            "stexplow", "stexpmid", "stexphigh", "opinionlock",
        ],
        [
            "string", "string", "int", "int",
            "int", "int", "int",
            "int", "int", "int",
            "int", "int", "int",
            "int", "int", "int", "int",
        ],
        [
            "活动唯一 id",
            "活动名称",
            "1放置/2线下/3签售",
            "参与门槛；0=无",
            "消耗饭圈积分；0=不扣",
            "消耗道具编号；可空",
            "消耗道具数量",
            "产出投稿类型1",
            "产出投稿类型2；可空",
            "本次结算抽取帖数",
            "结算后刷新中转站 0/1",
            "教程必中 0/1",
            "列表排序",
            "舆论负面档贡献站子经验",
            "舆论正常档贡献站子经验",
            "舆论极好档贡献站子经验",
            "受舆论限制 0/1",
        ],
        [],
    )

    # --- 5. fan_levels ---
    write_table(
        "会员等级表.xlsx",
        ["level", "name", "costitemcategory", "costitemcount", "shopdiscount", "benefitdesc", "unlockconditionid"],
        ["int", "string", "int", "int", "float", "string", "int"],
        [
            "等级数字",
            "等级名称",
            "升级消耗道具类型（items.category）",
            "升级消耗数量",
            "商品折扣率；0=无；0.1=九折",
            "权益展示文案",
            "本等级对应 type6 条件 id",
        ],
        [],
    )

    # --- 6. intel_levels ---
    write_table(
        "情报等级表.xlsx",
        ["level", "name", "thresholdintel", "unlockconditionid", "grantfp", "grantstars"],
        ["int", "string", "int", "int", "int", "int"],
        [
            "等级",
            "名称",
            "所需情报点阈值",
            "对应 type5 条件 id",
            "升级给饭圈积分",
            "升级给星星",
        ],
        [],
    )

    # --- 7. station_levels ---
    write_table(
        "站子等级表.xlsx",
        ["level", "name", "thresholdexp", "rewarditemid", "rewarditemcount", "idolkara", "videocallid"],
        ["int", "string", "int", "int", "int", "int", "string"],
        [
            "等级",
            "名称",
            "所需站子经验阈值",
            "等级奖励道具编号",
            "奖励数量",
            "0普通生咖/1艺人出席生咖",
            "影通事件 id（预留）",
        ],
        [],
    )

    # --- 8. shop_offers ---
    write_table(
        "商城上架表.xlsx",
        [
            "offerid", "currencytype", "price", "itemid", "shopdesc", "shopicon",
            "conditionid", "stocklimit", "shoptab", "tutorialonly",
        ],
        ["string", "int", "int", "int", "string", "string", "int", "int", "int", "int"],
        [
            "上架 id",
            "22饭圈积分/23星星/24情报点",
            "售价",
            "购买后给的道具",
            "商城展示描述",
            "art/icons 展示图",
            "显示条件；0=无条件",
            "-1=无限",
            "1周边售卖/2周边兑换",
            "0/1",
        ],
        [],
    )

    # --- 9. hotsearch_pool ---
    write_table(
        "热搜文本池表.xlsx",
        ["hotid", "opiniontier", "hottext", "weight"],
        ["string", "int", "string", "int"],
        ["热搜 id", "1负面/2正常/3极好", "热搜展示文本", "同档位内随机权重"],
        [],
    )

    # --- 10. market_catalog ---
    write_table(
        "中转站目录表.xlsx",
        [
            "entryid", "itemid", "tradetype",
            "pricelow", "pricemid", "pricehigh",
            "conditionid", "refreshonactivity",
        ],
        ["string", "int", "int", "int", "int", "int", "int", "int"],
        [
            "条目 id",
            "道具编号",
            "1玩家卖出/2玩家买入/3双向",
            "舆论负面档价格 fp",
            "舆论正常档价格 fp",
            "舆论极好档价格 fp",
            "显示条件；0=无条件",
            "0/1 活动结算后刷新此条目",
        ],
        [],
    )

    # --- 11. opinion_config (1 row) ---
    write_table(
        "舆论配置表.xlsx",
        [
            "tierlowmax", "tiermidmax", "tierhighmin",
            "pauseat", "resumeat", "capat", "capresetto", "capinfluxcount",
        ],
        ["int", "int", "int", "int", "int", "int", "int", "int"],
        [
            "负面档上限（50）",
            "正常档上限（80）",
            "极好档下限（80）",
            "活动暂停门槛（0）",
            "活动恢复门槛（10）",
            "封顶触发值（100）",
            "封顶后重置到（50）",
            "封顶涌入嫂子帖数量（3）",
        ],
        [[50, 80, 80, 0, 10, 100, 50, 3]],
    )

    # --- migrate chapters ---
    import csv
    chapters_path = os.path.join(DATA_SRC_DIR, "chapters.csv")
    with open(chapters_path, encoding="utf-8-sig") as fh:
        reader = csv.reader(fh)
        rows = list(reader)
    write_table("章节表.xlsx", rows[0], rows[1], rows[2], rows[3:])

    # --- migrate bgm ---
    bgm_path = os.path.join(DATA_SRC_DIR, "bgm.csv")
    with open(bgm_path, encoding="utf-8-sig") as fh:
        rows = list(csv.reader(fh))
    write_table("背景音乐表.xlsx", rows[0], rows[1], rows[2], rows[3:])

    # --- migrate effects ---
    effects_path = os.path.join(DATA_SRC_DIR, "effects.csv")
    with open(effects_path, encoding="utf-8-sig") as fh:
        rows = list(csv.reader(fh))
    write_table("特效表.xlsx", rows[0], rows[1], rows[2], rows[3:])

    # --- migrate levels + 4 new cols ---
    levels = load_json("levels.json")
    level_headers = [
        "level_id", "chapter_id", "order", "title", "scene_path", "data_dir",
        "cheer_reward", "bgm_id", "unlock_condition_id", "codex_unlock_id", "text2",
        "grantstars", "grantfp", "grantintel", "unlockpostcount",
    ]
    level_types = [
        "string", "int", "int", "string", "string", "string",
        "int", "string", "int", "int", "string",
        "int", "int", "int", "int",
    ]
    level_cn = [
        "关卡唯一ID",
        "章节ID",
        "章节内排序",
        "关卡标题",
        "Godot场景路径",
        "单关配表目录名",
        "应援棒奖励（废弃字段，保留兼容）",
        "背景音乐ID",
        "解锁条件ID",
        "图鉴解锁ID",
        "动态页时间文案",
        "通关给星星",
        "通关给饭圈积分",
        "通关给情报点",
        "通关解锁发帖次数",
    ]
    level_rows = []
    for lv in levels:
        level_rows.append([
            lv.get("level_id", ""),
            lv.get("chapter_id", 0),
            lv.get("order", 0),
            lv.get("title", ""),
            lv.get("scene_path", ""),
            lv.get("data_dir", ""),
            lv.get("cheer_reward", 0),
            lv.get("bgm_id", ""),
            lv.get("unlock_condition_id", 0),
            lv.get("codex_unlock_id", 0),
            lv.get("text2", ""),
            lv.get("grantstars", 0),
            lv.get("grantfp", 0),
            lv.get("grantintel", 0),
            lv.get("unlockpostcount", 0),
        ])
    write_table("关卡表.xlsx", level_headers, level_types, level_cn, level_rows)

    # --- migrate feed_posts ---
    posts = load_json("feed_posts.json")
    fp_headers = [
        "post_id", "type", "condition_id", "level_id", "name", "time", "text",
        "avatar_path", "image_path", "image_path2",
    ]
    fp_types = ["string", "int", "int", "string", "string", "string", "string", "string", "string", "string"]
    fp_cn = [
        "帖子编号", "类型901艺人/902废弃", "可见条件ID", "帖子关编号",
        "显示名", "时间", "正文", "头像", "配图", "配图2",
    ]
    fp_rows = [
        [
            p.get("post_id", ""),
            p.get("type", 0),
            p.get("condition_id", 0),
            p.get("level_id", ""),
            p.get("name", ""),
            p.get("time", ""),
            p.get("text", ""),
            p.get("avatar_path", ""),
            p.get("image_path", ""),
            p.get("image_path2", ""),
        ]
        for p in posts
    ]
    write_table("艺人帖表.xlsx", fp_headers, fp_types, fp_cn, fp_rows)

    print(f"\n全部 xlsx 已写入 {XLSX_DIR}")


if __name__ == "__main__":
    main()
