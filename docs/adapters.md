# 学校适配器与教务入口维护说明

这份文档用于记录：当新增一所学校、接入新的教务系统适配器，或修改学校教务在线入口时，需要改哪些文件。

## 目录结构

```
index/
  schools_index.yaml    # 学校适配器索引（YAML 格式）
resources/
  <SCHOOL_ID>/
    adapters.yaml       # 学校元数据
    <script>.js         # 适配脚本
assets/
  schools/
    schools.json        # 学校选择页数据（按省份分组）
```

## 1. 适配脚本放哪里

教务系统解析脚本按学校分目录存放：

- `resources/<SCHOOL_ID>/`

示例：

- `resources/JXNU/jxnu.js`
- `resources/GDUST/gdust.js`

每个学校目录下同时需要一份 `adapters.yaml` 元数据文件。

## 2. 适配器索引放哪里

适配器注册表放在：

- `index/schools_index.yaml`（YAML 格式）

这里负责告诉客户端：

- `school_id` 是什么
- `adapter_id` 是什么
- 对应的教务入口 `import_url` 是什么
- 应该加载哪个脚本文件 `js_file`
- 资源文件夹 `resource_folder`

新增或修改学校适配器时，至少要保证下面几个字段正确：

- `school_id`
- `adapter_id`
- `import_url`
- `js_file`
- `resource_folder`

其中：

- `js_file` 必须和 `resources/<SCHOOL_ID>/` 中的真实文件名一致
- `resource_folder` 必须和 `resources/` 下的目录名一致
- `import_url` 应填写实际教务系统入口，而不是学校官网首页

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

## 4. 三个文件之间必须保持一致的字段

下面这些字段在三个文件里必须能对上：

- `schools_index.yaml` 的 `school_id` ↔ `schools.json` 的 `schoolId`
- `schools_index.yaml` 的 `adapter_id` ↔ `schools.json` 的 `adapterId`
- `schools_index.yaml` 的 `resource_folder` ↔ `resources/` 下的目录名
- `schools_index.yaml` 的 `js_file` ↔ `resources/<SCHOOL_ID>/` 下的脚本文件名

推荐理解方式：

- `schools.json` 决定"用户选学校时看到什么、先打开哪个网址"
- `schools_index.yaml` 决定"这个学校最终加载哪份适配脚本、在哪个资源目录"
- `resources/<SCHOOL_ID>/adapters.yaml` 决定"这个适配器的详细元数据"

## 5. 新增一所学校时的最小步骤

1. 在 `resources/<SCHOOL_ID>/` 下新增适配脚本和 `adapters.yaml`
2. 在 `index/schools_index.yaml` 注册该适配器
3. 在 `assets/schools/schools.json` 增加学校条目
4. 确认 `school_id`、`adapter_id`、`js_file`、`resource_folder` 完全对应
5. 手动验证 WebView 是否打开正确教务入口，导入是否成功

## 6. 修改学校教务在线入口时的最小步骤

如果只是学校入口变了，也不要只改一个地方。

至少要检查并通常同时更新：

- `index/schools_index.yaml` 中的 `import_url`
- `assets/schools/schools.json` 中的 `url`

## 7. 本地调试建议

如果先在单独测试工具里调试脚本，调通后再复制到：

- `resources/<SCHOOL_ID>/`

正式接入前，务必确认：

- 文件名已经从临时名改为正式名
- 索引 YAML 已指向正式文件名和正确的 `resource_folder`
- 学校入口 URL 已改成真实教务入口
