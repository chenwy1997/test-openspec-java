#!/usr/bin/env python3
"""
update_memory.py — MEMORY.md 跨会话记忆自动更新 Hook（借鉴 OpenHarness 记忆机制）

在 PostToolUse 阶段监听 Bash 工具执行。
当检测到 openspec archive 相关命令完成后，自动从最新归档的 change 中
提取摘要并追加到 MEMORY.md，实现跨会话的项目知识积累。

触发条件：Bash 工具执行后，命令包含 "archive" 关键词
不触发条件：其他任何 Bash 命令
"""

import sys
import json
import os
import re
from datetime import date
from pathlib import Path


MEMORY_FILE = "MEMORY.md"
ARCHIVE_DIR = "openspec/changes/archive"

# MEMORY.md 中的占位符，用于定位插入点
PLACEHOLDER = "（暂无记录。随第一次 `/opsx:archive` 自动写入第一条。）"


def find_latest_archived_change() -> Path | None:
    """找到最新归档的 change 目录（按目录名排序，取最新）"""
    archive_path = Path(ARCHIVE_DIR)
    if not archive_path.exists():
        return None

    archived = [d for d in archive_path.iterdir() if d.is_dir()]
    if not archived:
        return None

    # 目录名格式为 YYYY-MM-DD-<name>，按名称降序取第一个
    archived.sort(key=lambda d: d.name, reverse=True)
    return archived[0]


def extract_proposal_summary(proposal_path: Path) -> str:
    """从 proposal.md 提取变更摘要（## 做什么 下的第一段非空文本）"""
    if not proposal_path.exists():
        return "（未找到 proposal.md）"

    content = proposal_path.read_text(encoding="utf-8")
    lines = content.splitlines()

    # 找到 "## 做什么" 段落后的第一段文本
    in_section = False
    summary_lines = []
    for line in lines:
        if re.match(r"^##\s+做什么", line):
            in_section = True
            continue
        if in_section:
            if line.startswith("## "):
                break  # 下一个 ## 段落，停止
            if line.strip():
                summary_lines.append(line.strip())
            elif summary_lines:
                break  # 空行且已有内容，段落结束

    return " ".join(summary_lines) if summary_lines else content.splitlines()[0].lstrip("# ").strip()


def extract_key_decisions(design_path: Path) -> str:
    """从 design.md 提取关键设计点（各机制的第一行说明）"""
    if not design_path.exists():
        return "（未找到 design.md）"

    content = design_path.read_text(encoding="utf-8")
    lines = content.splitlines()

    decisions = []
    for line in lines:
        # 提取二级和三级标题作为关键决策摘要（最多 3 条）
        if re.match(r"^##\s+", line) and len(decisions) < 3:
            title = line.lstrip("#").strip()
            if title and "design" not in title.lower():
                decisions.append(f"- {title}")

    return "\n".join(decisions) if decisions else "（详见 design.md）"


def already_recorded(change_name: str) -> bool:
    """检查该 change 是否已经记录在 MEMORY.md 中"""
    memory_path = Path(MEMORY_FILE)
    if not memory_path.exists():
        return False
    content = memory_path.read_text(encoding="utf-8")
    # 提取 change 核心名（去掉日期前缀 YYYY-MM-DD-）
    core_name = re.sub(r"^\d{4}-\d{2}-\d{2}-", "", change_name)
    return core_name in content


def append_to_memory(change_dir: Path) -> bool:
    """将变更摘要追加到 MEMORY.md，返回是否成功写入"""
    change_name = change_dir.name

    if already_recorded(change_name):
        return False  # 已记录，跳过

    # 提取信息
    summary = extract_proposal_summary(change_dir / "proposal.md")
    decisions = extract_key_decisions(change_dir / "design.md")

    # 提取日期（从目录名 YYYY-MM-DD-* 或使用今天）
    date_match = re.match(r"^(\d{4}-\d{2}-\d{2})-(.+)$", change_name)
    if date_match:
        record_date = date_match.group(1)
        core_name = date_match.group(2)
    else:
        record_date = str(date.today())
        core_name = change_name

    # 构建记录块
    record = (
        f"\n"
        f"## [{record_date}] {core_name}\n"
        f"\n"
        f"**变更摘要**：{summary}\n"
        f"\n"
        f"**关键决策**：\n"
        f"{decisions}\n"
        f"\n"
        f"**踩坑记录**：（归档时未记录，如有请手动补充）\n"
    )

    # 写入 MEMORY.md
    memory_path = Path(MEMORY_FILE)
    if not memory_path.exists():
        return False  # MEMORY.md 不存在，跳过

    content = memory_path.read_text(encoding="utf-8")

    # 如果存在占位符，替换它；否则追加到文件末尾
    if PLACEHOLDER in content:
        content = content.replace(PLACEHOLDER, record.strip())
        memory_path.write_text(content, encoding="utf-8")
    else:
        with memory_path.open("a", encoding="utf-8") as f:
            f.write(record)

    return True


def main():
    try:
        input_data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    # 只在 Bash 工具执行后触发
    tool_name = input_data.get("tool_name", "")
    if tool_name != "Bash":
        sys.exit(0)

    # 只在包含 archive 关键词的命令执行后触发
    command = input_data.get("tool_input", {}).get("command", "")
    if "archive" not in command.lower():
        sys.exit(0)

    # 查找最新归档的 change
    latest = find_latest_archived_change()
    if not latest:
        sys.exit(0)

    # 追加到 MEMORY.md
    written = append_to_memory(latest)
    if written:
        print(
            f"📝 [update_memory] 已将变更 '{latest.name}' 的摘要追加到 MEMORY.md",
            file=sys.stderr,
        )

    sys.exit(0)


if __name__ == "__main__":
    main()
