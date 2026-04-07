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
   解析 JSON 了解：
   - `schemaName`：使用的工作流（如 "spec-driven"）
   - 哪个工件包含任务（spec-driven 通常是 "tasks"，其他 schema 查看 status 输出）

4. **获取实现指令**

   ```bash
   openspec instructions apply --change "<name>" --json
   ```

   返回内容：
   - 上下文文件路径（因 schema 而异）
   - 进度（总数、已完成、剩余）
   - 带状态的任务列表
   - 基于当前状态的动态指令

   **处理不同状态：**
   - 如果 `state: "blocked"`（缺少工件）：显示消息，建议使用 `/opsx:propose` 先创建工件
   - 如果 `state: "all_done"`：恭喜完成，建议归档
   - 其他情况：继续实现

5. **读取上下文文件**

   读取实现指令输出中 `contextFiles` 列出的文件。
   文件内容因 schema 而异：
   - **spec-driven**：proposal、specs、design、tasks
   - 其他 schema：按 CLI 输出的 contextFiles 处理

6. **展示当前进度**

   显示：
   - 使用的 Schema
   - 进度："已完成 N/M 个任务"
   - 剩余任务概览
   - CLI 返回的动态指令

7. **实现任务（循环直到完成或阻塞）**

   对每个待处理任务：
   - 声明当前处理的任务
   - 进行代码变更
   - 保持变更最小化，聚焦于当前任务范围
   - 完成后立即在 tasks 文件中标记：`- [ ]` → `- [x]`
   - 继续下一个任务

   **每完成一个里程碑后**（数据库层完成、Service 层完成等）：
   - 执行编译检查：`mvn -q -DskipTests compile`
   - 确认编译通过后再继续下一阶段

   **遇到以下情况时暂停：**
   - 任务不明确 → 询问澄清
   - 实现过程中发现设计问题 → 建议更新工件（proposal/design）
   - 与 `implicit-contracts.md` 中的约定冲突 → 停下来确认
   - 遇到错误或阻塞 → 报告并等待指引
   - 用户中断

8. **完成或暂停时展示状态**

   显示：
   - 本次会话完成的任务
   - 总体进度："已完成 N/M 个任务"
   - 如果全部完成：建议依次执行 `/prepare-review` → `/spring-architecture-review` → `/sql-risk-review` → `@reviewer` → `/opsx:verify` → `/opsx:archive`
   - 如果暂停：解释原因并等待指引

**实现过程中的输出格式**

```
## 实现中：<change-name>（schema: <schema-name>）

正在处理任务 3/7：<任务描述>
[...实现中...]
✓ 任务完成

正在处理任务 4/7：<任务描述>
[...实现中...]
✓ 任务完成
```

**全部完成时的输出格式**

```
## 实现完成

**变更：** <change-name>
**Schema：** <schema-name>
**进度：** 7/7 个任务全部完成 ✓

### 本次完成的任务
- [x] 任务 1
- [x] 任务 2
...

所有任务已完成！建议按以下顺序进行审查：
1. /prepare-review         — 生成 PR 摘要
2. /spring-architecture-review — 分层架构检查
3. /sql-risk-review        — SQL 风险检查
4. @reviewer               — 只读代码审查
5. /opsx:verify            — 验证实现与工件一致性
6. /opsx:archive           — 归档本次变更
```

**遇到问题暂停时的输出格式**

```
## 实现暂停

**变更：** <change-name>
**Schema：** <schema-name>
**进度：** 4/7 个任务已完成

### 遇到的问题
<问题描述>

**可选方案：**
1. <方案 1>
2. <方案 2>
3. 其他方案

你想怎么处理？
```

**护栏规则**
- 持续执行任务，直到全部完成或遇到阻塞
- 开始前必须读取上下文文件（来自 apply 指令输出）和 `implicit-contracts.md`
- 任务不明确时，暂停询问，不要猜测实现
- 实现过程中发现问题时，暂停并建议更新工件
- 代码变更保持最小化，限定在每个任务范围内
- 完成每个任务后立即更新任务复选框
- 遇到错误、阻塞或需求不明确时暂停，不要猜测
- 使用 CLI 输出的 contextFiles，不要假定具体文件名

**Spring Boot 分层实现顺序**

按以下顺序实现，每层完成后执行编译检查：
1. **数据库层**：Entity（含字段注解）、Mapper 接口、XML SQL 文件
2. **业务层**：Service 接口定义、ServiceImpl 实现（含 @Transactional）
3. **控制层**：Controller、DTO/VO（Request/Response 对象）
4. **测试**：单元测试（Mockito）、集成测试（@SpringBootTest）

**流式工作流集成**

本 skill 支持"在变更上随时执行动作"的模式：

- **随时可调用**：在所有工件完成前（如果任务已存在）、部分实现后、与其他动作交替执行
- **允许更新工件**：如果实现过程中发现设计问题，建议更新工件——不锁定阶段，灵活推进
