#!/bin/bash
# restore-opsx-commands.sh
#
# 用途：openspec init / openspec update 会重置以下文件为英文：
#       - .claude/commands/opsx/ 下的命令文件
#       - .claude/skills/openspec-*/ 下的 skill 文件
#       运行此脚本可将它们全部恢复为中文版本（含 Spring Boot 增强内容）。
#
# 使用方式：
#   bash scripts/restore-opsx-commands.sh
#
# 建议：在每次执行 openspec init 或 openspec update 后运行一次。

set -e

COMMANDS_DIR=".claude/commands/opsx"

if [ ! -d "$COMMANDS_DIR" ]; then
  echo "❌ 目录不存在：$COMMANDS_DIR"
  echo "   请确认在项目根目录下执行此脚本。"
  exit 1
fi

echo "🔄 正在恢复 OpenSpec 命令文件为中文版本..."

# ────────────────────────────────────────────────────────────
# propose.md
# ────────────────────────────────────────────────────────────
cat > "$COMMANDS_DIR/propose.md" << 'PROPOSE_EOF'
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

4. **获取工件构建顺序**
   ```bash
   openspec status --change "<name>" --json
   ```

5. **按顺序创建工件，直到满足实现条件**

   使用 **TodoWrite 工具** 跟踪工件创建进度。

   对每个 `ready` 状态的工件：
   - 获取指令：`openspec instructions <artifact-id> --change "<name>" --json`
   - 读取依赖工件，按 `template` 创建文件
   - `context` 和 `rules` 是约束，**不要写入文件**

   继续直到所有 `applyRequires` 工件完成。

6. **展示最终状态**
   ```bash
   openspec status --change "<name>"
   ```

**Spring Boot 项目特有注意事项**

在生成 `design.md` 时，需额外关注：
- 接口设计（HTTP 方法、路径、请求/响应结构）
- 涉及的 Service 层业务逻辑伪代码
- 涉及的数据库表字段变更（新增字段/索引）
- 是否与 `implicit-contracts.md` 中的隐性约定有冲突

在生成 `tasks.md` 时，建议按分层拆分：
1. 数据库层（Entity / Mapper / XML）
2. 业务层（Service 接口 + Impl）
3. 控制层（Controller + DTO/VO）
4. 测试（单元测试 + 集成测试）

**护栏规则**
- 必须创建实现所需的所有工件
- 创建新工件前，必须先读取依赖工件
- 如果同名变更已存在，询问用户是继续还是新建
PROPOSE_EOF

# ────────────────────────────────────────────────────────────
# apply.md
# ────────────────────────────────────────────────────────────
cat > "$COMMANDS_DIR/apply.md" << 'APPLY_EOF'
---
name: "OPSX: Apply"
description: 按任务清单实现 OpenSpec 变更（实验性）
category: Workflow
tags: [workflow, artifacts, experimental]
---

按照 OpenSpec 变更的任务清单执行代码实现。

**输入**：可选地在命令后指定变更名称（如 `/opsx:apply add-auth`）。如果省略，从对话上下文推断。

**执行步骤**

1. **确定要操作的变更**（自动推断或提示选择）

2. **读取项目上下文（必须）**
   - `docs/architecture/implicit-contracts.md`
   - `docs/architecture/index.md`

3. **检查状态**
   ```bash
   openspec status --change "<name>" --json
   ```

4. **获取实现指令**
   ```bash
   openspec instructions apply --change "<name>" --json
   ```
   - `state: "blocked"` → 建议先 `/opsx:propose`
   - `state: "all_done"` → 建议归档
   - 其他 → 继续实现

5. **读取上下文文件**（来自 contextFiles 字段）

6. **实现任务（循环直到完成或阻塞）**

   对每个待处理任务：
   - 声明当前任务，进行代码变更
   - 完成后立即标记：`- [ ]` → `- [x]`
   - 每完成一个里程碑执行：`mvn -q -DskipTests compile`

   遇到以下情况暂停：任务不明确 / 发现设计问题 / 与隐性约定冲突 / 遇到错误

