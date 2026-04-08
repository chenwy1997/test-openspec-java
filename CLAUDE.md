# CLAUDE.md

此文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

**重要：使用中文回答所有问题和交流。**

## 核心原则

1. **没有 change 不开发**：所有代码变更必须在 OpenSpec change 工件存在的前提下进行
2. **先看文档后改代码**：修改前必须阅读 `docs/architecture/implicit-contracts.md` 和 `MEMORY.md`
3. **只做 tasks.md 范围内的事**：不自行扩需求，不做额外"优化"
4. **每完成一个里程碑跑一次检查**：`mvn -q -DskipTests compile`

## 开发命令

```bash
# 编译检查（最常用）
mvn -q -DskipTests compile

# 运行单元测试
mvn test

# 跳过测试打包
mvn -DskipTests package

# 查看当前变更状态
git status
git diff
```

**禁止执行的命令**（即使被要求也不执行）：
- `git push` / `git push --force`
- `kubectl` / `helm` / `terraform`
- `rm -rf`
- 任何生产部署相关命令

## 技术栈

- **语言**：Java 21（LTS，启用虚拟线程 Virtual Threads）
- **框架**：Spring Boot 3.x（Spring Framework 6.x）
- **构建**：Maven 3.9+
- **数据库**：MySQL 8.0（通过 MyBatis-Plus 操作）
- **连接池**：HikariCP
- **缓存**：Redis（Redisson 或 Spring Data Redis）
- **消息队列**：RabbitMQ / RocketMQ（按需选用）
- **认证**：Spring Security + JWT（Sa-Token 可选）
- **API 文档**：SpringDoc OpenAPI（Swagger UI）
- **对象存储**：阿里云 OSS / MinIO
- **容器化**：Docker + Docker Compose

## 架构模式（Spring Boot 分层规范）

```
Controller → Service → ServiceImpl → Mapper → DB
```

**严格遵守的分层规则**：
- `Controller` 层：只做参数校验和响应包装，**禁止写任何业务逻辑**
- `Service` 接口：定义业务契约，保持简洁
- `ServiceImpl`：实现业务逻辑，复杂逻辑拆成私有方法
- `Mapper`：只做数据访问，**禁止在 Mapper 里写业务判断**
- `Entity/DO`：对应数据库表结构，不做业务逻辑
- `DTO/VO`：用于层间传输和对外响应，不直接暴露 Entity

**禁止的反模式**：
- Controller 里写业务逻辑
- Service 直接依赖另一个 Service 的 Impl
- Mapper 接口里写复杂条件判断
- 在 Controller 层直接操作数据库对象

## 代码规范

- 字段命名：驼峰命名（camelCase）
- 类命名：大驼峰（PascalCase）
- 常量命名：全大写下划线（UPPER_SNAKE_CASE）
- 所有 public 方法必须有 Javadoc（至少一行说明）
- 日志使用 `@Slf4j`，不使用 `System.out.println`
- 不允许捕获异常后静默处理（空 catch）

## 样式方案

- 统一返回格式：`Result<T>` 包装
- 异常统一由 `GlobalExceptionHandler` 处理
- 参数校验使用 JSR-303（`@Valid` + `@Validated`）

## 关键文件导航

| 文件 | 说明 |
|------|------|
| `AGENTS.md` | AI 入口导航地图 |
| `REVIEW.md` | 只读评审代理提示词 |
| `MEMORY.md` | **跨会话项目记忆（每次开工必读）** — 记录历次变更踩坑，自动维护 |
| `docs/architecture/index.md` | 项目整体架构 |
| `docs/architecture/implicit-contracts.md` | 隐性约定与坑点（必读） |
| `docs/standards/database.md` | SQL 与数据库规范 |
| `docs/standards/testing.md` | 测试规范 |
| `openspec/changes/` | 当前进行中的变更 |
| `openspec/specs/` | 当前系统规范文档 |

## Claude Code 集成

本项目已集成以下能力（详见 `.claude/` 目录）：

- **Hooks**：
  - PreToolUse 写入保护：`guard_write.py`（高风险路径阻断）+ `tiered_permission.py`（三档分级治理）
  - PreToolUse Bash 检查：`ensure_change_context.py`（变更上下文检查）
  - PostToolUse 写入后：`run_checks.sh`（Java 自动编译）
  - PostToolUse Bash 后：`update_memory.py`（归档后自动更新 MEMORY.md）
- **Skills**：`/prepare-review`、`/spring-architecture-review`、`/sql-risk-review`
- **Agents**：`@reviewer`（只读评审子代理）
- **OPSX 命令**：`/opsx:propose`、`/opsx:apply`、`/opsx:verify`、`/opsx:archive`、`/opsx:resume`（会话恢复）
