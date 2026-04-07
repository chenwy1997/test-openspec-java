# 测试规范

> AI 在编写测试代码时，必须遵守本规范。

## 测试策略

本项目采用**单元测试为主、集成测试为辅**的策略：

- **单元测试**：覆盖 Service 层业务逻辑（必须）
- **集成测试**：覆盖关键 Controller 接口（重要接口必须）
- **不要求**：Mapper 层的独立单元测试（由集成测试间接覆盖）

## 测试框架

- JUnit 5（`@ExtendWith(MockitoExtension.class)`）
- Mockito（Mock 依赖）
- Spring Boot Test（集成测试）
- AssertJ（断言）

## 单元测试规范

### 测试类命名

```
被测类名 + Test.java
例：UserServiceImplTest.java
```

### 测试方法命名

格式：`方法名_场景描述_预期结果`

```java
// ✅ 正确
@Test
void createUser_whenEmailAlreadyExists_thenThrowBizException() { }

@Test
void createUser_whenValidInput_thenReturnUserVO() { }

// ❌ 错误
@Test
void testCreate() { }
```

### 测试结构（AAA 原则）

```java
@Test
void createUser_whenValidInput_thenReturnUserVO() {
    // Arrange（准备）
    CreateUserRequest req = new CreateUserRequest();
    req.setEmail("test@example.com");
    when(userMapper.countByEmail("test@example.com")).thenReturn(0);

    // Act（执行）
    UserVO result = userService.createUser(req);

    // Assert（断言）
    assertThat(result).isNotNull();
    assertThat(result.getEmail()).isEqualTo("test@example.com");
}
```

## 覆盖要求

每个 Service 方法至少覆盖：

| 场景类型 | 是否必须 |
|---------|---------|
| 正常路径（happy path） | 必须 |
| 参数为 null / 空值边界 | 必须 |
| 数据不存在的情况 | 按需（存在数据库查询时必须） |
| 业务异常路径（如重复、权限不足） | 必须 |
| 系统异常（如数据库超时） | 不强制 |

## 禁止事项

- 禁止测试只写 happy path，不写异常路径
- 禁止在测试中连接真实数据库（使用 Mock 或内存数据库）
- 禁止测试之间相互依赖（每个测试必须可以独立运行）
- 禁止在生产代码里为了测试而暴露 `package-private` 方法

## 测试覆盖说明格式

当某个场景**刻意不测试**时，必须在 PR 描述或 `prepare-review` 输出中说明：

```
测试覆盖说明：
- ✅ 正常创建用户
- ✅ 邮箱重复异常
- ⏭️ 数据库超时场景：当前阶段暂不覆盖，下一迭代补充
```

## 运行测试命令

```bash
# 运行所有测试
mvn test

# 运行指定测试类
mvn test -Dtest=UserServiceImplTest

# 运行带覆盖率报告（需要 JaCoCo 插件）
mvn test jacoco:report
```
