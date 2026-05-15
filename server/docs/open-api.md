# 相伴课表 API 接口文档

> 本文档描述相伴课表客户端调用的接口路径、请求/响应格式。
> 不含真实数据库结构、RLS 策略、字段级安全策略或内部实现细节。

## 通用约定

- 基础路径：`/api`
- 认证方式：请求头 `Authorization: Bearer <token>`
- 统一响应格式：`{ "code": 0, "msg": "ok", "data": ... }`
  - `code: 0` 成功，`code: 1` 业务错误，`code: 401` 未登录，`code: 500` 服务端错误
- 请求体：`Content-Type: application/json`

## 健康检查

### `GET /api/ping`

无需认证。

**响应：**
```json
{ "code": 0, "msg": "pong", "time": "2026-01-01T00:00:00.000Z" }
```

## 认证

### `POST /api/auth/register`

使用密码注册。

**请求：**
```json
{ "phone": "13800000000", "password": "123456", "nickname": "昵称" }
```

**响应：**
```json
{ "code": 0, "msg": "注册成功", "data": { "token": "...", "userId": "..." } }
```

### `POST /api/auth/login`

手机号 + 密码登录。

**请求：**
```json
{ "phone": "13800000000", "password": "123456" }
```

**响应：**
```json
{ "code": 0, "msg": "登录成功", "data": { "token": "...", "userId": "..." } }
```

### `POST /api/auth/register-sms`

使用短信验证码注册。

**请求：**
```json
{ "phone": "13800000000", "password": "123456", "nickname": "昵称", "smsCode": "123456" }
```

**响应：**
```json
{ "code": 0, "msg": "注册成功", "data": { "token": "...", "userId": "..." } }
```

### `POST /api/auth/forgot-password/send-code`

发送找回密码验证码。

**请求：** `{ "phone": "13800000000" }`

### `POST /api/auth/forgot-password/reset`

重置密码。

**请求：**
```json
{ "phone": "13800000000", "smsCode": "123456", "password": "新密码" }
```

## 短信

### `POST /api/sms/send`

发送短信验证码。

**请求：**
```json
{ "phone": "13800000000" }
```

> 生产环境需接入短信服务商 SDK；mock 环境固定返回测试验证码 `123456`。

## 用户

### `GET /api/user/profile`

需认证。获取当前用户资料。

**响应：**
```json
{
  "code": 0,
  "data": {
    "id": "...",
    "phone": "138****0000",
    "nickname": "昵称",
    "avatarUrl": null,
    "schoolName": "示例大学",
    "schoolId": "...",
    "createdAt": "2026-01-01T00:00:00.000Z"
  }
}
```

### `PUT /api/user/profile`

需认证。更新用户资料。

**请求：**
```json
{ "nickname": "新昵称", "schoolName": "新学校" }
```

### `PUT /api/user/phone`

需认证。修改绑定手机号。

**请求：**
```json
{ "phone": "13900000000", "smsCode": "123456" }
```

### `PUT /api/user/password`

需认证。修改密码。

**请求：**
```json
{ "oldPassword": "旧密码", "newPassword": "新密码" }
```

## 课程

### `GET /api/courses`

需认证。获取当前学期课程。

**查询参数：** `?semester=2025-2026-2`

**响应 data 内每条课程字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 课程 ID |
| name | string | 课程名 |
| teacher | string | 教师 |
| location | string | 上课地点 |
| day_of_week | int(1-7) | 周一~周日 |
| start_period | int | 开始节次 |
| end_period | int | 结束节次 |
| weeks | string | 周次，如 `"1-16"` |
| color | string | 显示颜色 |
| semester | string | 学期 |

### `POST /api/courses`

需认证。添加一门课程。

### `POST /api/courses/batch`

需认证。批量导入课程。

**请求：**
```json
{
  "courses": [
    { "name": "课程名", "dayOfWeek": 1, "startPeriod": 1, "endPeriod": 2, "weeks": "1-16" }
  ]
}
```

### `DELETE /api/courses/:id`

需认证。删除课程。

## 好友

### `GET /api/friends`

