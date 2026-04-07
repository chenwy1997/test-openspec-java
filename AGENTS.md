# AGENTS.md — AI 入口导航地图

> 本文件只做导航，不做知识库。真正的项目知识在 `docs/` 里。

## 工作流

本仓库使用 **OpenSpec OPSX** 管理所有变更生命周期，禁止在没有 change 的情况下直接开始开发。

标准主流程：
```
/opsx:propose → /opsx:apply → /opsx:verify → /opsx:archive
```

不确定需求时，先执行：
```
/opsx:explore
```

## 进入仓库后，必须先读这些文件

| 优先级 | 文件 | 说明 |
|--------|------|------|
| 🔴 必读 | `docs/architecture/index.md` | 项目整体架构、技术栈、分层规范 |
| 🔴 必读 | `docs/architecture/implicit-contracts.md` | 隐性业务约定与已知坑点 |
| 🟡 按需 | `docs/product/index.md` | 产品规则与业务背景 |
| 🟡 按需 | `docs/standards/testing.md` | 测试规范 |
| 🟡 按需 | `docs/standards/database.md` | 数据库与 SQL 规范 |

## 受保护目录（禁止直接修改）

以下路径属于高风险区域，**不得在没有明确变更工件的情况下修改**：

- `src/main/resources/application*.yml`
- `src/main/resources/bootstrap*.yml`
- `src/main/resources/db/`
- `sql/`
- `deploy/`
- `infra/`
- `secrets/`

## 主要命令入口

| 命令 | 功能 |
|------|------|
| `/opsx:explore` | 探索式调研，需求不明确时使用 |
| `/opsx:propose` | 创建变更提案（proposal + design + tasks） |
| `/opsx:apply` | 按任务清单执行开发 |
| `/opsx:verify` | 验证实现与 OpenSpec 工件是否一致 |
| `/opsx:archive` | 归档完成的变更 |
| `/prepare-review` | 生成 PR 前的变更摘要 |
| `/spring-architecture-review` | Spring Boot 分层架构检查 |
| `/sql-risk-review` | SQL 风险审查 |
| `@reviewer` | 启动只读评审子代理 |

## 开发前置检查

1. 确认当前是否有活跃的 OpenSpec change（`openspec/changes/` 下有进行中的变更）
2. 阅读 `implicit-contracts.md`，排查与当前需求相关的隐性约定
3. 确认 `proposal.md` / `design.md` / `tasks.md` 已经过人工审核后，再执行 `/opsx:apply`

## 评审与验证分工

不同审查工具职责不同，**不可混用**：

| 工具 | 检查内容 |
|------|--------|
| `/opsx:verify` | 实现是否与 OpenSpec change 工件一致 |
| `/prepare-review` | 整理"这次改了什么"，方便人工 review |
| `/spring-architecture-review` | Spring 分层是否合规 |
| `/sql-risk-review` | SQL、Mapper、批量更新、索引风险 |
| `@reviewer` | 独立只读视角的代码审查 |
