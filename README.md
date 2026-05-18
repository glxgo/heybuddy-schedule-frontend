# 相伴课表（HeyBuddy Schedule）

相伴课表是一款面向大学生的社交化课表管理应用。
它不只是在做“看课表”，而是希望把 **课程安排、好友关系、共同空闲时间、轻量交流** 连接起来，让课表成为校园生活里的一个小入口。

当前公开仓库已经公开 **Flutter 客户端代码**，并会在同一个仓库中开放 **脱敏后的后端基础能力**。当前仓库仍以前端客户端为主，适合用于前端开发、界面迭代、课表导入适配，以及公共后端模块的协作完善。

由于每个高校的教务系统略有不同，所有适配量比较大。如果你有能力适配教务系统，欢迎加入[**适配**](https://github.com/glxgo/heybuddy_warehouse)贡献队伍。

非常感谢 **拾光适配仓库** 提供的解析规则与开源思路支持。

## 预览图

![预览图1](/picture/预览.png "预览图")

## 项目定位

相伴课表聚焦几个核心方向：

- **个人课表管理**：让课程查看、编辑、调整更直观
- **多方式导入**：支持教务系统导入与截图识别导入
- **好友课表协同**：不仅看自己的课，也能看好友和共同空闲时间
- **轻社交体验**：围绕课程场景延伸好友、聊天、分享等能力
- **仓库开源**：公开 Flutter 客户端，开放脱敏后的后端基础框架、通用工具与公共逻辑

## 功能介绍

### 1. 账号与基础信息
- 手机号注册、登录、找回密码
- 学校选择、基础资料维护
- 本地保存登录状态与部分用户设置

### 2. 课表导入
- **教务系统导入**：通过 WebView 登录教务系统后解析课程数据
- **截图识别导入**：支持拍照或从相册选择课表截图进行识别
- **适配器机制**：仓库内置学校与适配脚本资源，方便扩展不同教务系统
- **导入后可调整**：导入完成后仍可手动编辑课程信息

### 3. 课表展示
- **日视图**：按时间线查看当天课程安排
- **周视图**：按周查看完整课表
- **好友课表**：支持查看指定好友的课表
- **共同课表**：对比双方有课 / 无课状态，辅助约时间
- **课表管理**：支持课程维护与表格内容调整

### 4. 好友与社交
- 手机号搜索添加好友
- 好友请求发送、接受、拒绝
- 好友主页与好友课表查看
- 一对一文字聊天
- 课程场景下的轻量社交扩展能力

### 5. 个人中心
- 个人资料展示与编辑
- 学校 / 学期等信息切换
- 关于页、许可信息查看
- 面向公开仓库的基础配置与说明

## 当前仓库的开源范围

当前公开仓库**当前以 Flutter 客户端为主**，在**仓库**公开脱敏后端基础框架、通用工具、配置模板与接口示例。

当前**没有完整公开**以下内容：

- 完整生产后端 API 服务实现
- 真实数据库 schema / 迁移 / 运维部署配置
- 短信验证码服务的生产实现与私有配置
- OCR 代理服务的生产实现与私有配置
- 管理员接口、后台管理端、权限控制、风控逻辑、盈利逻辑
- 生产环境域名、IP、密钥、证书、签名文件
- 调试日志、测试数据库、运维记录等敏感资料


## 技术栈

### 客户端
- **Flutter / Dart**
- **flutter_riverpod**：状态管理
- **go_router**：路由管理
- **dio**：网络请求
- **sqflite**：本地数据存储
- **shared_preferences**：轻量配置持久化
- **webview_flutter**：教务系统登录与页面桥接
- **image_picker**：拍照 / 相册导入
- **permission_handler**：权限管理

### 已开放的后端能力
- 通用路由骨架与基础服务封装
- 公共中间件、错误处理与配置模板
- 接口示例、mock 与文档化说明

### 项目特点
- 使用 `--dart-define` 注入后端地址，避免把生产 API 写死到公开仓库
- 学校资源与适配脚本分离，便于维护扩展
- 公开仓库聚焦客户端体验，并会在同仓库逐步补充可公开的后端基础能力

## 项目结构

```text
heybuddy_schedule/
├── assets/
│   ├── adapters/      # 教务系统适配脚本
│   ├── images/        # 图片资源
│   └── schools/       # 学校数据
├── lib/
│   ├── config/        # 路由、主题、常量配置
│   ├── models/        # 数据模型
│   ├── providers/     # 状态管理
│   ├── screens/       # 页面
│   ├── services/      # 客户端服务
│   └── widgets/       # 公共组件
├── android/
├── ios/
├── web/
├── test/
├── pubspec.yaml
└── README.md
```

## 快速开始本项目

### 环境要求
- Flutter 3.x
- Dart SDK `^3.11.5`

### 安装依赖

```bash
flutter pub get
```

### 本地运行

请在运行时通过 `--dart-define` 显式传入后端地址：

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api
```

如果你在本地联调后端，也可以这样启动：

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

> 真机调试时，请把 `127.0.0.1` 替换成你电脑的局域网 IP 或可访问的测试域名。

### 构建发布

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example.com/api
```

> 当前 Android release 仅打包 `armeabi-v7a` 和 `arm64-v8a`，不会再带上 `x86_64`。

如果未传入 `API_BASE_URL`，客户端会使用占位地址：

```text
https://example.com/api
```

### Mock 后端演示

仓库已附带一个 **仅用于本地演示** 的 mock API，方便在不接入真实后端的情况下联调 Flutter 客户端界面。

```bash
cd server/mock-api
npm install
npm start
```

> Mock 后端默认监听 `http://localhost:3000`，所有接口返回固定示例数据，不连接数据库、不发送短信、不调用第三方模型。

联调时：

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
```

更多说明见 [server/mock-api/README.md](server/mock-api/README.md)。


 
## 致谢

本项目在 **教务系统适配桥接规范、适配器组织方式与相关思路** 上，参考了 [拾光适配仓库](https://github.com/XingHeYuZhuan/shiguang_warehouse) 开源社区公开提供的方案。

感谢拾光仓库项目及其社区贡献者的工作与分享。

拾光仓库采用 **MIT License** 发布。依据 MIT 许可证关于 **保留原始版权声明与许可说明** 的要求，本项目在此保留来源致谢说明；如果后续分发内容中包含直接改编或移植自原项目的代码、脚本或其他受 MIT 许可覆盖的内容，也应继续保留相应的版权与许可文本。

## 如何参与

如果你也对校园产品、课表工具、教务适配、Flutter 客户端开发或后端基础能力建设感兴趣，欢迎通过以下方式参与：

1. Fork 仓库并进行修改
2. 提交 Pull Request
3. 提交 Issue 反馈问题或提出建议


## 相关链接

- 主页：[https://github.com/glxgo/heybuddy-schedule-frontend](https://github.com/glxgo/heybuddy-schedule-frontend)
- 适配脚本仓库：[https://github.com/glxgo/heybuddy_warehouse](https://github.com/glxgo/heybuddy_warehouse)
- 本人的博客：[https://glxgo.xin/](https://glxgo.xin/)

---

如果这个项目刚好也让你觉得“课表不该只是冷冰冰的一张表”，欢迎一起把它打磨得更好。
如果你非常支持本人的项目，可以通过**赞赏**的方式支持我，以运营成本