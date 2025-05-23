#!/usr/bin/env bash
set -euo pipefail

# 1. Checkout 子模块、打补丁、bootstrap（和 CI 一致）
(
  cd connectedhomeip
  scripts/checkout_submodules.py --shallow --platform linux
  for p in ../*.patch; do
    [ -e "$p" ] || break
    patch -p1 < "$p"
  done
  bash scripts/bootstrap.sh -p all,linux
)

# 2. 用官方的 multi-arch 容器，在 ARMv7 平台模拟下跑 GN build
docker run --rm \
  --platform linux/arm/v7 \
  -v "$(pwd)/connectedhomeip":/work/connectedhomeip \
  -w /work/connectedhomeip \
  ghcr.io/home-assistant-libs/chip-wheels/chip-wheels-builder:release \
  bash -lc "\
    mkdir -p out && \
    ./scripts/examples/gn_build_example.sh \
      examples/ota-provider-app/linux/ \
      out/ \
      chip_project_config_include_dirs=[\"//../../../..\"] \
      chip_crypto=\"boringssl\" \
      chip_config_network_layer_ble=false \
      chip_enable_wifi=false \
      chip_enable_openthread=false \
      chip_exchange_node_id_logging=true \
      chip_mdns=\"minimal\" \
      chip_minmdns_default_policy=\"libnl\" \
      chip_use_data_model_interface=\"enabled\" && \
    cp out/chip-ota-provider-app /work/connectedhomeip/bin/chip-ota-provider-app-armv7
"

# 3. 拿到产物
echo ">>> 构建完成，产物在 connectedhomeip/bin/chip-ota-provider-app-armv7"
