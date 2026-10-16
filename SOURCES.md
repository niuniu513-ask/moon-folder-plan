# 检索范围、差异与来源

检索日期：2026-10-12，Asia/Shanghai。结论是有限范围内的差异判断，不能证明全球唯一。
用户接受的标准为：没有在检索范围发现同类完整项目，核心问题、处理机制与交付成果有实质差异。

## 范围与证据

- Mooncakes `/api/v0/modules` 取得 2,945 个模块的名称、说明、关键词及来源地址。
- 检索组织整理、分类、文件分拣、rename、directory、undo、copy-plan 等相关语义，
  同时检查已知邻近项目。完整索引保存在项目外的私有研究目录。
- GitHub 名称/说明/README 检索包括 `MoonBit file organizer`、`MoonBit batch rename`、
  `MoonBit file sorting`、`MoonBit file organization`、`MoonBit organize files undo`、
  `organizer language:MoonBit`、`文件整理 MoonBit in:name,description,readme` 和项目名称。
- 广义 README 检索得到集合类仓库和个人项目管理应用，未把关键词命中直接视为同类。
  查阅 `CAIMEOX/circular` README 后确认其描述的是任务、笔记与专注会话管理。
- 查看邻近项目 README 与模块元数据，区分功能交集和相同产品流程。
  记录见 [docs/research/search-evidence.json](docs/research/search-evidence.json)。

## 邻近项目与不同之处

| 项目 | 已读证据 | 本项目差异与交集 |
|---|---|---|
| AlexenderSokolov/moonportcheck@0.2.0 | 发布元数据、GitHub README | 主体是可移植性审计、快照/基线与 CI 门禁；本项目提供分类目标、新批次复制、核对撤销。名称规则存在交集，因此不声称零功能重叠。 |
| chensuiyi/fsx@0.3.0 | 发布元数据；来源仓库 README 不可读取（404） | 主体是 atomic write、mkdir、rotation、flock 等底层操作；不能据元数据断言其所有源码没有整理功能，保留证据缺口。 |
| bzhangui/moonrestore | GitHub README、发布元数据 | 主体是增量备份、内容寻址快照和恢复历史版本；本项目没有备份仓库或历史版本，只分类复制当前直接文件并记录撤销。复制、校验存在基础交集。 |
| wenlittle/MoonEvidence | GitHub README | 主体是可信证据包、稳定摘要及可选存证；本项目不是证据证明或区块链工具，只用摘要阻止撤销修改过的复制品。 |
| CAIMEOX/circular | GitHub README | 主体是个人任务、资料与学习项目管理，不是文件系统分类复制工具。 |

未在上述范围识别“扩展名规则分类 + 稳定冲突编号 + 分类预览 + 独立批次复制 + 核对撤销”的同类完整 MoonBit 项目。
这里只比较取得的证据；未公开仓库、元数据缺失、检索未命中或来源无法访问都可能造成遗漏。
在其他语言生态中，文件整理工具是成熟类别，本项目不是全球首创产品。

## 放弃的方向

- 路径预检：发现 moonportcheck 的完整同类能力，放弃。
- 表格比较与对账：发现 JingLan0v0/moonrow 以及 GitHub `ago3x/moonledger`，放弃。
- 精确整数份额分配：用户要求更普适的方向，暂停候选，不作为本次交付。

## 实现与许可证

分类规则、名称处理、编号、规划报告、文件入口、示例和测试由本项目独立编写，使用 AI 辅助。
未复制 moonportcheck、fsx、moonrestore、MoonEvidence、circular 或其他邻近项目源码。
自有代码 MIT；仅导入 MoonBit 标准库，不分发工具链源代码。
Node.js 内置 `fs`、`path`、`crypto`、`child_process`、`os` 用于物理文件操作、摘要与测试；
Python 标准库用于独立验证。未嵌入第三方运行时源码或外部 JavaScript/CSS 资产。
分类使用常见扩展名映射；测试文件和报告数据均为自制合成数据，不包含用户真实文件或联系方式。

名称规则参考 Microsoft Windows 文件命名说明：
<https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file>。
文件复制及摘要行为参考 Node.js API：<https://nodejs.org/api/fs.html>、<https://nodejs.org/api/crypto.html>。
仅参考公开行为说明，未复制规范文本或示例源码，也不声称完整实现所有 Windows 规则。

## 2026-10-16 用途级复核

本次作为参赛项目复核了 3,038 条元数据、相关 GitHub 用途查询及 moonportcheck、moonrestore 0.2.0、MoonEvidence 的现行 README。fsx 的 GitHub 读取缺口通过正式发布包 0.3.0 的 README 与 API 表作部分补充，未审计全部实现。fsx 为 Linux native 的底层持久化写入、目录、轮转、锁及小文件读取工具，不能等同于分类整理；也不据此断言不存在任何功能交集。

当前未识别同用途的文件分类整理项目，但完整工作流组合不同不能单独证明通过初审。名称规则、复制、摘要、报告等交集须如实披露；没有真实集成，不声称是上述项目的扩展。此前检索结论仅保留为历史记录，当前证据见 docs/research/review-20261016.json。

参赛者已选择当前版本并要求停止开发。按用户新授权准备首次源码上传，但仍未具备不少于 10 次有效提交等初审提交条件；不将本地测试成功称为资格审核通过。
