#!/usr/bin/env bash
# 跑 KIT_STEPS=20 并和 golden/summary.20.json 比较（确定性：同 seed 同 aura 必须同结果）。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); KIT=${1:-evolve-strategy}
OUT=$(mktemp -d -p "${TMPDIR:-/tmp}")
KIT_STEPS=20 KIT_OUT="$OUT" "$ROOT/scripts/run-kit.sh" "$KIT"
for f in "$OUT/summary.json" "$OUT/report.html" "$OUT/audit.tsv" "$OUT/strategy.evolved.aura"; do
  [ -s "$f" ] || { echo "缺少输出 $f" >&2; exit 1; }; done
if diff -u "$ROOT/kits/$KIT/golden/summary.20.json" "$OUT/summary.json"; then echo "golden OK"; else echo "golden DIFF" >&2; exit 1; fi
