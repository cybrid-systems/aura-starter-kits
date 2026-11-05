#!/usr/bin/env bash
# 取官方产物（aura#4907）：从运行时镜像 ghcr.io/cybrid-systems/aura:<AURA_PIN 前 9 位> 里
# 拷出自包含 bundle（自带 loader/glibc/libstdc++，宿主 glibc 无关），放到 .aura-bin/。
#   scripts/fetch-aura.sh            -> .aura-bin/aura（指向 bundle 的 bin/aura 启动脚本）
# 镜像不存在（比如 pin 到了还没跑完 dist 的提交）时退回 scripts/build-aura.sh 源码构建。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
PIN=${AURA_REF:-$(cat AURA_PIN)}
IMG=${AURA_IMAGE:-ghcr.io/cybrid-systems/aura:${PIN:0:9}}
D=${DOCKER:-docker}
if ! $D pull -q "$IMG" >/dev/null 2>&1; then
  echo "fetch-aura: $IMG 不存在，改为源码构建" >&2
  exec scripts/build-aura.sh
fi
id=$($D create "$IMG")
trap '$D rm "$id" >/dev/null' EXIT
rm -rf .aura-bin && mkdir -p .aura-bin
$D cp "$id:/opt/." .aura-bin/
b=$(ls -d .aura-bin/aura-*/ | head -1)
ln -s "${b#.aura-bin/}bin/aura" .aura-bin/aura
commit=$(sed -n 's/^commit //p' "$b/BUILD-INFO")
case "$commit" in "${PIN:0:9}"*) ;; *) echo "fetch-aura: 镜像 commit $commit 与 AURA_PIN $PIN 不一致" >&2; exit 1;; esac
echo "$commit" > .aura-bin/AURA_COMMIT
echo "fetched: $ROOT/.aura-bin/aura (aura @ ${commit:0:9}, $IMG)"
