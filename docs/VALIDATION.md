# 本地验证记录

最近复验：2026-10-16，Asia/Shanghai（基线记录 2026-10-12）。本记录针对 MoonFolderPlan 本地源码，不是官方验收结论。

## 环境与命令

Windows 本地，`moonc v0.10.14+7d59c7ec9`，`moon 0.1.20260920`，Node.js 文件入口与 Python 独立验证。

```text
moon update
moon check --deny-warn --target all
moon build --deny-warn --target all
moon test --deny-warn --target all
moon run examples/demo
moon build cmd/files --target js --release --deny-warn
python scripts/verify_files.py
node scripts/verify_host.cjs
node scripts/render_demo.cjs
moon fmt
moon info
```

## 已验证行为

19 项核心测试在 wasm、wasm-gc、js、native 全部通过，共 76 次后端测试执行。
覆盖默认/自定义分类、空计划、隐藏文件选择、目录和链接跳过、中文名称、保留名称、
大小写重名、生成编号冲突、输入顺序不变性、资源限制、Int64 大小累计、报告副本防变更、
畸形 JSON 和深度限制。200 条合成大小写重名输入验证目标唯一与总大小守恒。

Python 在新建临时目录中独立验证：

- 预览分类与无写入副作用；
- HTML 预览产生、筛选结构及拒绝覆盖已有报告；
- 六类文件的复制字节、Python hashlib 摘要与原文件保留；
- 修改副本或修改原文件会阻止整个撤销预检；
- 成功撤销、重复撤销及原始内容保留；
- 收据目标路径跳转拒绝；
- 空目录、缺失目录、错误命令及错误输入类型。

Node Host 测试另外注入第二次物理复制失败，核对不完整收据只恢复已经成功的副本；
核对畸形路径、过时的大小信息在创建批次前拒绝；HTML 输出转义不可信文件名与目录字符串。
全部文件均为合成测试数据，没有操作个人下载目录或真实资料。

Windows 当前用户缺少符号链接创建权限，文件级符号链接流程未执行；纯 MoonBit 的跳过行为已测。
CI 脚本包含 Linux/Windows，尚未上传，因此没有线上测试或 Linux 实机文件入口验证证据。

## 限制与外部待办

没有大容量真实文件或生产用户验证。1 TiB 是校验上界，不是经过验证的文件性能承诺。
复制与撤销不是跨多文件原子事务，收据文件不是认证凭证，不能抵御恶意并发路径替换。
在完整撤销预检与逐项删除之间仍存在竞争窗口；改变内容的用户进程应先停止。
不保证所有文件系统的 Unicode 等价、名称长度及磁盘权限行为。

截至 2026-10-12 为仅本地开发；2026-10-16 按用户授权准备首次源码上传，未代办官方报名。当前远端证据以相应提交的 Actions 为准。
正式申报所需不少于 10 次有效提交尚未满足；Mooncakes 安装及官方审核也需分别取得实际证据。
申报书为本地参考材料，并已在 `.gitignore` 排除，不包含个人联系方式。
