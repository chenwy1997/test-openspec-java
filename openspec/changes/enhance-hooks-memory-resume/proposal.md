# Proposal: 借鉴 OpenHarness 三大机制强化 AI 开发治理

## 做什么

在现有 OpenSpec Java 脚手架基础上，引入三个来自 OpenHarness 的核心机制：

1. **分级权限治理**（tiered permission hook）：将现有粗粒度的 `guard_write.py` 升级为意图感知的动态授权系统，按操作风险等级分层处理（自动放行 / 询问确认 / 强制阻断）
2. **MEMORY.md 跨会话记忆**：在归档变更后自动追加本次踩坑记录到 `MEMORY.md`，让 AI 的项目知识能跨会话积累，弥补 `implicit-contracts.md` 纯人工维护的局限
3. **`/opsx:resume` 会话恢复**：新增 skill，让 AI 能自动读取当前活跃 change 的 `tasks.md` 未完成项，续接上次中断的工作，无需用户重新描述上下文

## 为什么

### 现有痛点

| 机制 | 现状 | 问题 |
|------|------|------|
| 权限控制 | `guard_write.py` 只有"放行/阻断"两档 | 对中等风险操作（如修改现有文件而非新建）过于粗暴，用户体验差 |
| 项目记忆 | `implicit-contracts.md` 纯人工维护 | 踩了坑需要手动记录，依赖人的主观意识，容易遗漏 |
| 会话恢复 | 无机制 | 每次重开会话，AI 不知道上次做到哪，用户需要重新 context switch |

### 变更价值

- 分级权限让治理更精准，减少误杀的同时保留关键阻断
- MEMORY.md 机制让项目知识自动沉淀，形成滚雪球效应
- `/opsx:resume` 极大降低多会话开发的上下文切换成本

## 边界

**本次变更包含**：
- 新增 `.claude/hooks/tiered_permission.py`（替换 `guard_write.py` 的文件写入保护逻辑）
- 新增 `.claude/hooks/update_memory.py`（PostToolUse hook，归档时触发）
- 新增 `.claude/skills/openspec-resume/`（新 skill）
- 更新 `.claude/settings.json`（注册新 hooks，调整权限规则）
- 新建 `MEMORY.md`（初始模板）

**本次变更不包含**：
- 修改任何 Java 业务代码
- 修改 `ensure_change_context.py`（Bash 命令检查逻辑不变）
- 修改 `run_checks.sh`（编译检查逻辑不变）
- 删除 `guard_write.py`（保留，tiered_permission.py 是增强，不是替换）
