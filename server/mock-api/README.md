# 相伴课表 Mock API

这是一个**仅用于本地开发与演示**的 mock 后端。它为相伴课表 Flutter 客户端提供固定示例数据，帮助你快速跑通 UI 联调，**不是生产后端**。

## ⚠ 安全与使用边界

- **仅限本地开发**：不要把 mock 部署到公网。
- **固定凭据仅用于演示**：所有请求使用固定 token，验证码固定为 `123456`。
- **无真实业务**：不包含数据库、短信发送、OCR 调用、权限校验或真实账号体系。

## 覆盖的接口

| 接口 | 返回 |
|------|------|
| `GET /api/ping` | `{ pong }` |
| `POST /api/auth/register` | 固定 token |
| `POST /api/auth/login` | 固定 token |
| `POST /api/auth/register-sms` | 固定 token（验证码 `123456`） |
| `GET /api/user/profile` | 示例用户 |
| `PUT /api/user/profile` | 更新成功 |
| `GET /api/courses` | 示例课程列表 |
| `POST /api/courses` | 回显请求体 |
| `POST /api/courses/batch` | 导入成功 |
| `DELETE /api/courses/:id` | 删除成功 |
| `GET /api/friends` | 示例好友列表 |
| `GET /api/friends/:friendId/courses` | 示例好友课程 |
| `POST /api/friends/request` | 请求已发送 |
| `PUT /api/friends/:id/accept` / `reject` / `remark` | 操作成功 |
| `DELETE /api/friends/:id` | 已删除 |
| `GET /api/messages/:friendId` | 示例聊天记录 |
| `POST /api/messages` | 回显消息 |
| `POST /api/ocr/recognize` | mock 识别结果 |
| `POST /api/sms/send` | mock 发送（测试验证码 `123456`） |
| `GET /api/friends/:friendId/anniversaries` | 示例纪念日 |
| `GET /api/prefs` / `PUT /api/prefs` | 示例偏好 |

## 快速开始

```bash
cd server/mock-api
npm install
npm start
```

启动后默认监听 `http://localhost:3000`。

## 测试

```bash
# 健康检查
curl http://localhost:3000/api/ping

# 登录并获取 token
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800000000","password":"123456"}'

# 用 token 查课程
curl http://localhost:3000/api/courses \
  -H "Authorization: Bearer mock-token-heybuddy-2026"
```

## 切换真实后端

编辑 Flutter 客户端的构建/运行参数：

```bash
flutter run --dart-define=API_BASE_URL=https://your-real-api.example.com/api
```
