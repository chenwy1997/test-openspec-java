---
name: openspec-propose
description: 提案一个新变更，一步生成所有工件。当用户想快速描述要构建的内容并获得完整提案（含设计、规范和任务）时使用。
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.2.0"
---

提案一个新变更，一步完成变更创建和所有工件生成。

生成的工件包括：
- `proposal.md`（做什么 & 为什么）
- `design.md`（怎么做）
- `tasks.md`（可执行的实现步骤）

完成后运行 `/opsx:apply` 开始实现。

---

**输入**：用户的请求应包含变更名（kebab-case）或对要构建内容的描述。

**执行步骤**

1. **没有明确输入时，询问用户想做什么**

   使用 **AskUserQuestion 工具**（开放式提问，不预设选项）：
   > "你想做什么变更？请描述要构建或修复的内容。"

   根据描述推导出 kebab-case 名称（如"添加用户认证" → `add-user-auth`）。

   **重要**：没有弄清楚用户要做什么之前，不要继续执行。

2. **阅读项目上下文（必须）**

   创建变更前先读取：
   - `docs/architecture/index.md` — 了解整体架构和分层规范
   - `docs/architecture/implicit-contracts.md` — 了解隐性约定，避免 proposal 阶段踩坑
   - `openspec/specs/` — 了解当前系统规范（如果存在）

3. **创建变更目录**
   ```bash
   openspec new change "<name>"
   ```
   在 `openspec/changes/<name>/` 下创建带 `.openspec.yaml` 的脚手架。

4. **获取工件构建顺序**
   ```bash
   openspec status --change "<name>" --json
   ```
   解析 JSON 获取：
   - `applyRequires`：实现前必须完成的工件 ID 列表
   - `artifacts`：所有工件及其状态和依赖关系

5. **按顺序创建工件，直到满足实现条件**

   使用 **TodoWrite 工具** 跟踪进度。

   对每个状态为 `ready` 的工件：
   - 获取生成指令：
     ```bash
     openspec instructions <artifact-id> --change "<name>" --json
     ```
   - 指令 JSON 包含 `context`（约束，不写入文件）、`rules`（约束，不写入文件）、`template`（结构模板）、`outputPath`、`dependencies`
   - 读取依赖工件，按 `template` 创建文件
   - 简短提示："已创建 <artifact-id>"

   每创建一个工件后重新运行 status，检查是否所有 `applyRequires` 均为 `done`。

   上下文不明确时使用 **AskUserQuestion 工具** 询问。

6. **展示最终状态**
   ```bash
   openspec status --change "<name>"
   ```

**输出格式**

```
## 变更提案完成：<change-name>

**位置：** openspec/changes/<name>/
**使用 Schema：** <schema-name>

### 已生成工件
- proposal.md — [一句话说明做什么]
- design.md   — [一句话说明方案]
- tasks.md    — [X 个任务]

所有工件已就绪！运行 `/opsx:apply` 开始实现。
```

**Spring Boot 项目特有注意事项**

生成 `design.md` 时额外关注：
- 接口设计（HTTP 方法、路径、请求/响应结构）
- Service 层核心业务逻辑（伪代码）
- 数据库变更（新增字段/索引）
- 是否与 `implicit-contracts.md` 中的隐性约定有冲突

生成 `tasks.md` 时建议按分层拆分：
1. 数据库层（Entity / Mapper / XML）
2. 业务层（Service 接口 + Impl）
3. 控制层（Controller + DTO/VO）
4. 测试（单元测试 + 集成测试）

**工件创建规范**

- 遵循 `openspec instructions` 返回的 `instruction` 字段
- 用 `template` 作为输出文件结构，填充各章节
- `context` 和 `rules` 是对你的约束，**不要写入文件**，不要复制 `<context>`、`<rules>`、`<project_context>` 块

**护栏规则**
- 必须创建实现所需的所有工件
- 创建新工件前必须先读取依赖工件
- 上下文不明确时询问用户
- 如果同名变更已存在，询问用户是继续还是新建
- 写入每个工件后验证文件是否存在再继续
