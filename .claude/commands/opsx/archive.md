---
name: "OPSX: Archive"
description: 归档已完成的变更
category: Workflow
tags: [workflow, archive, experimental]
---

归档已完成的 OpenSpec 变更。

**输入**：可选地在 `/opsx:archive` 后指定变更名称（如 `/opsx:archive add-auth`）。如果省略，从对话上下文推断。如果不明确，必须提示用户选择。

**前置条件（归档前建议完成）**

建议在归档前依次完成以下审查步骤：
1. `/opsx:verify` — 验证实现与 OpenSpec 工件一致
2. `/prepare-review` — 生成 PR 摘要
3. `/spring-architecture-review` — 分层架构检查
4. `/sql-risk-review` — SQL 风险检查
5. `@reviewer` — 只读代码审查

**执行步骤**

1. **如果未提供变更名称，提示选择**

   运行 `openspec list --json` 获取可用变更。使用 **AskUserQuestion 工具** 让用户选择。

   只显示活跃变更（未归档的）。
   如果可用，展示每个变更使用的 schema。

   **重要**：不要猜测或自动选择变更，必须让用户确认。

2. **检查工件完成状态**

   运行 `openspec status --change "<name>" --json` 检查工件完成情况。

   解析 JSON 了解：
   - `schemaName`：使用的工作流
   - `artifacts`：所有工件及其状态（`done` 或其他）

   **如果有未完成的工件：**
   - 显示警告，列出未完成的工件
   - 提示用户确认是否继续
   - 用户确认后继续

3. **检查任务完成状态**

   读取 tasks 文件（通常是 `tasks.md`）检查未完成的任务。

   统计标记为 `- [ ]`（未完成）和 `- [x]`（已完成）的任务数量。

   **如果发现未完成任务：**
   - 显示警告，说明未完成任务数量
   - 提示用户确认是否继续
   - 用户确认后继续

   **如果 tasks 文件不存在：** 跳过任务相关警告，继续执行。

4. **评估规范同步状态**

   检查 `openspec/changes/<name>/specs/` 是否有 delta specs。如果没有，跳过同步提示直接继续。

   **如果存在 delta specs：**
   - 将每个 delta spec 与 `openspec/specs/<capability>/spec.md` 中对应的主规范进行比较
   - 确定将应用的变更（新增、修改、删除、重命名）
   - 在提示前显示综合摘要

   **提示选项：**
   - 如果需要变更："立即同步（推荐）"、"不同步直接归档"
   - 如果已同步："立即归档"、"仍然同步"、"取消"

   如果用户选择同步，使用 Task 工具（subagent_type: "general-purpose"）调用 openspec-sync-specs。无论是否同步，都继续进行归档。

5. **执行归档**

   如果不存在，先创建归档目录：
   ```bash
   mkdir -p openspec/changes/archive
   ```

   使用当前日期生成目标名称：`YYYY-MM-DD-<change-name>`

   **检查目标是否已存在：**
   - 如果存在：报错，建议重命名现有归档或等待不同日期
   - 如果不存在：将变更目录移动到归档

   ```bash
   mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>
   ```

6. **展示摘要**

   显示归档完成摘要，包括：
   - 变更名称
   - 使用的 Schema
   - 归档位置
   - 规范同步状态（已同步 / 跳过同步 / 无 delta specs）
   - 任何警告说明（未完成工件/任务）
   - 下一步建议（提交 PR 等）

**成功归档的输出格式**

```
## 归档完成

**变更：** <change-name>
**Schema：** <schema-name>
**归档位置：** openspec/changes/archive/YYYY-MM-DD-<name>/
**规范：** ✓ 已同步到主规范

所有工件已完成。所有任务已完成。
```

**成功归档（无 Delta Specs）的输出格式**

```
## 归档完成

**变更：** <change-name>
**Schema：** <schema-name>
**归档位置：** openspec/changes/archive/YYYY-MM-DD-<name>/
**规范：** 无 delta specs

所有工件已完成。所有任务已完成。
```

**带警告的成功归档输出格式**

```
## 归档完成（有警告）

**变更：** <change-name>
**Schema：** <schema-name>
**归档位置：** openspec/changes/archive/YYYY-MM-DD-<name>/
**规范：** 跳过同步（用户选择跳过）

**警告：**
- 归档时有 2 个工件未完成
- 归档时有 3 个任务未完成
- Delta spec 同步已跳过（用户选择跳过）

如果这不是有意为之，请查阅归档内容。
```

**归档失败（目标已存在）的输出格式**

```
## 归档失败

**变更：** <change-name>
**目标：** openspec/changes/archive/YYYY-MM-DD-<name>/

目标归档目录已存在。

**可选方案：**
1. 重命名现有归档
2. 如果是重复内容，删除现有归档
3. 等到不同日期再归档
```

**护栏规则**
- 未提供变更名称时，始终提示用户选择
- 使用工件图（openspec status --json）检查完成情况
- 不因警告阻止归档 —— 只告知并确认
- 移动到归档时保留 `.openspec.yaml`（它随目录一起移动）
- 显示发生了什么的清晰摘要
- 如果请求同步，使用 Skill 工具调用 `openspec-sync-specs`（代理驱动）
- 如果存在 delta specs，始终先运行同步评估并在提示前显示综合摘要
