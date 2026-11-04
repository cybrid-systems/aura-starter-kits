# aura-starter-kits

用真实的小项目牵引 [Aura](https://github.com/cybrid-systems/aura) 的开发者体验（DX）。

每个 kit 都是一个**能跑完、能看到结果**的完整程序，按"新用户第一次接触 Aura"的路径搭建，
途中遇到的每一处摩擦都记在下面的[DX 摩擦日志](#dx-摩擦日志)里，并在 aura 仓库提 issue
（总追踪：见日志末尾）。kit 本身也是这些 issue 的验收用例：修好以后，CI 里的非阻塞检查应该变绿。

只使用合成数据，没有任何真实行情或私有数据。

| kit | 内容 | 状态 |
|---|---|---|
| [evolve-strategy](kits/evolve-strategy/) | 程序在 live AST 里改写自己的交易策略参数/规则，训练集 + 留出集门禁决定 KEEP / ROLLBACK，输出 HTML 报告和审计表 | ✅ `AURA_SANDBOX=off` 下可跑；默认沙箱 / `aura soft` / force-soa 下跑不通（见日志） |

## 快速开始

Aura 目前**没有官方二进制或镜像**，只能从源码编译（需要 C++26 工具链，用公开的 dev 镜像）：

```bash
git clone https://github.com/cybrid-systems/aura-starter-kits && cd aura-starter-kits

# 1. 编译 aura（固定在 AURA_PIN 记录的提交）。约 12 分钟（8 核，-j3），另需拉取 ~10GB 的 dev 镜像
scripts/build-aura.sh                      # 需要 docker；产物在 .aura-bin/

# 2. 运行 kit（aura 需要 GLIBC 2.44，大多数宿主机跑不了，所以默认在 dev 镜像里跑）
USE_DOCKER=1 scripts/run-kit.sh evolve-strategy
#   -> out/report.html  out/audit.tsv  out/strategy.evolved.aura  out/summary.json

# 已经有 aura 的话：
AURA_BIN=/path/to/aura scripts/run-kit.sh evolve-strategy
KIT_STEPS=20 KIT_SEED=3 scripts/run-kit.sh     # 改步数 / 种子
```

其他脚本：

- `scripts/check-golden.sh`：20 步运行结果必须和 `kits/*/golden/summary.20.json` 完全一致（确定性回归）。
- `scripts/mode-matrix.sh`：同一个 kit 在 沙箱{off, 默认, soft} × 管线{默认, STRICT=0, force-soa} × {直接运行, `--load`} 下各跑一遍，结果必须一致——这是"单一公开语义"的牵引测试，目前大部分格子是红的。
- CI（`.github/workflows/ci.yml`）：在 dev 镜像里按 `AURA_PIN` 编译 aura（按提交缓存），跑 golden + 60 步报告（上传为 artifact），模式矩阵作为非阻塞步骤，每天定时跑一次以发现 aura 行为漂移。

## DX 摩擦日志

环境：aura main `21a862bf5`（2026-11-04），dev 镜像 `ghcr.io/cybrid-systems/dev:v1.1.1`，8 核 / 16GB。

### 首次运行耗时（time-to-first-run）

| 步骤 | 耗时 |
|---|---|
| 拉取 dev 镜像（~10GB，本机已缓存，未计入） | — |
| clone aura + 冷编译 `aura` 目标（-j3，356 个编译单元） | **738 s** |
| 组装 `.aura-bin`（cmake 重新配置 + 拷贝） | 58 s |
| 第一次 `run-kit.sh`（20 步，含 ~19 s 容器启动） | 33 s |
| **合计** | **≈ 14 分钟**（不含镜像拉取） |
| 对比：kit 本身 60 步的运行时间 | 20 s（aura 启动 50 ms） |

理想状态：`curl … | sh` 或 `docker run ghcr.io/cybrid-systems/aura` 一行，< 1 分钟跑出第一个报告。

### 摩擦清单

| # | 摩擦 | 影响 | issue |
|---|---|---|---|
| F1 | 没有预编译二进制 / 运行镜像；`release.yml` 调用的 `scripts/release.sh` 不存在；二进制要求 GLIBC 2.44 | 首次运行 ≈14 分钟 + 10GB 镜像 | ISSUE_INSTALL |
| F2 | 默认沙箱（Restricted）下 `set-code` / `mutate:rebind` 被拒，连对自己 `cons` 出来的数据 `set-car!` 也被拒；报错写成 `type error: effect-denied: mutate not granted`，不提示 `aura soft` 或 `AURA_SANDBOX=off` | 第一次运行就失败，不知道怎么办 | ISSUE_ERRORS |
| F3 | `aura soft` 下第一次 `mutate:rebind` 列表值就 `persist-reject`（伴随 `[#2341] Densify … panic_residual`），之后所有 rebind 都 `densify-throttle`，`ast:restore` 返回 `#f`，workspace 卡死 | 自进化在官方推荐的实验面跑不通 | ISSUE_SOFT |
| F4 | `AURA_PIPELINE_STRICT=force-soa` 下 `mutate:rebind` 每步越来越慢：0.5 s → 3.3 s → 8.3 s → 16 s（其他模式 1–3 ms） | force-soa 下 kit 超时 | ISSUE_FORCESOA |
| F5 | 同一程序在 9 种执行方式下结果不一致：只有 sandbox=off 且非 force-soa 的 4 格一致 | 无法相信"本地跑通 = 生产跑通" | ISSUE_SEMANTICS |
| F6 | 被 `require` 的模块里出错时，报错不带文件名，`行:列` 是那个模块的，代码片段却取自主文件（`memq` 未定义被显示成 `main.aura` 第 4 行） | 定位错误靠猜 | ISSUE_LOC |
| F7 | 顶层出错后程序继续往下执行，一个错误引出一串 `unbound variable`；同一个 `(error …)` 在不同行被报 6 次；用户自己的 `(error "…")` 也被印成 `type error:` | 真正的第一个错误淹没在噪声里 | ISSUE_ERRORS |
| F8 | `write-file` 失败（目录不存在、权限、路径被拒）时只返回 `()`，不报错、退出码 0 | 报告"生成成功"但文件不存在 | ISSUE_WRITEFILE |
| F9 | 相对路径 `(require "./x")` 按**当前工作目录**解析，不按文件所在目录；从别的目录运行就 `cannot resolve './x'` | kit 只能 cd 到目录里跑 | ISSUE_REQUIRE |
| F10 | `(require "std/fs")` 在默认沙箱里加载时就要 write 权限，报 `internal error: module-load-failed`；`file-exists?` 原语不 require 就是 unbound，`std/fs` 版本返回 Bool 而原语声明返回 Int | 不敢用标准库 | ISSUE_STDFS |
| F11 | CLI 无法授予 MacroSelfEvo / TenantAdmin；只能整体关沙箱 | 安全默认值和可用性二选一 | ISSUE_PRESETS |
| F12 | 自进化没有现成的可观测性：KEEP/ROLLBACK、原因、门禁证据、HTML 报告全靠自己写（本 kit 的 `report.aura` ~100 行） | 每个项目重复造轮子 | ISSUE_OBS |
| F13 | 没有 REPL 热重载 / worldline 查看；没有 LSP（高亮、跳转、诊断） | 改一行要整程序重跑（含 19 s 容器启动） | ISSUE_REPL |
| F14 | 没有 `aura new <模板>`（`aura new foo` → `cannot open program file 'new'`）；`--help` 不列 `--check/--fmt/--typecheck/--evo-explain/--query`；`aura soft --load` 报 unknown option | 只能翻源码 | ISSUE_NEW |
| F15 | 小坑：`memq` 不存在（`member` 可以）且无提示；`(query :code)` 是未知 op，但有 `query:code` 原语；`sh` 需要 `(require "std/process")`，而它在默认沙箱要 exec 权限 | 卡几分钟 | ISSUE_ERRORS |

总追踪 issue：ISSUE_TRACK

## 约定

- `AURA_PIN` 记录验证过的 aura 提交；升级 aura 时改它，CI 会重新编译并跑全部 kit。
- 新 kit 放在 `kits/<名字>/`，入口 `main.aura`，能力需求写在 `aura.env`，确定性结果放 `golden/summary.20.json`。
