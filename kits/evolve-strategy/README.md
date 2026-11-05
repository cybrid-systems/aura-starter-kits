# evolve-strategy：让程序自己改自己的交易策略

一个最小但完整的"自进化"闭环，全部用 Aura 写成，只用合成数据：

1. `strategy.aura` 是**被进化的程序**：`strategy-params`（均线周期、趋势过滤、波动上限……）和 `strategy-rules`（启用哪些规则）。
2. `main.aura` 用 `set-code` 把它装进 live AST。
3. 每一步 `evolve.aura`：
   - `ast:snapshot` → 提议一个变更（改一个参数 / 同时改两个 / 开关一条规则）→ `mutate:rebind` 改写 live AST 里的定义 → 读回 live AST 确认生效；
   - 在**训练**行情上回测（`backtest.aura`），同时在**留出**行情上回测；
   - `gate.aura` 裁决：训练 Sharpe 至少涨 0.02、回撤 ≤ 25%、交易 ≥ 10 次、留出 Sharpe 不能掉超过 0.10 → **KEEP**；否则 `ast:restore` **ROLLBACK**；
   - 契约（`fast < slow`、必须保留 `ma-cross`）不满足的提议直接拦截，不进 AST。
4. 进化过程写进 aura 的进化日志（aura#4910）：`evolve.aura` 对每个候选调用 `evo:record!`，记下变更描述、KEEP/ROLLBACK、原因（哪条门禁没过）、门禁证据（训练/留出 Sharpe、回撤、交易次数）、候选源码和耗时；`mutate:rebind` / `ast:restore` 也由 aura 自动记录。日志位置由 `aura.env` 里的 `AURA_EVO_LOG` 决定（默认 `out/evo.jsonl`）。
   - `aura evo log --run last --log out/evo.jsonl`：在终端列出每个候选；
   - `aura evo report --html out/report --run last --log out/evo.jsonl`：静态 HTML（时间线、分数曲线、每个候选相对上一个 KEEP 的源码 diff，不联网）。
5. `outputs.aura` 输出到 `out/`：
   - `strategy.evolved.aura`：进化后的程序，可以直接替换 `strategy.aura` 再跑一轮；
   - `summary.json`：CI 用来比对的确定性摘要。

行情由 `market.aura` 里的 LCG 随机数生成（4 种行情状态轮换），同 seed 同结果。

## 运行

```bash
scripts/run-kit.sh evolve-strategy                 # 默认 60 步
KIT_STEPS=20 KIT_SEED=3 scripts/run-kit.sh         # 改步数 / 提议种子
KIT_OUT=/tmp/r scripts/run-kit.sh                  # 改输出目录
```

需要的能力面写在 `aura.toml`（`preset = "dev"`）；额外环境变量（`AURA_EVO_LOG`）在 `aura.env`。

## 参考结果（aura 21a862bf5，seed 1，60 步）

```
evolve-strategy: 60 步，KEEP 3，ROLLBACK 49，契约拦截 6，重复 2
训练 Sharpe 0.817 → 1.275，留出 Sharpe 0.647 → 0.748，训练最大回撤 0.188
进化后：((fast . 3) (slow . 5) (trend . 100) (vol-cap . 0.4) (vol-win . 40)) (ma-cross vol-filter)
```

每步 `mutate:rebind` ×2 + `eval-current` 约 2–3 ms，两次回测约 350 ms；60 步总共约 20 s。

## 改着玩

- `gate.aura` 的 `*gate*`：门槛调严/调松，看 KEEP/ROLLBACK 怎么变。
- `evolve.aura` 的 `*grid*` / `*optional-rules*`：扩大搜索空间。
- `backtest.aura` 的 `position-at`：加一条新规则（比如 `mean-revert`），再把它加进 `*optional-rules*`。
