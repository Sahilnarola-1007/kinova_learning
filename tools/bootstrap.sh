#!/usr/bin/env bash
# Reconstruct the kinova_learning workspace on a fresh machine.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS"
echo "Workspace: $WS"

command -v vcs     >/dev/null || { echo "ERROR: install python3-vcstool"; exit 1; }
command -v colcon  >/dev/null || { echo "ERROR: colcon not found — source /opt/ros/jazzy/setup.bash"; exit 1; }

echo "--- [1/5] importing repositories"
vcs import . < kinova_learning.repos

echo "--- [2/5] python venv"
[ -d venv ] || python3 -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt
if command -v nvidia-smi >/dev/null 2>&1; then
  ./venv/bin/pip install -r requirements-gpu.txt
else
  echo "    no nvidia-smi — skipping requirements-gpu.txt"
fi

echo "--- [3/5] MAE SDK (proprietary, manual copy)"
MAE="$HOME/SensuReal SDKs"
if [ -d "$MAE/mae-sdk" ] && [ -d "$MAE/mae-fts-sdk" ]; then
  ./venv/bin/pip install -e "$MAE/mae-sdk"
  ./venv/bin/pip install -e "$MAE/mae-fts-sdk"
else
  echo "    MISSING: '$MAE'"
  echo "    Copy it from the other machine. F/T sensor will not work without it."
fi

echo "--- [4/5] Kortex C++ SDK binary"
KAPI="$WS/kortex/api_cpp/examples/kortex_api"
if [ -f "$KAPI/lib/release/libKortexApiCpp.a" ]; then
  echo "    found"
else
  echo "    MISSING: $KAPI/lib/release/libKortexApiCpp.a"
  echo "    Download the Kortex C++ API package from Kinova and extract it there."
  echo "    Mock builds will still work; -DUSE_KORTEX_MOCK=OFF will not."
fi

echo "--- [5/5] build (mock SDK)"
cd ros2_ws
colcon build

cat <<'DONE'

Done. Next:
  source ~/kinova_learning/ros2_ws/install/setup.bash
Real hardware:
  colcon build --packages-select kinova_wrapper --cmake-args -DUSE_KORTEX_MOCK=OFF
DONE
