#!/usr/bin/env bash
# 运行一个 kit：scripts/run-kit.sh [kit] [额外 aura 参数...]
#   AURA_BIN   aura 可执行文件（默认 .aura-bin/aura）
#   KIT_STEPS  进化步数（默认 60）  KIT_SEED  随机种子（默认 1）  KIT_OUT  输出目录（默认 out）
# 官方产物（scripts/fetch-aura.sh / install.sh，aura#4907）自带 glibc，宿主机直接跑。
# 源码构建（scripts/build-aura.sh）的二进制依赖 GLIBC 2.44，这时设置 USE_DOCKER=1 在 dev 镜像里运行。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
KIT=${1:-evolve-strategy}; shift || true
BIN=${AURA_BIN:-$ROOT/.aura-bin/aura}
[ -x "$BIN" ] || { echo "找不到 aura：$BIN（先跑 scripts/build-aura.sh 或设置 AURA_BIN）" >&2; exit 2; }
cd "$ROOT/kits/$KIT"
set -a; [ -f aura.env ] && . ./aura.env; set +a
mkdir -p "${KIT_OUT:-out}"   # 沙箱里的 kit 不调 shell；write-file 不会建目录
if [ "${USE_DOCKER:-0}" = 1 ]; then
  exec ${DOCKER:-docker} run --rm -v "$ROOT:$ROOT" -w "$PWD" \
    -e "AURA_SANDBOX=${AURA_SANDBOX:-}" -e "AURA_PRESET=${AURA_PRESET:-}" -e "KIT_STEPS=${KIT_STEPS:-60}" -e "KIT_SEED=${KIT_SEED:-1}" -e "KIT_OUT=${KIT_OUT:-out}" -e "AURA_EVO_LOG=${AURA_EVO_LOG:-}" \
    "${AURA_DEV_IMAGE:-ghcr.io/cybrid-systems/dev:v1.1.1}" "$BIN" "$@" main.aura
fi
exec "$BIN" "$@" main.aura
