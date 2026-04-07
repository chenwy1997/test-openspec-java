---
name: "OPSX: Propose"
description: 提案一个新变更 - 一步创建变更并生成所有工件
category: Workflow
tags: [workflow, artifacts, experimental]
---

提案一个新变更，一步完成变更创建和所有工件生成。

执行完成后将生成以下工件：
- `proposal.md`（做什么 & 为什么）
- `design.md`（怎么做，包括接口设计、数据库设计、核心逻辑）
- `tasks.md`（可执行的实现步骤清单）

工件生成完毕后，运行 `/opsx:apply` 开始实现。

---

**输入**：`/opsx:propose` 后面跟变更名（kebab-case），或者直接描述你要做什么。

**执行步骤**

1. **没有输入时，询问用户想做什么**

   使用 **AskUserQuestion 工具**（开放式提问，不预设选项）：
   > "你想做什么变更？请描述要构建或修复的内容。"

   根据描述推导出 kebab-case 名称（如"添加用户认证" → `add-user-auth`）。

   **重要**：没有弄清楚用户要做什么之前，不要继续执行。

2. **阅读项目上下文（必须）**

   在创建变更之前，先读取：
   - `docs/architecture/index.md` — 了解整体架构和分层规范
   - `docs/architecture/implicit-contracts.md` — 了解隐性约定，避免 proposal 阶段就踩坑
   - `openspec/specs/` — 了解当前系统规范（如果存在）

3. **创建变更目录**
   ```bash
   openspec new change "<name>"
   ```
   这会在 `openspec/changes/<name>/` 下创建带有 `.openspec.yaml` 的脚手架。

4. **获取工件构建顺序**
   ```bash
   openspec status --change "<name>" --json
   ```
   解析 JSON 获取：
   - `applyRequires`：实现前必须完成的工件 ID 列表（如 `["tasks"]`）
   - `artifacts`：所有工件及其状态和依赖关系

5. **按顺序创建工件，直到满足实现条件**

   使用 **TodoWrite 工具** 跟踪工件创建进度。

   按依赖顺序循环处理工件（先处理无待定依赖的工件）：

   a. **对每个状态为 `ready`（依赖已满足）的工件**：
      - 获取生成指令：
        ```bash
        openspec instructions <artifact-id> --change "<name>" --json
        ```
      - 指令 JSON 包含：
        - `context`：项目背景（对你的约束，**不要写入文件**）
        - `rules`：工件专属规则（对你的约束，**不要写入文件**）
        - `template`：输出文件的结构模板
        - `instruction`：该工件类型的生成指引
        - `outputPath`：文件输出路径
        - `dependencies`：需要读取的已完成工件
      - 读取所有依赖工件获取上下文
      - 按 `template` 结构创建工件文件
      - 以 `context` 和 `rules` 作为约束，但**不要把它们复制进文件**
      - 简短提示进度："已创建 <artifact-id>"

   b. **继续直到所有 `applyRequires` 工件完成**
      - 每创建一个工件后，重新运行 `openspec status --change "<name>" --json`
      - 检查 `applyRequires` 中每个工件 ID 的 `status` 是否为 `"done"`
      - 全部完成后停止

   c. **如果工件需要用户补充信息**（上下文不明确）：
      - 使用 **AskUserQuestion 工具** 询问
      - 然后继续创建

6. **展示最终状态**
   ```bash
   openspec status --change "<name>"
   ```

**输出格式**

完成所有工件后，输出摘要：
- 变更名称和路径
- 已创建的工件列表及简要描述
- 就绪状态："所有工件已创建！可以开始实现了。"
- 提示："运行 `/opsx:apply` 开始实现。"

**工件创建规范**

- 遵循 `openspec instructions` 返回的 `instruction` 字段
- Schema 定义了每个工件的内容 —— 严格按照执行
- 创建新工件前，先读取依赖工件获取上下文
- 用 `template` 作为输出文件的结构框架 —— 填充各章节
- **重要**：`context` 和 `rules` 是对你的约束，不是文件内容
  - 不要把 `<context>`、`<rules>`、`<project_context>` 块复制到工件文件中

**Spring Boot 项目特有注意事项**

在生成 `design.md` 时，需额外关注：
- 接口设计（HTTP 方法、路径、请求/响应结构）
- 涉及的 Service 层业务逻辑伪代码
- 涉及的数据库表字段变更（新增字段/索引）
- 是否与 `implicit-contracts.md` 中的隐性约定有冲突

在生成 `tasks.md` 时，建议按分层拆分任务：
1. 数据库层（Entity / Mapper / XML）
2. 业务层（Service 接口 + Impl）
3. 控制层（Controller + DTO/VO）
4. 测试（单元测试 + 集成测试）

**护栏规则**
- 必须创建实现所需的所有工件（由 schema 的 `apply.requires` 定义）
- 创建新工件前，必须先读取依赖工件
- 上下文不明确时询问用户，但优先做出合理判断以保持推进节奏
- 如果同名变更已存在，询问用户是继续还是新建
- 写入每个工件文件后，继续之前先验证文件是否存在
