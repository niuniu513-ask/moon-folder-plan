# MoonFolderPlan

面向下载文件、学习资料、照片和办公文件的本地分类整理工具。
先查看每个文件将放到哪里，再按明确命令复制到全新的分类目录；原文件保留。
整理后可用收据撤销仍与原文件一致的复制品，避免误删修改过的内容。

## 日常用途

1. **下载目录整理：** 输入包含 PDF、图片、压缩包和其他文件的目录，预览分类与重名处理，
   执行后得到新的分类副本目录，下载目录中的原文件不移动。
2. **嵌入开发者自己的工具：** 输入文件元数据和扩展名分类规则，直接调用纯 MoonBit `plan`，
   获得确定性的目标位置、冲突编号和 JSON 报告，供自己的界面或执行器使用；规划 API 不读写文件。
3. **撤回整理批次：** 输入某次复制产生的收据，核对现存复制品及原文件摘要；
   全部符合时删除复制品，任一内容变化则拒绝撤销。收据与目录保留，不替代备份恢复。

这些是实际工具流程，尚无外部用户采用或生产环境验证。分类仅依据扩展名，不鉴定文件内容。

## 已实现

- 纯 MoonBit 规划库：默认七类分类、可配置扩展名规则、明确的跳过原因、Int64 字节统计。
- 固定 UTF-16 码元顺序规划，ASCII 大小写重名用编号处理；输入顺序不改变结果。
- 名称检查拒绝路径跳转、分隔符、常见 Windows 保留名称、尾部点/空格等。
- Node.js 文件入口：只读预览、独占新批次的复制、摘要核对、写入收据和撤销预检。
- 可搜索、按分类筛选的独立 HTML 预览页，无需上传文件或运行网络服务。
- 核心支持 wasm、wasm-gc、js、native；文件入口仅支持 Node.js / js。

## 构建与运行

需要 MoonBit `moonc v0.10.14+7d59c7ec9`、Node.js 22 或更新版本；独立验证需要 Python 3。
本地编译器未加入 PATH 时，PowerShell 先设置：

```powershell
$env:MOON_HOME = 'D:\moonbit-toolchain'
$env:PATH = "$env:MOON_HOME\bin;$env:PATH"
```

在项目目录执行：

```powershell
moon check --deny-warn --target all
moon build --deny-warn --target all
moon test --deny-warn --target all
moon run examples/demo
moon build cmd/files --target js --release --deny-warn
```

文件命令请替换为自己的目录；路径含空格时加引号：

```powershell
# 只读预览，输出 JSON。
node scripts/moonfolder.cjs preview "D:/Downloads"
# 创建新的 HTML 预览文件；已有报告不会被覆盖。
node scripts/preview.cjs "D:/Downloads" "D:/preview.html"
# 复制到 Downloads 内全新的 MoonFolderPlan-时间-随机标识 目录。
node scripts/moonfolder.cjs copy "D:/Downloads"
# 用上一步实际输出的收据路径撤销复制品，原文件保留。
node scripts/moonfolder.cjs undo "D:/Downloads/MoonFolderPlan-实际批次/receipt.json"
```

每次 `copy` 重新扫描并规划，不读取先前预览作为授权文件；目录变化后应重新预览。
复制需要额外磁盘空间。批次目录始终新建，目标副本使用独占创建，原文件不删除。
中途失败会保留不完整收据，错误信息给出恢复路径；撤销仅处理摘要可确认的现存复制品。
撤销预检发现任何副本或原文件发生变化，会拒绝删除整个批次的文件；缺失副本会跳过。
重复撤销可返回零删除。收据、空分类目录、批次目录保留作为记录，不递归清理目录。

## MoonBit API

```moonbit
let entries : Array[@folder.Entry] = [
  { name: "课程.PDF", size: 1024, kind: File },
  { name: "photo.jpg", size: 4096, kind: File },
]
let result = @folder.plan(entries)
let report = result.to_json().stringify()
```

API 会抛出 `PlanError`，应在可抛错函数或 `try/catch` 中使用。
导入名为 `niuniu513-ask/moon-folder-plan`，目录内示例提供实际导入配置。
`plan` 的 `rules` 参数接收完整替换规则，例如 `pdf -> Study`；`include_hidden` 可显式包含隐藏文件。
CLI 使用默认规则并跳过隐藏文件。新项目未发布，不能声称 `moon add` 已可安装。

## 验证

```powershell
python scripts/verify_files.py
node scripts/verify_host.cjs
node scripts/render_demo.cjs
```

文件测试只创建临时合成文件，独立核对原文件内容、复制字节、Python hashlib 摘要、变化拒绝与撤销结果。
Host 测试注入第二次复制失败，核对不完整收据与部分成功副本的恢复。
`docs/demo-preview.html` 是虚构样本的预览，验证记录见 [docs/VALIDATION.md](docs/VALIDATION.md)。

## 范围与差异

当前只处理一个目录的直接条目，最多 4096 条、256 条分类规则；单项大小最多 1 TiB，
名称最多 180 个 UTF-16 码元。摘要以 1 MiB 缓冲读取，不把大文件整体装入内存；尚未验证 1 TiB 实际文件。
编号后的目标名称、文件系统剩余空间、权限和具体文件系统限制仍可能导致复制失败。
只覆盖 ASCII 名称折叠与列出的名称规则，不宣称完整 Unicode 规范化或全部平台等价性。
没有内容识别、AI 自动分类、内容去重、递归整理、原文件移动、压缩/备份格式、权限/时间戳完整保留或后台监控。

本工具面向单个用户控制的本地目录。收据是本地操作记录，不是经过认证的凭证；不接收不可信第三方收据。
检查与文件操作之间仍有竞争窗口，不适用于恶意进程同时替换文件/目录的场景，不承诺多文件事务或断电原子性。
请在实际执行前关闭正在改写文件的应用。分类规则由用户决定，库不判断文件是否重要。

`moonportcheck` 已覆盖名称可移植性审计，`fsx` 已覆盖底层文件操作，`moonrestore` 已覆盖增量备份，
`MoonEvidence` 已覆盖证据包与摘要复核。本项目的核心交付是**分类预览—新批次复制整理—核对撤销**，
不是重新实现上述完整产品。存在名称检查、复制和摘要等基础能力交集。
2026-10-16 已按分类整理用途复核 3,038 条生态元数据与相邻项目的现行说明，暂未识别同用途成熟项目；
功能交集、新增价值与检索局限见 [SOURCES.md](SOURCES.md)。完整流程组合不同不能单独证明初审合规。

## 开发与提交状态

自有源码 MIT；依赖仅为 MoonBit 标准库及 Node.js 内置模块，未复制相似项目源码。
源码仓库：<https://github.com/niuniu513-ask/moon-folder-plan>。CI 固定已验证的 MoonBit 工具链，覆盖 Linux/Windows；
实际状态以仓库 Actions 对应提交为准。尚未发布 Mooncakes，不声称注册表已可安装或官方审核通过。
本项目此前仅本地开发；现有代码作为一次真实初始提交公开，不拆分已有文件制造开发历史。
申报书与报名资料保持私有，不属于公开源码。
