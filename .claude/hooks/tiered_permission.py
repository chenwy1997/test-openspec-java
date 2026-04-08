#!/usr/bin/env python3
"""
tiered_permission.py — 分级权限治理 Hook（借鉴 OpenHarness 权限治理机制）

在 Claude 尝试写入/编辑文件时触发，按操作风险等级分三档处理：

  🟢 LOW    — 自动放行（exit 0）
  🟡 MEDIUM — 输出警告，询问用户确认（exit 2）
  🔴 HIGH   — 强制阻断（exit 1）

风险等级判断规则：
  HIGH   ：原 guard_write.py 保护的所有路径（环境配置、DB脚本、部署脚本等）
  MEDIUM ：修改 .claude/ 自身配置、修改当前活跃 change 范围外的 openspec/ 文件
  LOW    ：其余所有写入（新建 Java 文件、修改业务代码、写 change 工件等）

与 guard_write.py 的关系：
  并联注册，不替换。两者都会执行，此 Hook 额外覆盖 MEDIUM 场景。
"""

import sys
import json
import os
from enum import Enum


class RiskLevel(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


# ── 原 guard_write.py 的 HIGH 风险路径（保持一致）──────────────────────────
HIGH_RISK_PATH_PREFIXES = [
    "src/main/resources/application",
    "src/main/resources/bootstrap",
    "src/main/resources/db/",
    "sql/",
    "deploy/",
    "infra/",
    "secrets/",
]

HIGH_RISK_EXACT_FILES = [
    ".env",
    "docker-compose.prod.yml",
]

HIGH_RISK_STARTSWITH = [
    ".env.",
]

# ── MEDIUM 风险：.claude/ 自身配置（hooks/skills 除外）────────────────────
MEDIUM_RISK_CLAUDE_PATHS = [
    ".claude/settings.json",
    ".claude/settings.local.json",
]


def normalize_path(file_path: str) -> str:
    """标准化路径，去掉 ./ 前缀和绝对路径中的 cwd 部分"""
    normalized = file_path.replace("\\", "/")
    if normalized.startswith("./"):
        normalized = normalized[2:]
    cwd = os.getcwd().replace("\\", "/")
    if normalized.startswith(cwd + "/"):
        normalized = normalized[len(cwd) + 1:]
    return normalized


def get_active_change_name() -> str | None:
    """获取当前活跃 change 的名称（取第一个非 archive 子目录）"""
    changes_dir = "openspec/changes"
    if not os.path.isdir(changes_dir):
        return None
    for entry in os.listdir(changes_dir):
        if entry == "archive":
            continue
        full_path = os.path.join(changes_dir, entry)
        if os.path.isdir(full_path):
            has_proposal = os.path.exists(os.path.join(full_path, "proposal.md"))
            has_tasks = os.path.exists(os.path.join(full_path, "tasks.md"))
            if has_proposal or has_tasks:
                return entry
    return None


def classify_risk(normalized_path: str, active_change: str | None) -> tuple[RiskLevel, str]:
    """
    判断文件路径的风险等级。
    返回 (RiskLevel, reason)
    """
    basename = os.path.basename(normalized_path)

    # ── HIGH：精确文件名匹配 ──────────────────────────────────────────────
    if basename in HIGH_RISK_EXACT_FILES:
        return RiskLevel.HIGH, f"受保护的敏感文件：{basename}"

    # ── HIGH：.env. 前缀匹配 ──────────────────────────────────────────────
    for prefix in HIGH_RISK_STARTSWITH:
        if basename.startswith(prefix):
            return RiskLevel.HIGH, f"受保护的环境配置文件（匹配 {prefix}*）"

    # ── HIGH：路径前缀匹配 ────────────────────────────────────────────────
    for protected in HIGH_RISK_PATH_PREFIXES:
        if normalized_path.startswith(protected):
            return RiskLevel.HIGH, f"受保护的路径区域：{protected}"

    # ── MEDIUM：修改 .claude/ 核心配置文件 ───────────────────────────────
    if normalized_path in MEDIUM_RISK_CLAUDE_PATHS:
        return RiskLevel.MEDIUM, f"正在修改 Claude Code 配置文件：{normalized_path}"

    # ── MEDIUM：修改 openspec/ 但不在当前活跃 change 目录下 ───────────────
    if normalized_path.startswith("openspec/") and active_change:
        change_prefix = f"openspec/changes/{active_change}/"
        if not normalized_path.startswith(change_prefix):
            # 排除 openspec/specs/（允许写入规范文件）
            if not normalized_path.startswith("openspec/specs/"):
                return (
                    RiskLevel.MEDIUM,
                    f"正在写入当前活跃 change（{active_change}）范围之外的 openspec 路径",
                )

    # ── LOW：其余均放行 ──────────────────────────────────────────────────
    return RiskLevel.LOW, "常规写入操作"


def main():
    try:
        input_data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    file_path = input_data.get("file_path", "")
    if not file_path:
        sys.exit(0)

    normalized = normalize_path(file_path)
    active_change = get_active_change_name()
    risk, reason = classify_risk(normalized, active_change)

    if risk == RiskLevel.LOW:
        # 放行，不输出任何内容（保持静默，避免干扰正常流程）
        sys.exit(0)

    elif risk == RiskLevel.MEDIUM:
        print(
            f"🟡 [tiered_permission] 中等风险写入操作，需要确认\n"
            f"\n"
            f"  文件：{file_path}\n"
            f"  原因：{reason}\n"
            f"\n"
            f"  如果这是计划内的操作（已在 design.md 中说明），请确认继续。\n"
            f"  如果不确定，请先查阅当前活跃 change 的 design.md。\n",
            file=sys.stderr,
        )
        sys.exit(2)  # exit(2) = 询问用户

    else:  # HIGH
        print(
            f"🔴 [tiered_permission] 高风险写入操作，已强制阻断\n"
            f"\n"
            f"  文件：{file_path}\n"
            f"  原因：{reason}\n"
            f"\n"
            f"  该路径属于高风险区域，禁止 AI 直接修改。\n"
            f"  如确需修改，请：\n"
            f"    1. 在当前 change 的 design.md 中明确说明此变更\n"
            f"    2. 由人工执行或在人工监督下操作\n",
            file=sys.stderr,
        )
        sys.exit(1)  # exit(1) = 强制阻断


if __name__ == "__main__":
    main()