需认证。获取好友列表。

### `POST /api/friends/request`

需认证。发送好友请求。

**请求：** `{ "phone": "13800000000" }`

### `PUT /api/friends/:id/accept`

需认证。接受好友请求。

### `PUT /api/friends/:id/reject`

需认证。拒绝好友请求。

### `PUT /api/friends/:id/remark`

需认证。设置好友备注。

**请求：** `{ "remark": "备注文字" }`

### `DELETE /api/friends/:id`

需认证。删除好友。

### `GET /api/friends/:friendId/courses`

需认证。查看好友课表。

## 好友纪念日

### `GET /api/friends/:friendId/anniversaries`

需认证。获取与好友的纪念日列表。

### `POST /api/friends/:friendId/anniversaries`

需认证。添加纪念日。

**请求：** `{ "name": "纪念日名称", "targetDate": "2026-06-01" }`

### `PUT /api/friends/:friendId/anniversaries/:id`

需认证。修改纪念日。

### `DELETE /api/friends/:friendId/anniversaries/:id`

需认证。删除纪念日。

## 聊天

### `GET /api/messages/:friendId`

需认证。获取与好友的聊天记录（最近 100 条）。

### `POST /api/messages`

需认证。发送消息。

**请求：**
```json
{ "receiverId": "...", "content": "消息内容", "contentType": "text" }
```

## OCR 截图识别

### `POST /api/ocr/recognize`

需认证。上传课表截图进行识别。

**请求：**
```json
{
  "imageBase64": "data:image/jpeg;base64,...",
  "config": {
    "morningStart": "08:00",
    "afternoonStart": "14:00",
    "eveningStart": "19:00",
    "periodMinutes": 45,
    "morningCount": 5,
    "afternoonCount": 4,
    "eveningCount": 2
  }
}
```

> 生产环境需自行接入视觉模型 API；图片会上传至你配置的服务端并可能转发给模型服务，请在应用中告知用户。

## 显示偏好

### `GET /api/prefs`

需认证。获取课表显示偏好。

### `PUT /api/prefs`

需认证。更新显示偏好。

## 接口列表总览

| 方法 | 路径 | 需认证 |
|------|------|--------|
| GET | `/api/ping` | 否 |
| POST | `/api/auth/register` | 否 |
| POST | `/api/auth/login` | 否 |
| POST | `/api/auth/register-sms` | 否 |
| POST | `/api/auth/forgot-password/send-code` | 否 |
| POST | `/api/auth/forgot-password/reset` | 否 |
| POST | `/api/sms/send` | 否 |
| GET | `/api/user/profile` | 是 |
| PUT | `/api/user/profile` | 是 |
| PUT | `/api/user/phone` | 是 |
| PUT | `/api/user/password` | 是 |
| GET | `/api/courses` | 是 |
| POST | `/api/courses` | 是 |
| POST | `/api/courses/batch` | 是 |
| DELETE | `/api/courses/:id` | 是 |
| GET | `/api/friends` | 是 |
| POST | `/api/friends/request` | 是 |
| PUT | `/api/friends/:id/accept` | 是 |
| PUT | `/api/friends/:id/reject` | 是 |
| PUT | `/api/friends/:id/remark` | 是 |
| DELETE | `/api/friends/:id` | 是 |
| GET | `/api/friends/:friendId/courses` | 是 |
| GET | `/api/friends/:friendId/anniversaries` | 是 |
| POST | `/api/friends/:friendId/anniversaries` | 是 |
| PUT | `/api/friends/:friendId/anniversaries/:id` | 是 |
| DELETE | `/api/friends/:friendId/anniversaries/:id` | 是 |
| GET | `/api/messages/:friendId` | 是 |
| POST | `/api/messages` | 是 |
| POST | `/api/ocr/recognize` | 是 |
| GET | `/api/prefs` | 是 |
| PUT | `/api/prefs` | 是 |

> 本文档不包含管理员接口、真实数据库结构、权限策略或内部部署配置。
> 如需接入你自己的后端，请参考 mock 后端目录 `server/mock-api/`。
