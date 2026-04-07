#!/usr/bin/env python3
"""
guard_write.py — 文件写入前保护 Hook

在 Claude 尝试写入/编辑文件时触发，检查目标路径是否属于受保护区域。
如果目标路径在保护列表中，输出阻塞信息并以非零状态码退出，阻止写入。
"""

import sys
import json
import os

# 受保护的路径前缀（相对于项目根目录）
PROTECTED_PATHS = [
    "src/main/resources/application",
    "src/main/resources/bootstrap",
    "src/main/resources/db/",
    "sql/",
    "deploy/",
    "infra/",
    "secrets/",
    ".env",
    ".env.",
]

# 受保护的文件名（精确匹配）
PROTECTED_FILES = [
    ".env",
    "docker-compose.prod.yml",
]


def is_protected(file_path: str) -> bool:
    """判断给定路径是否受保护"""
    # 标准化路径（去掉开头的 ./ 和绝对路径前缀）
    normalized = file_path.replace("\\", "/")
    if normalized.startswith("./"):
        normalized = normalized[2:]

    # 去掉绝对路径中的项目根目录前缀
    cwd = os.getcwd().replace("\\", "/")
    if normalized.startswith(cwd + "/"):
        normalized = normalized[len(cwd) + 1:]

    # 检查精确文件名
    basename = os.path.basename(normalized)
    if basename in PROTECTED_FILES:
        return True

    # 检查路径前缀
    for protected in PROTECTED_PATHS:
        if normalized.startswith(protected):
            return True

    return False


def main():
    # Claude Code hooks 通过 stdin 传入 JSON 格式的 tool_input
    try:
        input_data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, EOFError):
        # 无法解析输入，不拦截，让 Claude 自行处理
        sys.exit(0)

    # 获取目标文件路径（Write 工具用 file_path，Edit 工具也用 file_path）
    file_path = input_data.get("file_path", "")

    if not file_path:
        sys.exit(0)

    if is_protected(file_path):
        print(
            f"🚫 [guard_write] 拒绝写入受保护路径：{file_path}\n"
            f"\n"
            f"该路径属于高风险区域，禁止 AI 直接修改。\n"
            f"如果确实需要修改此文件，请：\n"
            f"  1. 确认当前有活跃的 OpenSpec change\n"
            f"  2. 在 design.md 中明确说明此变更\n"
            f"  3. 由人工执行或在人工监督下执行\n",
            file=sys.stderr
        )
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
