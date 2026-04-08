# Building commissioning containers

This repository contains the **Dockerfiles and build scripts** for all publicly available b-controlled Box commissioning container images.

> **This repository only builds images.** To _run_ a commissioning container, use the [b_ctrldbox_commissioning](https://github.com/b-robotized/b_ctrldbox_commissioning) repository.

---

## Table of Contents

1. [Who This Is For](#1-who-this-is-for)
2. [Repository Structure](#2-repository-structure)
3. [Architecture Overview](#3-architecture-overview)
4. [Prerequisites](#4-prerequisites)
5. [Building a Robot Image](#5-building-a-robot-image)
6. [Rebuilding the Base Image (Advanced)](#6-rebuilding-the-base-image-advanced)
7. [Using Your Custom Image](#7-using-your-custom-image)
8. [Reference](#8-reference)

---

## 1. Who This Is For

Clients who want to modify the commissioning container (add packages, change configurations, integrate custom ROS 2 nodes) and build it locally.

If you just want to **run** a pre-built container without modifications, *you do not need this repository*. Use [b_ctrldbox_commissioning](https://github.com/b-robotized/b_ctrldbox_commissioning) directly.

---

## 2. Repository Structure

```
b_controlled_box_commissioning_containers/
  common/                       # Base image layer
    rtw-tools.jazzy.Dockerfile  #   - ROS 2 Jazzy + ROS Team Workspace
    build.sh                    #   - Build script for the base image
    entrypoint.sh               #   - Container entrypoint
    clone_robot_dir.sh          #   - Script for cloning robot workspace files
  ur/                           # UR robot image
    comissioning.Dockerfile
    ur.jazzy.repos
  kuka/                         # KUKA robot image
    comissioning.Dockerfile
    kuka.jazzy.repos
  kassow/                       # Kassow robot image
    comissioning.Dockerfile
    kassow.jazzy.repos
  pssbl/                        # Pssbl robot image
    comissioning.Dockerfile
    pssbl.jazzy.repos
  dobot/                        # Dobot robot image
    comissioning.Dockerfile
    dobot.jazzy.repos
  fanuc/                        # Fanuc robot image
    comissioning.Dockerfile
    fanuc.jazzy.repos
  build-robot-image.sh          # Build script
```

---

## 3. Architecture Overview

All commissioning images follow a two-layer structure:

```
  Layer 1 (Base):    rtw-tools:jazzy
                     - osrf/ros:jazzy-desktop
                     - ROS Team Workspace (RTW)
                     - chrony NTP server
                     - Generic 'b-robotized' user

  Layer 2 (Robot):   <robot>-commission:<tag>
                     - Robot-specific ROS 2 packages (via vcs import)
                     - Robot workspace files from b_ctrldbox_commissioning
                     - rosdep dependencies
                     - Pre-built colcon workspace
```

The base image (`rtw-tools:jazzy`) is a **pre-built foundation** hosted on the public registry. When you build a robot image, Docker pulls the base image automatically in the Dockerfile (`FROM` directive). You do not need to build the base image yourself unless you have a specific reason to modify it (see [Section 6](#6-rebuilding-the-base-image-advanced)).

---

## 4. Prerequisites

- **Docker** with BuildKit support (Docker 18.09+).
- **SSH agent** running with a key that has access to the required git repositories. The build uses SSH forwarding to clone any private repos you might add to `.repos` file during the image build.

  ```bash
  # Verify your SSH agent has a key loaded
  ssh-add -l
  ```

- Clone this repository:
  ```bash
  git clone https://github.com/b-robotized/b_controlled_box_commissioning_containers.git
  ```

---

## 5. Building a Robot Image

The `build-robot-image.sh` script wraps the Docker build arguments. `<IMAGE_TAG>` refers to the major b-controlled-box app version this container supports. You can [see the version history here.](https://github.com/b-robotized/b_ctrldbox_commissioning?tab=readme-ov-file#bcontrolled-box-compatibility)

```bash
chmod +x build-robot-image.sh
./build-robot-image.sh <ROBOT_MANUFACTURER> <IMAGE_TAG>
```

**Example:**

```bash
./build-robot-image.sh ur 1.6.x
```

**What the script does:**

1. Validates that the `<ROBOT_MANUFACTURER>/` directory exists. We are pulling workspace files [from the corresponding workspace directory](https://github.com/b-robotized/b_ctrldbox_commissioning/tree/master/workspaces) *(this is subject to change)*
2. Runs `docker build` with:
   - `--ssh default` -- forwards your SSH agent into the build for `vcs import` of private repos.
   - `--network host` -- allows the build to access the network for package downloads.
   - `--no-cache` -- ensures a clean build every time.
   - `--build-arg ROBOT_MANUFACTURER=<robot>` -- passed to the Dockerfile.
3. Tags the resulting image as:
   ```
   code.b-robotized.com:5050/b_public/b_products/b_controlled_box/b-controlled-box-commissioning-containers/<robot>-commission:<tag>
   ```

> **Why the full registry path as a local tag?** The `start.sh` script in `b_ctrldbox_commissioning` checks for this exact tag. By using the full registry path locally, Docker finds the image and skips pulling from the remote registry. ***This is how local custom builds take priority over pre-built images.***

### Customizing the Build

To modify a robot image, edit the files in the corresponding `<robot>/` directory before building:

- **`comissioning.Dockerfile`** -- Add or remove build steps, install additional packages, change build arguments.
- **`<robot>.jazzy.repos`** -- Add or remove git repositories that are cloned into the workspace via `vcs import`.

---

## 6. Rebuilding the Base Image (Advanced)

Most users **do not need to do this**. The pre-built `rtw-tools:jazzy` base image is pulled automatically during robot image builds. Only rebuild the base if you need to modify the foundational layer (e.g., add system-level packages, or modify the entrypoint).

```bash
cd common/
chmod +x build.sh
./build.sh
```

This builds the base image and tags it locally with the full registry path:

```
code.b-robotized.com:5050/b_public/b_products/b_controlled_box/b-controlled-box-commissioning-containers/rtw-tools:jazzy
```

**Important:** The robot Dockerfiles reference this exact path in their `FROM` line:

```dockerfile
FROM code.b-robotized.com:5050/b_public/b_products/b_controlled_box/b-controlled-box-commissioning-containers/rtw-tools:jazzy
```

Because `build.sh` tags the local build with this same path, Docker resolves the `FROM` to your local image instead of pulling from the remote registry.

> **To revert to the official base image:** Remove the local tag with `docker rmi code.b-robotized.com:5050/.../rtw-tools:jazzy` and Docker will pull the upstream version on the next robot image build.

---

## 7. Using Your Custom Image

After building, the image exists only on your local machine. To run it:

1. Go to your `b_ctrldbox_commissioning` directory.
2. Make sure your `.env` file has matching values. For example:
   ```
   ROBOT_TYPE=ur
   VERSION_TAG=1.6.x
   ```
3. Run `./start.sh`.

`start.sh` checks for the image locally before attempting a pull. Since your local build is tagged with the full registry path, it will be found and used immediately.

### Verifying

You can confirm your local image is being used:

```bash
docker images | grep ur-commission
```

You should see an entry with your tag and a recent creation timestamp.

---

## 8. Reference

### The `clone_robot_dir` Utility

Located at `common/clone_robot_dir.sh`, this script sparse-clones a single directory from the `b_ctrldbox_commissioning` GitHub repository. This avoids cloning the entire repo when only one robot's workspace files are needed.

Usage inside a Dockerfile:
```dockerfile
RUN clone_robot_dir "<repo_url>" "<robot_dir_name>" "<target_dir_name>"
```
