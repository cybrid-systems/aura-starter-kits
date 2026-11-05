# aura-starter-kits

用真实的小项目牵引 [Aura](https://github.com/cybrid-systems/aura) 的开发者体验（DX）。

每个 kit 都是一个**能跑完、能看到结果**的完整程序，按"新用户第一次接触 Aura"的路径搭建，
途中遇到的每一处摩擦都记在下面的[DX 摩擦日志](#dx-摩擦日志)里，并在 aura 仓库提 issue
（总追踪：见日志末尾）。kit 本身也是这些 issue 的验收用例：修好以后，CI 里的非阻塞检查应该变绿。

只使用合成数据，没有任何真实行情或私有数据。

| kit | 内容 | 状态 |
|---|---|---|
| [evolve-strategy](kits/evolve-strategy/) | 程序在 live AST 里改写自己的交易策略参数/规则，训练集 + 留出集门禁决定 KEEP / ROLLBACK，输出 HTML 报告和审计表 | ✅ 默认 Restricted 沙箱 + `aura.toml` 里的 `preset = "dev"` 下可跑（不再需要 `AURA_SANDBOX=off`）；Restricted + force-soa、plain `--load` 仍不一致（见日志 F5） |

## 快速开始

用 aura 的官方产物（aura#4907：自包含 tarball / 运行时镜像，自带 loader 和 glibc，宿主 glibc 无关；Ubuntu 24.04 x86_64 / arm64 已验证），不需要编译：

```bash
git clone https://github.com/cybrid-systems/aura-starter-kits && cd aura-starter-kits

# 1. 取 AURA_PIN 对应的官方产物（从 ghcr.io/cybrid-systems/aura:<pin 前 9 位> 拷出 bundle 到 .aura-bin/，需要 docker）
scripts/fetch-aura.sh
#    或者装 nightly：curl -fsSL https://raw.githubusercontent.com/cybrid-systems/aura/main/install.sh | sh
#    （之后用 AURA_BIN=$(command -v aura)）

# 2. 运行 kit
scripts/run-kit.sh evolve-strategy
#   -> out/evo.jsonl（进化日志）  out/strategy.evolved.aura  out/summary.json
#   报告：.aura-bin/aura evo report --html out/report --run last --log kits/evolve-strategy/out/evo.jsonl

# 已经有 aura 的话：
AURA_BIN=/path/to/aura scripts/run-kit.sh evolve-strategy
KIT_STEPS=20 KIT_SEED=3 scripts/run-kit.sh     # 改步数 / 种子
```

要测没发布产物的 aura 提交：`AURA_REF=<sha> scripts/build-aura.sh`（源码编译，需要 dev 镜像，约 12 分钟）。

其他脚本：

- `scripts/check-golden.sh`：20 步运行结果必须和 `kits/*/golden/summary.20.json` 完全一致（确定性回归）。
- `scripts/mode-matrix.sh`：同一个 kit 在 沙箱{off, 默认+aura.toml preset, soft} × 管线{默认, STRICT=0, force-soa} × {直接运行, `--load`} 下各跑一遍，结果必须一致——这是"单一公开语义"的牵引测试。已知不一致的格子用 `MATRIX_KNOWN_RED` 列出（每格对应一个 aura issue），其余格子必须一致。
- CI（`.github/workflows/ci.yml`）：在干净的 ubuntu-24.04 runner 上用 `scripts/fetch-aura.sh` 取 `AURA_PIN` 的官方产物（不再编译），跑 golden + 60 步报告（上传为 artifact），模式矩阵（阻塞，已知红格见 `ci.yml` 里的 `MATRIX_KNOWN_RED`），每天定时跑一次以发现 aura 行为漂移。

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

**重测（2026-11-05，aura `d5e1fda62` 官方产物，同一台 8 核机器）**：`install.sh`（从 GitHub nightly 下载 + sha256 校验）2.8 s，或 `scripts/fetch-aura.sh` 从运行时镜像取 bundle；kit 60 步 25 s；**合计 < 30 s**（原来 ≈ 14 分钟）。aura 的 dist CI 在干净的 Ubuntu 24.04 x86_64 / arm64 runner 上从安装到 `out/report.html` 也是秒级。

### 摩擦清单

下表是 `21a862bf5` 时记录的原始摩擦。2026-11-05 在 aura `22049db39` 上复查（F4、F12 在 `d77b9c4bf`，即本仓库当前 `AURA_PIN` 上复查），状态见下一节。


| # | 摩擦 | 影响 | issue |
|---|---|---|---|
| F1 | 没有预编译二进制 / 运行镜像；`release.yml` 调用的 `scripts/release.sh` 不存在；二进制要求 GLIBC 2.44 | 首次运行 ≈14 分钟 + 10GB 镜像 | [aura#4907](https://github.com/cybrid-systems/aura/issues/4907) |
| F2 | 默认沙箱（Restricted）下 `set-code` / `mutate:rebind` 被拒，连对自己 `cons` 出来的数据 `set-car!` 也被拒；报错写成 `type error: effect-denied: mutate not granted`，不提示 `aura soft` 或 `AURA_SANDBOX=off` | 第一次运行就失败，不知道怎么办 | [aura#4909](https://github.com/cybrid-systems/aura/issues/4909)、[aura#4912](https://github.com/cybrid-systems/aura/issues/4912) |
| F3 | `aura soft` 下第一次 `mutate:rebind` 列表值就 `persist-reject`（伴随 `[#2341] Densify … panic_residual`），之后所有 rebind 都 `densify-throttle`，`ast:restore` 返回 `#f`，workspace 卡死 | 自进化在官方推荐的实验面跑不通 | [aura#4914](https://github.com/cybrid-systems/aura/issues/4914) |
| F4 | `AURA_PIPELINE_STRICT=force-soa` 下 `mutate:rebind` 每步越来越慢：0.5 s → 3.3 s → 8.3 s → 16 s（其他模式 1–3 ms） | force-soa 下 kit 超时 | [aura#4915](https://github.com/cybrid-systems/aura/issues/4915) |
| F5 | 同一程序在 15 种执行方式下结果不一致：只有 sandbox=off 且非 force-soa 的 4 格一致 | 无法相信"本地跑通 = 生产跑通" | [aura#4908](https://github.com/cybrid-systems/aura/issues/4908) |
| F6 | 被 `require` 的模块里出错时，报错不带文件名，`行:列` 是那个模块的，代码片段却取自主文件（`memq` 未定义被显示成 `main.aura` 第 4 行） | 定位错误靠猜 | [aura#4916](https://github.com/cybrid-systems/aura/issues/4916) |
| F7 | 顶层出错后程序继续往下执行，一个错误引出一串 `unbound variable`；同一个 `(error …)` 在不同行被报 6 次；用户自己的 `(error "…")` 也被印成 `type error:` | 真正的第一个错误淹没在噪声里 | [aura#4909](https://github.com/cybrid-systems/aura/issues/4909) |
| F8 | `write-file` 失败（目录不存在、权限、路径被拒）时只返回 `()`，不报错、退出码 0 | 报告"生成成功"但文件不存在 | [aura#4917](https://github.com/cybrid-systems/aura/issues/4917) |
| F9 | 相对路径 `(require "./x")` 按**当前工作目录**解析，不按文件所在目录；从别的目录运行就 `cannot resolve './x'` | kit 只能 cd 到目录里跑 | [aura#4918](https://github.com/cybrid-systems/aura/issues/4918) |
| F10 | `(require "std/fs")` 在默认沙箱里加载时就要 write 权限，报 `internal error: module-load-failed`；`file-exists?` 原语不 require 就是 unbound，`std/fs` 版本返回 Bool 而原语声明返回 Int | 不敢用标准库 | [aura#4919](https://github.com/cybrid-systems/aura/issues/4919) |
| F11 | CLI 无法授予 MacroSelfEvo / TenantAdmin；只能整体关沙箱 | 安全默认值和可用性二选一 | [aura#4912](https://github.com/cybrid-systems/aura/issues/4912) |
| F12 | 自进化没有现成的可观测性：KEEP/ROLLBACK、原因、门禁证据、HTML 报告全靠自己写（本 kit 的 `report.aura` ~100 行） | 每个项目重复造轮子 | [aura#4910](https://github.com/cybrid-systems/aura/issues/4910) |
| F13 | 没有 REPL 热重载 / worldline 查看；没有 LSP（高亮、跳转、诊断） | 改一行要整程序重跑（含 19 s 容器启动） | [aura#4911](https://github.com/cybrid-systems/aura/issues/4911) |
| F14 | 没有 `aura new <模板>`（`aura new foo` → `cannot open program file 'new'`）；`--help` 不列 `--check/--fmt/--typecheck/--evo-explain/--query`；`aura soft --load` 报 unknown option | 只能翻源码 | [aura#4913](https://github.com/cybrid-systems/aura/issues/4913) |
| F15 | 小坑：`memq` 不存在（`member` 可以）且无提示；`(query :code)` 是未知 op，但有 `query:code` 原语；`sh` 需要 `(require "std/process")`，而它在默认沙箱要 exec 权限 | 卡几分钟 | [aura#4909](https://github.com/cybrid-systems/aura/issues/4909) |

### 复查（aura `22049db39`；F4、F12 在 `d77b9c4bf` 上复查，2026-11-05）

| # | 状态 | 说明 |
|---|---|---|
| F1 | 已修 | 每个 main 提交发布 x86_64/arm64 自包含 tarball（+ sha256，nightly release）和多架构运行镜像 `ghcr.io/cybrid-systems/aura:<sha>` / `:nightly`；`install.sh` 按 `uname -m` 选架构。本仓库 CI 改用官方产物，首次运行 < 30 s（aura#4907） |
| F2 | 已修 | 拒绝现在报 `effect-denied: mutate not granted … op=set-code`，带 `file:line:col` 和 hint（`aura --preset dev main.aura`）；kit 改用 `aura.toml` 的 `preset = "dev"` |
| F3 | 已修 | `aura soft` 下 rebind 正常（aura#4914 已关） |
| F4 | 已修 | force-soa 下每步 `mutate:rebind` 稳定在 2–3 ms（原来 61 ms → 2140 ms 线性增长），闭包不再泄漏（aura#4915 已关） |
| F5 | 部分 | 6 步矩阵 15 格里 12 格一致（原来 4 格）。plain `aura --load` 现在也读 `aura.toml`/`AURA_PRESET`，"naked mutate" 和 `--load` 下的 "invalid closure" 已修（aura#4908 进展）。剩下 Restricted/soft + force-soa 的 3 格：set-code 后 Moving compaction 让 `map`/`apply` 调用的 closure 静默返回 void（[aura#4928](https://github.com/cybrid-systems/aura/issues/4928)） |
| F6 | 已修 | aura#4916 已关 |
| F7 | 大部分 | 首个错误即停（`--keep-going` 可继续）、分类准确、每条拒绝带 hint；过程体内的错误位置仍指向调用点（aura#4909） |
| F8 | 已修 | aura#4917 已关 |
| F9 | 已修 | aura#4918 已关 |
| F10 | 已修 | aura#4919 已关 |
| F11 | 部分 | 有了 `--preset dev\|ci\|prod`、`--grant`/`--deny`、`AURA_PRESET`、`aura.toml`，`--load` 也生效（aura#4912 未关） |
| F12 | 已修 | `evo:record!` 记录每个候选的决定、原因、门禁证据；`aura evo log` / `aura evo report --html` 直接出 KEEP/ROLLBACK 列表和 HTML 报告，本 kit 的 `report.aura` 已删除（aura#4910） |
| F13 | 未修 | aura#4911 |
| F14 | 大部分 | `aura new app\|evolve\|agent`、`aura run`、`aura test` 可用；`--help` 列出 `--check/--fmt/--typecheck/--evo-explain/--query`；`aura soft --load` 可用 |
| F15 | 部分 | `memq` 现在提示 `did you mean 'member'?` |

总追踪 issue：[aura#4906](https://github.com/cybrid-systems/aura/issues/4906)

## 约定

- `AURA_PIN` 记录验证过的 aura 提交（要有官方产物，即 aura 的 dist 跑完的 main 提交）；升级 aura 时改它，CI 会取新产物并跑全部 kit。
- 新 kit 放在 `kits/<名字>/`，入口 `main.aura`，能力需求写在同目录 `aura.toml`（`preset = "dev"` 等），其他环境变量写在 `aura.env`，确定性结果放 `golden/summary.20.json`。
