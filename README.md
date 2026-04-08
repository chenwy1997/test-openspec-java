# Spring Boot + OpenSpec 企业级脚手架

基于 **Java 21 + Spring Boot 3.x** 的企业级后端脚手架，集成 [OpenSpec OPSX](https://openspec.dev) AI 规范驱动开发工作流，让 AI 协作开发更可控、更规范。

## 核心理念

> 没有 Change 不开发。所有代码变更必须在 OpenSpec 工件（proposal → design → tasks）存在的前提下进行。

将 AI 放入一套可审计、可复现的工程流程中，而不是让它自由发挥。

## 技术栈

| 层次 | 技术选型 |
|------|---------|
| 语言 | Java 21 LTS（Virtual Threads） |
| 框架 | Spring Boot 3.x / Spring Framework 6.x |
| 构建 | Maven 3.9+ |
| 数据库 | MySQL 8.0 + MyBatis-Plus |
| 连接池 | HikariCP |
| 缓存 | Redis 7.x（Redisson） |
| 消息队列 | RabbitMQ / RocketMQ |
| 认证 | Spring Security + JWT |
| API 文档 | SpringDoc OpenAPI（Swagger UI） |
| 容器化 | Docker + Docker Compose |

## 项目结构

```
.
├── src/                        # 业务代码
├── docs/
│   ├── architecture/
│   │   ├── index.md            # 整体架构说明
│   │   └── implicit-contracts.md  # 隐性约定（开发前必读）
│   └── standards/
│       ├── database.md         # 数据库规范
│       └── testing.md          # 测试规范
├── openspec/
│   ├── config.yaml             # OpenSpec 项目配置
│   ├── changes/                # 进行中的变更
│   └── specs/                  # 系统规范文档
├── scripts/
│   └── restore-opsx-commands.sh  # 恢复 OpenSpec 中文命令
├── AGENTS.md                   # AI 导航地图
├── CLAUDE.md                   # Claude Code 系统提示
├── MEMORY.md                   # 跨会话项目记忆（自动维护）
└── REVIEW.md                   # 只读代码审查代理
```

## OpenSpec OPSX 工作流

```
/opsx:explore  →  /opsx:propose  →  /opsx:apply  →  /opsx:verify  →  /opsx:archive
  （探索想法）      （生成工件）      （执行实现）     （验证一致性）     （归档变更）
                                                                            ↓
                                                                    MEMORY.md 自动更新

# 中断后恢复上次工作
/opsx:resume
```

每个变更都会生成三份工件后再动一行代码：
- `proposal.md` — 做什么 & 为什么
- `design.md` — 接口设计、业务逻辑、数据库变更
- `tasks.md` — 分层可执行任务清单

## 快速开始

```bash
# 1. 克隆项目
git clone <repo-url>
cd test-openspec-java

# 2. 编译检查
mvn -q -DskipTests compile

# 3. 在 Claude Code 中开始第一个变更
# /opsx:propose
```

## Claude Code 集成

本项目已预置以下 Claude Code 能力：

| 类型 | 名称 | 说明 |
|------|------|------|
| 命令 | `/opsx:propose` | 提案变更，一步生成所有工件 |
| 命令 | `/opsx:apply` | 按任务清单实现变更 |
| 命令 | `/opsx:explore` | 进入思考探索模式 |
| 命令 | `/opsx:archive` | 归档已完成的变更 |
| 命令 | `/opsx:resume` | 恢复中断的会话，自动读取未完成任务续接执行 |
| Skill | `/prepare-review` | 生成 PR 审查摘要 |
| Skill | `/spring-architecture-review` | Spring Boot 分层架构检查 |
| Skill | `/sql-risk-review` | SQL 风险检查 |
| Agent | `@reviewer` | 只读代码审查子代理 |
| Hook | 分级写入保护 | 三档权限治理（🔴阻断 / 🟡询问 / 🟢放行），防止误改关键文件 |
| Hook | 编译检查 | Java 文件变更后自动触发 `mvn compile` |
| Hook | 记忆更新 | 每次 `/opsx:archive` 后自动将变更摘要写入 `MEMORY.md` |

## 注意事项

执行 `openspec init --tools claude` 或 `openspec update` 后，需恢复中文定制文件：

```bash
bash scripts/restore-opsx-commands.sh
```
