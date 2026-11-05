#!/usr/bin/env bash
# 跑 KIT_STEPS=20 并和 golden/summary.20.json 比较（确定性：同 seed 同 aura 必须同结果），
# 再用 `aura evo report` 从进化日志生成 HTML 报告（aura#4910），确认每一步都记录了。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); KIT=${1:-evolve-strategy}
OUT=$(mktemp -d -p "${TMPDIR:-/tmp}")
KIT_STEPS=20 KIT_OUT="$OUT" AURA_EVO_LOG="$OUT/evo.jsonl" "$ROOT/scripts/run-kit.sh" "$KIT"
for f in "$OUT/summary.json" "$OUT/strategy.evolved.aura" "$OUT/evo.jsonl"; do
  [ -s "$f" ] || { echo "缺少输出 $f" >&2; exit 1; }; done
if diff -u "$ROOT/kits/$KIT/golden/summary.20.json" "$OUT/summary.json"; then echo "golden OK"; else echo "golden DIFF" >&2; exit 1; fi
BIN=${AURA_BIN:-$ROOT/.aura-bin/aura}
aura() {
  if [ "${USE_DOCKER:-0}" = 1 ]; then
    ${DOCKER:-docker} run --rm -v "$ROOT:$ROOT" -v "$OUT:$OUT" -w "$ROOT" "${AURA_DEV_IMAGE:-ghcr.io/cybrid-systems/dev:v1.1.1}" "$BIN" "$@"
  else "$BIN" "$@"; fi
}
aura evo report --html "$OUT/report" --run last --log "$OUT/evo.jsonl"
[ -s "$OUT/report/index.html" ] || { echo "缺少 $OUT/report/index.html" >&2; exit 1; }
# 20 步 = 1 条基线 + 每个被评测 / 被契约拦截的候选各 1 条（重复跳过的不记）
n=$(aura evo log --json --run last --log "$OUT/evo.jsonl" | python3 -c 'import json,sys; print(sum(1 for r in json.load(sys.stdin) if r["kind"]=="record"))')
want=$(python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); print(1+s["keeps"]+s["rollbacks"]+s["illegal"])' "$OUT/summary.json")
[ "$n" = "$want" ] || { echo "进化日志记录数 $n != $want" >&2; exit 1; }
echo "evo report OK ($n records) -> $OUT/report/index.html"
