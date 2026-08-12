# kinova_learning

Workspace manifest for force-conditioned contact skills on a Kinova Gen3 7-DOF arm.
This repo contains no source — it reconstructs the workspace from component repos.

## Setup

    sudo apt install python3-vcstool
    source /opt/ros/jazzy/setup.bash
    git clone git@github.com:Sahilnarola-1007/kinova_learning.git ~/kinova_learning
    cd ~/kinova_learning && ./tools/bootstrap.sh

## Manual steps bootstrap cannot do

**MAE SensuReal SDK** — proprietary, not redistributable. Copy
`~/SensuReal SDKs/` from an existing machine to the same path. Editable installs
are path-bound, so the location must match.

**Kortex C++ API binary** — `libKortexApiCpp.a` is not in the Kinova git repo.
Download the Kortex C++ API package and extract to
`kortex/api_cpp/examples/kortex_api/`. Only needed for real-hardware builds.

**Network** — arm and F/T sensor sit on 192.168.1.x. NIC names differ per machine;
run `ip link show` and write your own netplan config. Do not copy one between
machines.

## Build

    cd ros2_ws && colcon build                    # mock SDK (default) — no arm needed
    colcon build --packages-select kinova_wrapper \
      --cmake-args -DUSE_KORTEX_MOCK=OFF          # real hardware

## Layout

    kinova_lowlevel/            1 kHz cyclic control loop (standalone CMake)
    kortex/                     Kinova SDK, pinned @ 5bf21ef
    ros2_ws/src/
      kinova_kinematics/        FK, Jacobian, DLS IK (Classical DH)
      kinova_wrapper/           Kortex API wrapper, RAII, mock build mode
      admittance_controller/    admittance reflex + force PI
      mae_sensor_driver/        MAE 6-axis F/T driver
      surface_wipe/             contact-motion demo
      kinova_perception/        pose estimation (scaffold)
      kinova_moveit_bridge/     MoveIt 2 bridge
      wipe_msgs/                message definitions
      ros2_kortex_vision/       Kinova upstream (vendored)
