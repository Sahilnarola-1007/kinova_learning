#!/usr/bin/env bash
# Reconstruct the kinova_learning workspace on a fresh machine.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS"
echo "Workspace: $WS"

command -v vcs     >/dev/null || { echo "ERROR: install python3-vcstool"; exit 1; }
command -v colcon  >/dev/null || { echo "ERROR: colcon not found — source /opt/ros/jazzy/setup.bash"; exit 1; }

echo "--- [1/6] importing repositories"
vcs import . < kinova_learning.repos

# =============================================================================
# TWO VENVS, NOT ONE.
#
# mae-sdk and mae-fts-sdk both pin  numpy>=1.26.4,<2.0.0
# scipy 1.18.0 requires             numpy>=2.0.0,<2.8.0
# opencv-python 5.0.0.93 requires   numpy>=2
#
# Those ranges have empty intersection. A constraints file cannot fix this —
# it pins a version, it cannot reconcile disjoint ranges. Installing MAE into
# the perception venv silently downgrades numpy to 1.26.4 and leaves scipy,
# opencv, torch and open3d running outside their tested ABI range.
#
#   venv     — perception stack: numpy 2.x, torch, opencv, scipy, FoundationPose
#   venv_ft  — F/T sensor only:  numpy 1.x, mae-sdk, mae-fts-sdk
#
# COLCON_IGNORE in both: colcon's python_setup_py identifier otherwise descends
# into site-packages and tries to run setup.py on numpy's Cython test fixtures
# and wandb's vendored gql/graphql/promise. Harmless, but ~40 lines of traceback
# on every single build.
# =============================================================================

echo "--- [2/6] perception venv (numpy 2.x)"
[ -d venv ] || python3 -m venv venv
touch venv/COLCON_IGNORE
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt
if command -v nvidia-smi >/dev/null 2>&1; then
  ./venv/bin/pip install -r requirements-gpu.txt
else
  echo "    no nvidia-smi — skipping requirements-gpu.txt"
fi
echo "    dependency check:"
./venv/bin/pip check || echo "    ^^ WARNING: conflicts above — do not ignore"

echo "--- [3/6] MAE SDK -> user site-packages (~/.local)"
# Installed for SYSTEM python, not a venv: mae_sensor_node is an rclpy node and
# `ros2 run` invokes /usr/bin/python3, which searches ~/.local automatically.
# --break-system-packages is required (PEP 668 marks system python managed).
#
# This works because Ubuntu 24.04's apt numpy is 1.26.4, which satisfies
# mae-sdk's numpy>=1.26.4,<2.0.0. The perception venv stays isolated at
# numpy 2.x for torch/opencv/scipy. If a future apt upgrade pushes system
# numpy past 2.0, this breaks and MAE moves to its own venv.
MAE="$HOME/SensuReal SDKs"
if [ -d "$MAE/mae-sdk" ] && [ -d "$MAE/mae-fts-sdk" ]; then
  /usr/bin/python3 -m pip install --user --break-system-packages \
    "$MAE/mae-sdk" "$MAE/mae-fts-sdk"
  /usr/bin/python3 -c "import numpy, mae_sdk, mae_fts_sdk; \
    print('    system numpy:', numpy.__version__); \
    assert numpy.__version__ < '2', 'system numpy >= 2.0 — MAE needs < 2.0'"
else
  echo "    MISSING: '$MAE'"
  echo "    Copy it from the other machine. F/T sensor will not work without it."
fi

echo "--- [4/6] Kortex C++ SDK binary"
KAPI="$WS/kortex/api_cpp/examples/kortex_api"
HAVE_KORTEX=0
if [ -f "$KAPI/lib/release/libKortexApiCpp.a" ]; then
  echo "    found"
  HAVE_KORTEX=1
else
  echo "    MISSING: $KAPI/lib/release/libKortexApiCpp.a"
  echo "    Download the Kortex C++ API package from Kinova and extract it there."
  echo "    Mock builds will still work; -DUSE_KORTEX_MOCK=OFF will not."
fi

cd ros2_ws

echo "--- [5/6] build: mock SDK  ->  build/ install/"
colcon build --cmake-args -DUSE_KORTEX_MOCK=ON

# Hardware build goes in its own tree. Sharing one install space means the last
# build wins and the default workspace silently ends up holding a binary that
# needs the arm. Compile-and-link only — no robot required for this step.
echo "--- [6/6] build: real SDK  ->  build_hw/ install_hw/"
if [ "$HAVE_KORTEX" -eq 1 ]; then
  colcon build --packages-up-to kinova_wrapper \
    --cmake-args -DUSE_KORTEX_MOCK=OFF \
    --build-base build_hw --install-base install_hw
else
  echo "    skipped — no libKortexApiCpp.a"
fi

cat <<'DONE'

Done.

  mock (default):  source ~/kinova_learning/ros2_ws/install/setup.bash
  real hardware:   source ~/kinova_learning/ros2_ws/install_hw/setup.bash
  F/T sensor:      ~/kinova_learning/venv_ft/bin/python
  perception:      ~/kinova_learning/venv/bin/python

Rebuild by hand (always from ros2_ws, never from the parent dir):
  colcon build --cmake-args -DUSE_KORTEX_MOCK=ON
  colcon build --packages-up-to kinova_wrapper --cmake-args -DUSE_KORTEX_MOCK=OFF \
    --build-base build_hw --install-base install_hw
DONE
