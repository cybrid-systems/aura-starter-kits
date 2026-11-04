#!/usr/bin/env bash
# 用同一个 kit 跑 Aura 的各种执行方式，比较结果是否一致（"单一公开语义"的牵引测试）。
#   AURA_BIN=/path/to/aura scripts/mode-matrix.sh [kit]   默认 kit=evolve-strategy，KIT_STEPS 默认 20
# 输出每种方式的退出码、耗时和 summary.json 摘要；和基准（sandbox=off / 默认管线 / 直接运行）不一致的标 DIFF。
# sandbox=unset 表示不设 AURA_SANDBOX：默认 Restricted 沙箱 + kit 目录里 aura.toml 的 preset。
# MATRIX_KNOWN_RED：已知不一致的格子（正则，匹配 "沙箱-管线-方式"，如 unset-force-soa-direct），
#   标 KNOWN、不计入失败；每一格都要对应一个 aura issue。已知红格变绿时标 FIXED，提醒从列表里删掉。
set -u
KIT=${1:-evolve-strategy}
: "${AURA_BIN:?set AURA_BIN to an aura binary}"
cd "$(dirname "$0")/../kits/$KIT"
export KIT_STEPS=${KIT_STEPS:-20}
OUT=${MATRIX_OUT:-$(mktemp -d)}; base=""; diffs=0; KNOWN=${MATRIX_KNOWN_RED:-}
for sb in off unset soft; do for st in def 0 force-soa; do for md in direct load; do
  [ $sb = soft ] && [ $md = load ] && continue      # aura soft 不支持 --load
  e=(env -u AURA_SANDBOX -u AURA_PIPELINE_STRICT KIT_OUT="$OUT/$sb-$st-$md")
  [ $sb = off ] && e+=(AURA_SANDBOX=off); [ $st != def ] && e+=(AURA_PIPELINE_STRICT=$st)
  args=(); [ $sb = soft ] && args+=(soft); [ $md = load ] && args+=(--load)
  mkdir -p "$OUT/$sb-$st-$md"
  t0=$(date +%s%N); "${e[@]}" timeout -s KILL ${KIT_TIMEOUT:-300} "$AURA_BIN" "${args[@]}" main.aura > "$OUT/$sb-$st-$md.log" 2>&1; rc=$?; t1=$(date +%s%N)
  s=$(cat "$OUT/$sb-$st-$md/summary.json" 2>/dev/null | tr -d '\n' | cut -c1-160)
  [ -z "$base" ] && base="$s"
  key="$sb-$st-$md"; known=0; [ -n "$KNOWN" ] && [[ $key =~ ^($KNOWN)$ ]] && known=1
  if [ "$s" != "$base" ]; then
    if [ $known = 1 ]; then mark=KNOWN; else mark=DIFF; diffs=$((diffs+1)); fi
  else
    mark=OK; [ $known = 1 ] && mark=FIXED
  fi
  printf '%-5s %-6s sandbox=%-5s strict=%-9s %-6s rc=%-3s %6sms  %s\n' "$mark" "" "$sb" "$st" "$md" "$rc" $(( (t1-t0)/1000000 )) "${s:-<no summary> $(grep -m1 -E 'error|失败' "$OUT/$sb-$st-$md.log" | cut -c1-140)}"
done; done; done
echo "logs: $OUT"; echo "diffs=$diffs"
[ $diffs -eq 0 ]