7. **完成后建议审查流程**
   ```
   /prepare-review → /spring-architecture-review → /sql-risk-review → @reviewer → /opsx:verify → /opsx:archive
   ```

**护栏规则**
- 开始前必须读取上下文文件和 `implicit-contracts.md`
- 任务不明确时暂停询问，不猜测
- 代码变更最小化，限定在每个任务范围内
- 完成每个任务后立即更新复选框
APPLY_EOF

# ────────────────────────────────────────────────────────────
# explore.md
# ────────────────────────────────────────────────────────────
cat > "$COMMANDS_DIR/explore.md" << 'EXPLORE_EOF'
---
name: "OPSX: Explore"
description: 进入探索模式 - 思考想法、调查问题、澄清需求
category: Workflow
tags: [workflow, explore, experimental, thinking]
---

进入探索模式。深入思考，自由探索，跟随对话的走向。

**重要：探索模式只用于思考，不用于实现。** 可以读取文件、搜索代码，但绝不能编写应用代码。

**这是一种态度，不是工作流程。** 没有固定步骤，你是用户的思考伙伴。

---

## 探索姿态

- **好奇，不规定** — 自然提问，不按脚本
- **开放线索** — 呈现多个方向，让用户选择
- **可视化** — 大量使用 ASCII 图表
- **适应性** — 跟随有趣线索，灵活转向
- **接地气** — 探索实际代码库，不只是理论化

## Spring Boot 场景下的特定探索方向

- 分层边界是否清晰（Controller/Service/Mapper 职责）
- 是否有相关隐性约定（查阅 `docs/architecture/implicit-contracts.md`）
- 数据库层面的影响（是否需要新增表/索引/字段）
- 接口设计是否与现有约定兼容
- 事务边界在哪里

## OpenSpec 感知

开始时检查现有状态：
```bash
openspec list --json
```

当想法成熟时，提议：
- "可以开始创建变更了。要生成一个提案吗？"

当有活跃变更时，读取工件并自然引用。决策时提议记录，由用户决定是否保存。

## 护栏规则

- **不实现** — 绝不编写应用代码
- **不急于求成** — 探索是思考时间
- **不自动记录** — 提议保存洞察，不直接去做
- **多可视化** — 好图表胜过很多文字
EXPLORE_EOF

# ────────────────────────────────────────────────────────────
# archive.md
# ────────────────────────────────────────────────────────────
cat > "$COMMANDS_DIR/archive.md" << 'ARCHIVE_EOF'
---
name: "OPSX: Archive"
description: 归档已完成的变更
category: Workflow
tags: [workflow, archive, experimental]
---

归档已完成的 OpenSpec 变更。

**输入**：可选地在命令后指定变更名称（如 `/opsx:archive add-auth`）。

**前置条件（归档前建议完成）**

1. `/opsx:verify` — 验证实现与工件一致
2. `/prepare-review` — 生成 PR 摘要
3. `/spring-architecture-review` — 分层架构检查
4. `/sql-risk-review` — SQL 风险检查
5. `@reviewer` — 只读代码审查

**执行步骤**

1. **提示选择变更**（未提供名称时）
   ```bash
   openspec list --json
   ```
   使用 **AskUserQuestion 工具** 让用户选择，**不要自动选择**。

2. **检查工件和任务完成状态**
   ```bash
   openspec status --change "<name>" --json
   ```
   有未完成项时警告并确认，不强制阻止。

3. **评估 delta specs 同步**

   检查 `openspec/changes/<name>/specs/`，若有 delta specs：
   - 与主规范比较，展示摘要
   - 提示选择：立即同步 / 跳过

4. **执行归档**
   ```bash
   mkdir -p openspec/changes/archive
   mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>
   ```

5. **展示归档摘要**（变更名、位置、同步状态、下一步建议）

**护栏规则**
- 始终提示用户确认变更名称
- 不因警告阻止归档，只告知并确认
- 保留 `.openspec.yaml`（随目录移动）
ARCHIVE_EOF

