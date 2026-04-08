# Tasks: 借鉴 OpenHarness 三大机制强化 AI 开发治理

## 机制一：分级权限治理

- [ ] 1.1 新建 `.claude/hooks/tiered_permission.py`，实现三档风险分级逻辑（LOW/MEDIUM/HIGH）
- [ ] 1.2 更新 `.claude/settings.json`，在 PreToolUse `Write|Edit` matcher 中**追加** `tiered_permission.py`（保留原 `guard_write.py`）

## 机制二：MEMORY.md 跨会话记忆

- [ ] 2.1 在项目根目录新建 `MEMORY.md`（初始模板，含说明注释）
- [ ] 2.2 新建 `.claude/hooks/update_memory.py`，实现归档后自动追加摘要逻辑
- [ ] 2.3 更新 `.claude/settings.json`，在 PostToolUse `Bash` matcher 中追加 `update_memory.py`
- [ ] 2.4 更新 `CLAUDE.md`，在"关键文件导航"表格中新增 `MEMORY.md` 说明行

## 机制三：/opsx:resume 会话恢复

- [ ] 3.1 新建目录 `.claude/skills/openspec-resume/`
- [ ] 3.2 新建 `.claude/skills/openspec-resume/skill.md`，编写 resume 执行步骤（扫描活跃变更 → 展示进度 → 衔接执行）

## 收尾验证

- [ ] 4.1 人工验证：触发一次文件写入，确认 `tiered_permission.py` 三档响应正确
- [ ] 4.2 人工验证：检查 `MEMORY.md` 格式正确、`update_memory.py` 脚本语法无误（`python3 -m py_compile`）
- [ ] 4.3 人工验证：执行 `/opsx:resume` 确认 skill 被正确加载和执行
