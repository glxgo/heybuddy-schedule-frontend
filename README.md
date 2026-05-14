# 相伴课表（Frontend Only）

相伴课表是一款面向大学生的社交化课表应用。当前这份仓库用于维护 **Flutter 客户端**。

## 开源范围说明

这个仓库在对外公开时，**只开放前端客户端代码**，不包含以下内容：

- 后端 API 服务源码
- 数据库 schema / 迁移 / 运维部署配置
- 短信验证码服务配置
- OCR 代理服务配置
- 生产环境域名、IP、密钥、证书、签名文件
- 任何调试日志、测试数据库、运维记录

也就是说：

- `lib/`
- `android/`
- `ios/`
- `web/`
- `pubspec.yaml`
- `pubspec.lock`

这些属于客户端可公开范围；

- `server/`
- `devlog/`
- 本地数据库 / keystore / 私钥 / 运维资料

这些不应公开。

## API 地址配置

客户端不会再默认指向生产 API。

请在运行或打包时通过 `--dart-define` 显式传入后端地址：

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api
```

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example.com/api
```

如果不传，客户端会使用占位地址：

```text
https://example.com/api
```

## 本地开发建议

如果你在本地自己搭后端，可以这样启动：

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

> 真机调试时请把 `127.0.0.1` 替换成你电脑局域网 IP 或可访问的测试域名。

## Android 发布说明

发布签名文件和密码不应进入公开仓库。

本地打包依赖：

- `android/key.properties`
- 对应的 `.jks/.keystore` 文件

这些都应该保留在私有环境里。

## 隐私与 OCR 说明

AI 拍照识图功能依赖服务端代理进行模型调用。

在前端-only 开源版本中：

- 不应在客户端内置第三方模型 API Key
- 不应把生产 OCR 服务地址写死在仓库里
- 应在 README 中明确截图会被发送到你自己配置的服务端

## 前端-only 公共副本导出

当前仓库仍然保留了后端和运维相关内容，用于私有开发。
如果你准备把客户端代码公开，推荐不要直接把当前仓库改成 public，而是先导出一份前端-only 副本。

仓库根目录提供了导出脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\prepare_frontend_public_release.ps1
```

默认会导出到：

```text
D:\Workspace\heybuddy_schedule-public
```

它会保留：
- `lib/`
- `assets/`
- `android/`
- `ios/`
- `web/`
- `pubspec.yaml`
- `pubspec.lock`
- `README.md`
- `.gitignore`

并排除：
- `server/`
- `devlog/`
- 本地数据库
- keystore / `key.properties`
- 证书、公钥、日志、构建产物、生成文件

> 导出后仍建议你手动复查一遍，再发布到公开仓库。

## 后续建议

如果你准备正式公开这个仓库，建议在发布前再做一轮清理：

1. 把 `server/` 从公开仓库中剥离，或直接使用导出的前端-only 副本
2. 删除 `devlog/`、测试数据库、证书、公钥等资料
3. 确认 `key.properties`、`.env`、keystore 均未纳入版本控制
4. 再检查一遍客户端里是否还有生产域名 / IP / 私有服务信息
5. 公开前再次运行 `flutter analyze` 并手动验证登录、导入、OCR、好友等主流程
