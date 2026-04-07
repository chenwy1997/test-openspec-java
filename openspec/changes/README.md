# changes/ — 变更目录

## 这个目录是什么

`changes/` 管理所有**进行中的变更**（需求）的生命周期。

每次有新需求时，通过 `/opsx:propose` 在这里创建一个变更目录，包含完整的工件。

## 变更生命周期

```
/opsx:propose                    /opsx:archive
     ↓                                ↓
changes/<name>/          →    changes/archive/YYYY-MM-DD-<name>/
  ├── .openspec.yaml                 （自动移入，不用手动操作）
  ├── proposal.md
  ├── design.md
  ├── tasks.md
  └── specs/（delta specs，可选）
```

## 每个工件的职责

| 文件 | 职责 | 生成时机 |
|------|------|---------|
| `.openspec.yaml` | 变更元数据（schema、状态等）| 工具自动生成 |
| `proposal.md` | 做什么、为什么、边界是什么 | `/opsx:propose` |
| `design.md` | 怎么做（接口、DB、核心逻辑）| `/opsx:propose` |
| `tasks.md` | 可执行任务清单（带复选框）| `/opsx:propose` |
| `specs/` | 本次变更影响的规范增量 | `/opsx:propose`（可选）|

## 重要原则

**一个变更 = 一件明确的事**

判断是否应该新建变更还是继续当前变更：
- 意图变了 → 新建变更
- 涉及完全不同的模块 → 新建变更
- 只是实现方式调整 → 更新当前变更
- 当前变更可以独立完成并发布 → 归档当前，再开新的

**变更边界不清时，宁可拆小不要合并**

如果 AI 始终无法稳定理解某块逻辑，通常不是 AI 能力问题，
而是这个变更的边界定义得不够清楚。

## archive/ 子目录

`archive/` 存放所有已完成的变更，格式为 `YYYY-MM-DD-<name>`。

归档后的变更只用于查阅历史，不再参与日常开发。

---

> 使用 `/opsx:propose` 创建你的第一个变更。
