# /spring-architecture-review — Spring Boot 分层架构审查

## 触发方式

用户输入 `/spring-architecture-review` 时执行本技能。

## 功能说明

专项检查本次变更是否符合 Spring Boot 分层架构规范。聚焦分层边界是否清晰，不做业务逻辑正确性判断。

## 执行步骤

1. 执行 `git diff HEAD --name-only` 获取变更文件列表，筛选出 `.java` 文件
2. 读取 `docs/architecture/index.md` 确认分层规范
3. 逐一检查变更的 Java 文件，按照以下维度审查

## 审查维度

### Controller 层检查

对 `controller/` 目录下的文件检查：

- [ ] 是否有直接的数据库操作（注入了 Mapper / Repository）
- [ ] 是否有复杂的 if-else 业务判断（超过 3 层嵌套）
- [ ] 是否直接操作了 Entity 对象（应该操作 DTO/VO）
- [ ] 方法是否超过 20 行（Controller 方法应该很薄）
- [ ] 返回值是否统一用 `Result<T>` 包装

### Service 层检查

对 `service/impl/` 目录下的文件检查：

- [ ] 是否直接依赖了另一个 Service 的 Impl 类（应该依赖接口）
- [ ] 事务注解 `@Transactional` 是否使用合理（只在需要事务的方法上加）
- [ ] 是否有捕获异常后静默处理（空 catch 或只 log 不抛出）
- [ ] 方法是否超过 50 行（超出需注意是否可以拆分）
- [ ] 是否处理了 null 返回值（Mapper 查询可能返回 null）

### Mapper 层检查

对 `mapper/` 目录及对应 XML 文件检查：

- [ ] 接口方法是否有业务判断逻辑（Mapper 只应该有数据操作）
- [ ] XML 中是否使用了 `${}` 拼接（SQL 注入风险）
- [ ] 手写 SQL 是否遗漏了 `deleted = 0` 软删除条件
- [ ] 批量操作是否有 WHERE 条件限制

### 对象传递检查

- [ ] Entity 对象是否直接从 Controller 传到 Service（应使用 DTO）
- [ ] Entity 对象是否直接作为 API 响应返回（应使用 VO）

## 输出格式

```markdown
## Spring 分层架构审查报告

**审查范围**：[本次变更涉及的 Java 文件列表]

### 违规项（需要修复）

> 如无，写"无违规项"

**[违规类型]** `文件路径:行号`
- 问题：[描述]
- 建议：[如何修复]

---

### 注意项（不强制但建议关注）

- `文件路径:行号` — [说明]

---

### 整体评级

- ✅ 分层规范，无违规
- ⚠️ 存在轻微违规，建议修复
- ❌ 存在严重违规，必须修复后合并
```
