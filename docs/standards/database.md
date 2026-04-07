# 数据库与 SQL 规范

> AI 在涉及数据库操作时，必须遵守本规范。`/sql-risk-review` 将按本文件内容进行审查。

## 基本原则

1. 所有 DDL 变更通过版本管理（Flyway / Liquibase 或手动 SQL 文件放入 `src/main/resources/db/`）
2. **禁止直接在生产数据库手动执行 DDL**
3. 所有新增表必须包含：`id`（主键）、`created_at`、`updated_at`、`deleted`（软删除）

## 表设计规范

### 命名规范

| 对象 | 命名规则 | 示例 |
|------|---------|------|
| 表名 | `t_` 前缀 + 下划线小写 | `t_user`、`t_order` |
| 字段名 | 下划线小写 | `user_name`、`created_at` |
| 索引名 | `idx_表名_字段名` | `idx_user_email` |
| 唯一索引 | `uniq_表名_字段名` | `uniq_user_phone` |
| 外键（不推荐） | `fk_表名_关联表名` | `fk_order_user` |

### 必须字段

```sql
`id`          BIGINT      NOT NULL AUTO_INCREMENT COMMENT '主键',
`created_at`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
`updated_at`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
`deleted`     TINYINT(1)  NOT NULL DEFAULT 0 COMMENT '软删除标记：0=正常，1=已删除',
PRIMARY KEY (`id`)
```

### 字段类型规范

| 数据类型 | 推荐 Java 类型 | 注意事项 |
|---------|--------------|---------|
| `BIGINT` | `Long` | 主键、外键 |
| `VARCHAR(n)` | `String` | 不要用 `TEXT` 代替 VARCHAR |
| `DECIMAL(10,2)` | `BigDecimal` | 金额字段，禁止用 double |
| `TINYINT(1)` | `Boolean` / `Integer` | 状态类字段 |
| `DATETIME` | `LocalDateTime` | 时间字段 |
| `JSON` | `String` (手动序列化) | 复杂结构，谨慎使用 |

## MyBatis SQL 规范

### 禁止使用 `${}` 拼接用户输入

```xml
<!-- ✅ 正确：使用 #{} 占位符 -->
<select id="findByName" resultType="User">
    SELECT * FROM t_user WHERE name = #{name} AND deleted = 0
</select>

<!-- ❌ 错误：${}直接拼接，存在SQL注入风险 -->
<select id="findByName" resultType="User">
    SELECT * FROM t_user WHERE name = '${name}'
</select>
```

**例外**：动态排序字段（`ORDER BY ${column}`）必须通过白名单校验后才可使用，并在代码注释中说明。

### 手写 SQL 必须加软删除条件

```xml
<!-- ✅ 正确 -->
<select id="findById">
    SELECT * FROM t_user WHERE id = #{id} AND deleted = 0
</select>

<!-- ❌ 错误：忘记软删除条件 -->
<select id="findById">
    SELECT * FROM t_user WHERE id = #{id}
</select>
```

### 批量操作必须有 WHERE 条件

```xml
<!-- ✅ 正确 -->
<update id="batchUpdateStatus">
    UPDATE t_order SET status = #{status}
    WHERE id IN
    <foreach collection="ids" item="id" open="(" separator="," close=")">
        #{id}
    </foreach>
    AND deleted = 0
</update>

<!-- ❌ 极度危险：无 WHERE 条件的批量更新，可能更新全表 -->
<update id="updateAllStatus">
    UPDATE t_order SET status = #{status}
</update>
```

### 避免全表扫描

- 查询条件字段必须有索引
- `LIKE '%xxx'` 无法走索引，只允许 `LIKE 'xxx%'`
- 避免在 WHERE 条件中对字段做函数运算（`WHERE DATE(created_at) = ?` → 改为范围查询）

## 高风险操作检查清单

在提交涉及以下操作的 change 前，必须经过 `/sql-risk-review` 审查：

- [ ] 新增或修改索引
- [ ] 批量 UPDATE / DELETE（特别是影响行数可能超过 1000 的）
- [ ] 新增大表的全表扫描查询
- [ ] 修改字段类型或长度（可能锁表）
- [ ] 删除字段（不可逆）
- [ ] 涉及金额的计算或更新

## 事务规范

- 事务尽量短，避免长事务持有锁
- `@Transactional` 只加在 Service 层，Controller 层禁止加
- 跨服务操作不要用单一数据库事务（考虑最终一致性方案）
- 事务方法避免捕获异常后不重新抛出（会导致事务不回滚）

```java
// ❌ 错误：捕获异常后不抛出，事务无法回滚
@Transactional
public void transfer() {
    try {
        deduct();
        add();
    } catch (Exception e) {
        log.error("转账失败", e); // 静默处理，事务不会回滚！
    }
}

// ✅ 正确
@Transactional
public void transfer() {
    deduct();
    add();
    // 异常自然向上抛，事务自动回滚
}
```