SKILLS_DIR=".claude/skills"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "❌ 目录不存在：$SKILLS_DIR"
  echo "   请确认在项目根目录下执行此脚本。"
  exit 1
fi

echo "🔄 正在恢复 OpenSpec skill 文件为中文版本..."

# ────────────────────────────────────────────────────────────
# openspec-propose/SKILL.md
# ────────────────────────────────────────────────────────────
mkdir -p "$SKILLS_DIR/openspec-propose"
cat > "$SKILLS_DIR/openspec-propose/SKILL.md" << 'PROPOSE_SKILL_EOF'
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
PROPOSE_SKILL_EOF

# ────────────────────────────────────────────────────────────
# openspec-apply-change/SKILL.md
# ────────────────────────────────────────────────────────────
mkdir -p "$SKILLS_DIR/openspec-apply-change"
cat > "$SKILLS_DIR/openspec-apply-change/SKILL.md" << 'APPLY_SKILL_EOF'
---
name: openspec-apply-change
description: 实现 OpenSpec 变更中的任务。当用户想开始实现、继续实现或逐步完成任务时使用。
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.2.0"
---

按照 OpenSpec 变更的任务清单执行代码实现。

**输入**：可选地指定变更名称。如果省略，从对话上下文推断。如果不明确，必须提示用户选择。

**执行步骤**

1. **确定要操作的变更**

   如果提供了名称，直接使用。否则：
   - 从对话上下文推断用户提到的变更
   - 如果只有一个活跃变更，自动选择
   - 如果不明确，运行 `openspec list --json` 获取可用变更，使用 **AskUserQuestion 工具** 让用户选择

   始终声明："使用变更：<name>"，并说明如何覆盖（如 `/opsx:apply <other>`）。

2. **读取项目上下文（必须）**

   实现前先读取：
   - `docs/architecture/implicit-contracts.md` — 了解隐性约定，避免实现踩坑
   - `docs/architecture/index.md` — 确认分层规范

3. **检查状态以了解 schema**
   ```bash
   openspec status --change "<name>" --json
   ```

4. **获取实现指令**
   ```bash
   openspec instructions apply --change "<name>" --json
   ```

   **处理不同状态：**
   - 如果 `state: "blocked"`：显示消息，建议使用 `/opsx:propose`
   - 如果 `state: "all_done"`：恭喜完成，建议归档
   - 其他情况：继续实现

5. **读取上下文文件**（来自 contextFiles 字段）

6. **实现任务（循环直到完成或阻塞）**

   对每个待处理任务：
   - 声明当前处理的任务，进行代码变更
   - 完成后立即标记：`- [ ]` → `- [x]`
   - 每完成一个里程碑执行：`mvn -q -DskipTests compile`

   遇到以下情况暂停：任务不明确 / 发现设计问题 / 与隐性约定冲突 / 遇到错误

7. **完成后建议审查流程**
   ```
   /prepare-review → /spring-architecture-review → /sql-risk-review → @reviewer → /opsx:verify → /opsx:archive
   ```

**Spring Boot 分层实现顺序**

1. 数据库层（Entity / Mapper / XML）
2. 业务层（Service 接口 + Impl）
3. 控制层（Controller + DTO/VO）
4. 测试（单元测试 + 集成测试）

**护栏规则**
- 开始前必须读取上下文文件和 `implicit-contracts.md`
- 任务不明确时暂停询问，不猜测
- 代码变更最小化，限定在每个任务范围内
- 完成每个任务后立即更新复选框
APPLY_SKILL_EOF

# ────────────────────────────────────────────────────────────
# openspec-archive-change/SKILL.md
# ────────────────────────────────────────────────────────────
mkdir -p "$SKILLS_DIR/openspec-archive-change"
cat > "$SKILLS_DIR/openspec-archive-change/SKILL.md" << 'ARCHIVE_SKILL_EOF'
---
name: openspec-archive-change
description: 归档已完成的变更。当用户想在实现完成后归档变更时使用。
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.2.0"
---

归档已完成的 OpenSpec 变更。

**输入**：可选地指定变更名称。如果省略，从对话上下文推断。如果不明确，必须提示用户选择。

