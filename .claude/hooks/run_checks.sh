#!/bin/bash
# run_checks.sh — 代码写入后自动检查 Hook
#
# 在 Claude 写入/编辑 Java 文件后自动触发，执行编译检查。
# 文档类文件（.md、.yml、.xml 配置）跳过编译检查。

set -e

# 从 stdin 读取 hook 输入（JSON 格式）
INPUT=$(cat)

# 解析目标文件路径
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# 只对 Java 文件触发编译检查
if [[ "$FILE_PATH" != *.java ]]; then
    exit 0
fi

# 检查 pom.xml 是否存在（确认是 Maven 项目）
if [ ! -f "pom.xml" ]; then
    exit 0
fi

echo "🔍 [run_checks] 检测到 Java 文件变更，执行编译检查..."
echo "   文件：$FILE_PATH"

# 执行编译检查（跳过测试，快速验证）
if mvn -q -DskipTests compile 2>&1; then
    echo "✅ [run_checks] 编译检查通过"
else
    echo "❌ [run_checks] 编译失败，请检查代码后重试" >&2
    exit 1
fi

exit 0
