# 学校适配器与教务入口维护说明

这份文档用于记录：当新增一所学校、接入新的教务系统适配器，或修改学校教务在线入口时，需要改哪些文件。

## 1. 适配脚本放哪里

教务系统解析脚本统一放在：

- `assets/adapters/`

示例：

- `assets/adapters/jxnu.js`
- `assets/adapters/gdust.js`

脚本文件名应尽量使用清晰、稳定的学校缩写命名，不要继续使用临时名如 `school.js`。

## 2. 适配器索引放哪里

适配器注册表放在：

- `assets/adapters/schools_index.json`

这里负责告诉客户端：

- `schoolId` 是什么
- `adapterId` 是什么
- 对应的教务入口 `importUrl` 是什么
- 应该加载哪个脚本文件 `jsFile`

新增或修改学校适配器时，至少要保证下面几个字段正确：

- `schoolId`
- `adapterId`
- `importUrl`
- `jsFile`

其中：

- `jsFile` 必须和 `assets/adapters/` 中的真实文件名一致
- `importUrl` 应填写实际教务系统入口，而不是学校官网首页

## 3. 学校列表入口放哪里

学校选择页显示的数据放在：

- `assets/schools/schools.json`

这里负责：

- 学校名称展示
- 学校分类 / 系统类型
- WebView 初始打开的 `url`
- 对应适配器的 `adapterId`
- 对应学校的 `schoolId`

新增学校或修改学校入口时，要同步更新这里的学校条目。

## 4. 两个 JSON 之间必须保持一致的字段

下面这些字段在两个 JSON 文件里必须能对上：

- `schoolId`
- `adapterId`

推荐理解方式：

- `schools.json` 决定“用户选学校时看到什么、先打开哪个网址”
- `schools_index.json` 决定“这个学校最终加载哪份适配脚本”

## 5. 新增一所学校时的最小步骤

1. 在 `assets/adapters/` 新增适配脚本
2. 在 `assets/adapters/schools_index.json` 注册该适配器
3. 在 `assets/schools/schools.json` 增加学校条目
4. 确认 `schoolId`、`adapterId`、`jsFile` 完全对应
5. 手动验证 WebView 是否打开正确教务入口，导入是否成功

## 6. 修改学校教务在线入口时的最小步骤

如果只是学校入口变了，也不要只改一个地方。

至少要检查并通常同时更新：

- `assets/adapters/schools_index.json` 中的 `importUrl`
- `assets/schools/schools.json` 中的 `url`

## 7. 本地调试建议

如果先在单独测试工具里调试脚本，调通后再复制到：

- `assets/adapters/`

正式接入前，务必确认：

- 文件名已经从临时名改为正式名
- 索引 JSON 已指向正式文件名
- 学校入口 URL 已改成真实教务入口