**前置条件（归档前建议完成）**

1. `/opsx:verify` — 验证实现与工件一致
2. `/prepare-review` — 生成 PR 摘要
3. `/spring-architecture-review` — 分层架构检查
4. `/sql-risk-review` — SQL 风险检查
5. `@reviewer` — 只读代码审查

**执行步骤**

1. **提示选择变更**（未提供名称时）
   ```bash
   openspec list --json
   ```
   使用 **AskUserQuestion 工具** 让用户选择，**不要自动选择**。

2. **检查工件和任务完成状态**
   ```bash
   openspec status --change "<name>" --json
   ```
   有未完成项时警告并确认，不强制阻止。

3. **评估 delta specs 同步**

   检查 `openspec/changes/<name>/specs/`，若有 delta specs：
   - 与主规范比较，展示摘要
   - 提示选择：立即同步 / 跳过

4. **执行归档**
   ```bash
   mkdir -p openspec/changes/archive
   mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>
   ```

5. **展示归档摘要**（变更名、位置、同步状态、下一步建议）

**护栏规则**
- 始终提示用户确认变更名称
- 不因警告阻止归档，只告知并确认
- 保留 `.openspec.yaml`（随目录移动）
- 如果存在 delta specs，始终先运行同步评估并展示摘要
ARCHIVE_SKILL_EOF

# ────────────────────────────────────────────────────────────
# openspec-explore/SKILL.md
# ────────────────────────────────────────────────────────────
mkdir -p "$SKILLS_DIR/openspec-explore"
cat > "$SKILLS_DIR/openspec-explore/SKILL.md" << 'EXPLORE_SKILL_EOF'
---
name: openspec-explore
description: 进入探索模式——作为思考伙伴，帮助探索想法、调查问题、澄清需求。当用户想在变更前后深入思考时使用。
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.2.0"
---

进入探索模式。深入思考，自由探索，跟随对话的走向。

**重要：探索模式只用于思考，不用于实现。** 可以读取文件、搜索代码，但绝不能编写应用代码。

**这是一种态度，不是工作流程。** 没有固定步骤，你是用户的思考伙伴。

---

## 探索姿态

- **好奇，不规定** — 自然提问，不按脚本
- **开放线索** — 呈现多个方向，让用户选择
- **可视化** — 大量使用 ASCII 图表
- **适应性** — 跟随有趣线索，灵活转向
- **接地气** — 探索实际代码库，不只是理论化

## Spring Boot 场景下的特定探索方向

- 分层边界是否清晰（Controller/Service/Mapper 职责）
- 是否有相关隐性约定（查阅 `docs/architecture/implicit-contracts.md`）
- 数据库层面的影响（是否需要新增表/索引/字段）
- 接口设计是否与现有约定兼容
- 事务边界在哪里

## OpenSpec 感知

开始时检查现有状态：
```bash
openspec list --json
```

当想法成熟时，提议：
- "可以开始创建变更了。要生成一个提案吗？"

当有活跃变更时，读取工件并自然引用。决策时提议记录，由用户决定是否保存。

## 护栏规则

- **不实现** — 绝不编写应用代码
- **不急于求成** — 探索是思考时间
- **不自动记录** — 提议保存洞察，不直接去做
- **多可视化** — 好图表胜过很多文字
- **质疑假设** — 包括用户的和你自己的
EXPLORE_SKILL_EOF

echo "✅ 全部恢复完成！"
echo ""
echo "已恢复的文件："
echo "  Commands:"
echo "  - $COMMANDS_DIR/propose.md"
echo "  - $COMMANDS_DIR/apply.md"
echo "  - $COMMANDS_DIR/explore.md"
echo "  - $COMMANDS_DIR/archive.md"
echo "  Skills:"
echo "  - $SKILLS_DIR/openspec-propose/SKILL.md"
echo "  - $SKILLS_DIR/openspec-apply-change/SKILL.md"
echo "  - $SKILLS_DIR/openspec-archive-change/SKILL.md"
echo "  - $SKILLS_DIR/openspec-explore/SKILL.md"
