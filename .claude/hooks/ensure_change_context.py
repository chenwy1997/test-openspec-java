#!/usr/bin/env python3
"""
ensure_change_context.py — 上下文变更保护 Hook

在 Claude 执行高风险 Bash 命令前触发，检查是否存在活跃的 OpenSpec change。
如果没有活跃 change，对高风险命令输出警告（ask 模式，不强制阻塞）。
"""

import sys
import json
import os
import glob

# 高风险命令关键词（包含这些词的 Bash 命令需要检查 change 上下文）
HIGH_RISK_KEYWORDS = [
    "mvn -DskipTests package",
    "mvn install",
    "mvn deploy",
    "git commit",
    "git merge",
    "git rebase",
]

# 纯安全命令（这些命令始终放行，不做检查）
SAFE_COMMANDS = [
    "git status",
    "git diff",
    "git log",
    "git show",
    "git branch",
    "mvn -q -DskipTests compile",
    "mvn test",
    "mvn dependency",
    "mvn help",
    "git stash list",
]


def has_active_change() -> bool:
    """检查是否存在活跃的 OpenSpec change"""
    changes_dir = "openspec/changes"
    if not os.path.isdir(changes_dir):
        return False

    # 有除 archive 之外的子目录，说明有活跃 change
    for entry in os.listdir(changes_dir):
        if entry == "archive":
            continue
        full_path = os.path.join(changes_dir, entry)
        if os.path.isdir(full_path):
            # 检查目录内是否有 proposal.md 或 tasks.md
            has_proposal = os.path.exists(os.path.join(full_path, "proposal.md"))
            has_tasks = os.path.exists(os.path.join(full_path, "tasks.md"))
            if has_proposal or has_tasks:
                return True

    return False


def is_safe_command(command: str) -> bool:
    """判断是否为安全命令"""
    for safe in SAFE_COMMANDS:
        if command.strip().startswith(safe):
            return True
    return False


def is_high_risk_command(command: str) -> bool:
    """判断是否为高风险命令"""
    for keyword in HIGH_RISK_KEYWORDS:
        if keyword in command:
            return True
    return False


def main():
    try:
        input_data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    command = input_data.get("command", "")

    if not command:
        sys.exit(0)

    # 安全命令直接放行
    if is_safe_command(command):
        sys.exit(0)

    # 非高风险命令直接放行
    if not is_high_risk_command(command):
        sys.exit(0)

    # 高风险命令：检查是否有活跃 change
    if not has_active_change():
        print(
            f"⚠️  [ensure_change_context] 检测到高风险命令，但当前没有活跃的 OpenSpec change。\n"
            f"\n"
            f"命令：{command}\n"
            f"\n"
            f"建议流程：\n"
            f"  1. 先执行 /opsx:propose 创建变更工件\n"
            f"  2. 审核 proposal.md / design.md / tasks.md\n"
            f"  3. 再执行 /opsx:apply 进行开发\n"
            f"\n"
            f"如果当前操作确实是计划内的，请确认后继续。\n",
            file=sys.stderr
        )
        # 输出 ask 信号（退出码 2 表示需要用户确认）
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
