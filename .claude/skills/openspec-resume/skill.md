# /opsx:resume — 会话恢复

当用户说 `/opsx:resume`、"继续上次的工作"、"接着做"、"从上次断点继续" 时触发此 skill。

## 目标

让 AI 自动读取当前活跃 change 的进度状态，无需用户重新描述上下文，直接衔接上次中断的工作。

## 执行步骤

### 第一步：扫描活跃变更

读取 `openspec/changes/` 目录，列出所有**非 archive** 的子目录，找出含有 `proposal.md` 或 `tasks.md` 的目录（即活跃变更）。

- **零个活跃变更**：告知用户当前没有进行中的变更，建议运行 `/opsx:propose` 创建新变更
- **一个活跃变更**：直接加载，继续第二步
- **多个活跃变更**：展示列表，请用户选择要恢复哪个，然后继续第二步

### 第二步：加载变更上下文

读取该变更目录下的所有工件：
- `proposal.md` — 了解变更目标和边界
- `design.md` — 了解技术设计决策
- `tasks.md` — 获取任务清单和当前进度

### 第三步：统计并展示进度

解析 `tasks.md` 中的复选框：
- `- [x]` → 已完成
- `- [ ]` → 待完成

以清晰格式展示恢复摘要，例如：

```
📋 恢复变更：enhance-hooks-memory-resume

进度：5/8 任务已完成（62.5%）

✅ 已完成：
  [1.1] 新建 tiered_permission.py
  [1.2] 更新 settings.json 注册 hook
  [2.1] 新建 MEMORY.md 初始模板
  [2.2] 新建 update_memory.py
  [2.3] 更新 settings.json 注册记忆 hook

⏳ 待完成：
  [2.4] 更新 CLAUDE.md 新增 MEMORY.md 说明
  [3.1] 新建 openspec-resume skill 目录
  [3.2] 新建 skill.md 编写 resume 步骤

下一个任务：[2.4] 更新 CLAUDE.md 新增 MEMORY.md 说明
```

### 第四步：询问确认并开始

询问用户：

> "是否立即从第一个未完成任务开始？（直接回复"是"或"继续"即可）"

用户确认后，**直接开始执行第一个未完成的任务**，无需等待进一步指令。执行方式与 `/opsx:apply` 相同：严格按照 `tasks.md` 的任务顺序，逐条完成并用 `[x]` 标记。

## 注意事项

- 读取 `MEMORY.md`（如果存在），了解项目历史踩坑记录
- 读取 `docs/architecture/implicit-contracts.md`，确保本次续做符合隐性约定
- 如果 `tasks.md` 中所有任务都已完成（全部 `[x]`），提示用户可以运行 `/opsx:archive` 归档
- 不要自行扩展任务范围，只做 `tasks.md` 中明确列出的内容
