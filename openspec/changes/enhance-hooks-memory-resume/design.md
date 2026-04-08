# Design: 借鉴 OpenHarness 三大机制强化 AI 开发治理

## 机制一：分级权限治理（tiered_permission.py）

### 设计思路

将文件写入操作按风险等级分为三档，取代 `guard_write.py` 的二元判断：

```
风险等级        操作特征                          处理方式
─────────────────────────────────────────────────────────
🟢 LOW          新建文件 / 写入 src/ 内 Java 文件   自动放行，记录日志
🟡 MEDIUM       修改 openspec/changes/ 之外的 .md   输出 WARN，exit(2) 询问
                修改 .claude/ 配置文件本身
🔴 HIGH         原 guard_write.py 保护的所有路径    强制阻断，exit(1)
                写入 Change 范围之外的核心配置
```

### 风险判断逻辑

```python
def classify_risk(file_path, active_change_name) -> RiskLevel:
    # 1. 原保护路径 → HIGH（直接阻断）
    if is_originally_protected(file_path):
        return RiskLevel.HIGH

    # 2. 写入 .claude/ 自身配置 → MEDIUM（询问）
    if file_path.startswith(".claude/") and not file_path.startswith(".claude/hooks/"):
        return RiskLevel.MEDIUM

    # 3. 写入 openspec/ 但不在当前 change 目录下 → MEDIUM（询问）
    if file_path.startswith("openspec/") and active_change_name:
        if f"openspec/changes/{active_change_name}" not in file_path:
            return RiskLevel.MEDIUM

    # 4. 其余 → LOW（放行）
    return RiskLevel.LOW
```

### 退出码约定（遵循 Claude Code Hooks 规范）

| 退出码 | 含义 |
|--------|------|
| `0` | 允许，继续执行 |
| `1` | 阻断，拒绝执行 |
| `2` | 询问用户，由用户决定是否继续 |

### 与现有 guard_write.py 的关系

`tiered_permission.py` **不替换** `guard_write.py`，而是**并联注册**在 PreToolUse 中。两个 hook 都会执行，任一返回非零则触发对应行为。实际上 `tiered_permission.py` 覆盖了 `guard_write.py` 的所有 HIGH 场景，且新增了 MEDIUM 场景。后续可考虑合并，本次先并联保持兼容。

---

## 机制二：MEMORY.md 跨会话记忆（update_memory.py）

### 设计思路

在 `PostToolUse` 阶段，监听 `Bash` 工具执行，当检测到 `/opsx:archive` 相关命令完成时，自动触发记忆更新流程。

由于 Hook 本身是 Python 脚本，无法调用 LLM，所以采用**结构化追加**策略：将已归档 change 的 `proposal.md` 摘要和 `implicit-contracts.md` 中尚未记录的条目追加到 `MEMORY.md`。

### MEMORY.md 文件格式

```markdown
# MEMORY.md — 跨会话项目记忆

> 此文件由系统自动维护，记录每次变更归档后的关键经验。
> AI 在开始工作时应优先读取此文件，了解项目的历史踩坑记录。

## [YYYY-MM-DD] <change-name>

**变更摘要**：（来自 proposal.md 第一段）
**关键决策**：（来自 design.md 关键设计点）
**踩坑记录**：（由 AI 在归档前手动追加，或从 implicit-contracts.md 新增条目推断）
```

### update_memory.py 触发逻辑

```python
# PostToolUse: Bash 工具执行后
def main():
    input_data = json.loads(sys.stdin.read())
    command = input_data.get("tool_input", {}).get("command", "")

    # 只在归档命令执行后触发
    if "openspec" not in command or "archive" not in command:
        sys.exit(0)

    # 找到最新归档的 change（archive/ 下最新目录）
    archived = find_latest_archived_change()
    if not archived:
        sys.exit(0)

    # 读取 proposal.md 提取摘要
    summary = extract_summary(archived / "proposal.md")

    # 追加到 MEMORY.md
    append_to_memory(summary, archived.name)
```

### MEMORY.md 初始模板

```markdown
# MEMORY.md — 跨会话项目记忆

> 此文件由系统自动维护。AI 每次开工前应读取此文件。
> 手动追加格式见底部模板区。

---

（暂无记录，随第一次 /opsx:archive 自动生成）
```

---

## 机制三：/opsx:resume 会话恢复（新 skill）

### 设计思路

新增 skill `openspec-resume`，触发词为 `/opsx:resume`。AI 执行时：

1. 读取 `openspec/changes/` 下所有活跃变更（非 archive 子目录）
2. 如果只有一个活跃变更 → 直接加载
3. 如果有多个活跃变更 → 展示列表，询问用户选择哪个
4. 加载选定变更的 `tasks.md`，找出所有 `- [ ]` 未完成项
5. 展示恢复摘要，询问"是否从第一个未完成任务开始？"
6. 用户确认后，直接衔接执行（相当于自动触发 `/opsx:apply`）

### Skill 文件结构

```
.claude/skills/openspec-resume/
└── skill.md          ← skill 指令文件
```

### skill.md 核心内容

```markdown
# /opsx:resume — 会话恢复

## 触发条件
用户说 `/opsx:resume` 或"继续上次的工作"时触发。

## 执行步骤
1. 扫描 openspec/changes/ 找出所有活跃变更
2. 读取对应 tasks.md，统计已完成 [x] 和待完成 [ ] 项
3. 展示进度摘要
4. 询问用户是否立即开始执行第一个未完成任务
```

---

## settings.json 变更

### 新增 PreToolUse hook

```json
{
  "matcher": "Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "python3 .claude/hooks/tiered_permission.py"
    }
  ]
}
```

### 新增 PostToolUse hook

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "python3 .claude/hooks/update_memory.py"
    }
  ]
}
```

### CLAUDE.md 补充说明

在 `CLAUDE.md` 的"关键文件导航"表格中新增 `MEMORY.md` 一行，提示 AI 每次开工前读取。
