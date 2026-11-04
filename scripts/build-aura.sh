#!/usr/bin/env bash
# 从源码构建 aura（目前没有官方二进制/镜像，只能这么做）。
#   scripts/build-aura.sh            -> 输出 .aura-bin/aura（+ 运行时 .so + 标准库 lib/）
# 需要 docker（使用公开 dev 镜像 ghcr.io/cybrid-systems/dev:v1.1.1，内含 GCC/C++26 工具链）。
# 已在容器里（如 CI）时设置 IN_CONTAINER=1 直接构建。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
PIN=${AURA_REF:-$(cat AURA_PIN)}
IMG=${AURA_DEV_IMAGE:-ghcr.io/cybrid-systems/dev:v1.1.1}
J=${J:-2}   # aura 的模块化 C++ 构建很吃内存，16GB 机器上 -j2 比较安全
if [ ! -d .aura-src/.git ]; then git clone --filter=blob:none https://github.com/cybrid-systems/aura.git .aura-src; fi
git -C .aura-src fetch -q origin && git -C .aura-src checkout -q "$PIN"
build='cmake -S .aura-src -B .aura-build -G Ninja -Wno-author -DCMAKE_BUILD_TYPE=Release >/dev/null && ninja -C .aura-build -j'"$J"' aura'
if [ "${IN_CONTAINER:-0}" = 1 ]; then bash -c "$build"
else ${DOCKER:-docker} run --rm -v "$ROOT:$ROOT" -w "$ROOT" "$IMG" bash -c "$build"; fi
# 组装一个可搬运的目录：aura 运行时按可执行文件旁边的 lib/ 找标准库
rm -rf .aura-bin && mkdir -p .aura-bin
cp .aura-build/aura .aura-build/*.so .aura-bin/ && cp -r .aura-src/lib .aura-bin/lib
git -C .aura-src rev-parse HEAD > .aura-bin/AURA_COMMIT
echo "built: $ROOT/.aura-bin/aura (aura @ $(cut -c1-9 .aura-bin/AURA_COMMIT))"
