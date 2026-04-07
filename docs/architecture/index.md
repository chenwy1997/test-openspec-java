# 项目架构总览

> 此文件是项目架构的权威说明。AI 在做任何涉及架构层面的变更前，必须先阅读本文件。

## 项目概述

本项目是一个企业级 Java Spring Boot 后台服务，提供 RESTful API 供前端（Web/App）消费。

**技术栈**：
- Java 21（LTS）+ Spring Boot 3.x
- MyBatis-Plus（数据访问，兼容手写 XML）
- MySQL 8.0（主数据库）
- Redis 7.x（缓存 / 分布式锁 / 限流）
- RabbitMQ / RocketMQ（异步消息，按需选用）
- Spring Security + JWT（认证授权）
- SpringDoc OpenAPI（接口文档）
- Docker + Docker Compose（容器化）
- Maven 3.9+（构建）

## 分层架构

```
┌─────────────────────────────────────┐
│           Controller 层              │  ← 接收请求、参数校验、响应包装
├─────────────────────────────────────┤
│            Service 层                │  ← 业务逻辑编排
├─────────────────────────────────────┤
│           Mapper/DAO 层              │  ← 数据访问（MyBatis）
├─────────────────────────────────────┤
│             数据库 (MySQL)            │
└─────────────────────────────────────┘
```

### 包结构规范

```
src/main/java/com/example/
├── controller/          # Controller 层
├── service/             # Service 接口
│   └── impl/            # Service 实现
├── mapper/              # MyBatis Mapper 接口
├── entity/              # 数据库实体（DO）
├── dto/                 # 数据传输对象（请求/响应）
│   ├── request/         # 请求 DTO
│   └── response/        # 响应 VO
├── config/              # 配置类（Spring Config）
├── common/              # 公共模块
│   ├── result/          # 统一返回 Result<T>
│   ├── exception/       # 自定义异常
│   └── enums/           # 公共枚举
└── util/                # 工具类
```

## 各层职责边界

### Controller 层
**职责**：接收 HTTP 请求，参数校验，调用 Service，包装响应
**禁止**：写任何业务逻辑、直接调用 Mapper、直接操作 Entity

```java
// ✅ 正确
@PostMapping("/user")
public Result<UserVO> createUser(@Valid @RequestBody CreateUserRequest req) {
    return Result.success(userService.createUser(req));
}

// ❌ 错误：Controller 里写业务逻辑
@PostMapping("/user")
public Result<UserVO> createUser(@RequestBody CreateUserRequest req) {
    if (userMapper.countByEmail(req.getEmail()) > 0) {
        throw new BizException("邮箱已存在");
    }
    // ...
}
```

### Service 层
**职责**：业务逻辑的核心承载，事务管理
**禁止**：直接处理 HTTP 相关对象（HttpServletRequest 等）

### Mapper 层
**职责**：SQL 执行，数据库 CRUD
**禁止**：写业务判断逻辑，不允许使用 `${}` 直接拼接用户输入

## 统一响应格式

所有 API 响应统一使用 `Result<T>` 包装：

```json
{
  "code": 200,
  "message": "success",
  "data": { }
}
```

错误响应：
```json
{
  "code": 400,
  "message": "参数校验失败：用户名不能为空",
  "data": null
}
```

## 异常处理

- 业务异常：抛出 `BizException`（自定义异常），由 `GlobalExceptionHandler` 统一处理
- 参数校验异常：框架自动处理（`MethodArgumentNotValidException`）
- 系统异常：不对外暴露堆栈，统一返回 500 并记录日志

## 认证授权

- JWT Token 在请求头 `Authorization: Bearer <token>` 中传递
- 路由权限通过 Spring Security 配置白名单/黑名单
- 接口级权限校验使用 `@PreAuthorize` 注解

## 相关文档

- [隐性约定与坑点](./implicit-contracts.md) — **重点阅读**
- [测试规范](../standards/testing.md)
- [数据库与 SQL 规范](../standards/database.md)
- [产品规则](../product/index.md)
