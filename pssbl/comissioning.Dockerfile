# Start from pre-build rtw-layer image layer
FROM code.b-robotized.com:5050/b_public/b_products/b_controlled_box/b-controlled-box-commissioning-containers/rtw-tools:jazzy
ARG ROBOT_MANUFACTURER

# Use bash as the default shell
SHELL ["/bin/bash", "-c"]

#########################
# root user
#########################
# ssh forwarding from host works only as root user, so we do our vcs import that needs the authentification right here, before switching to b-robotized user.
RUN mkdir -p -m 0700 /root/.ssh && \
    ssh-keyscan code.b-robotized.com >> /root/.ssh/known_hosts

RUN apt update -y && apt upgrade -y
RUN apt install -y \
        nlohmann-json3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/b-robotized/commissioning/ros2_jazzy/src
COPY pssbl.jazzy.repos .
RUN --mount=type=ssh \
  vcs import . < pssbl.jazzy.repos
# clones a single named dir from a github repo - only fetches the workspace directory for this specific robot.
RUN clone_robot_dir "https://github.com/b-robotized/b_ctrldbox_commissioning.git" "pssbl" "b_ctrldbox_commissioning/"
RUN chown -R b-robotized:b-robotized /home/b-robotized/commissioning

RUN sudo apt update -y && apt upgrade -y && sudo apt install -y ros-jazzy-moveit

############################
# now go to our generic user.
USER b-robotized
#########################

WORKDIR /home/b-robotized/commissioning

# commissioning workspace
# `yes` is here to confirm the existing repo we createt via `vcs import` as root user.
RUN yes | rtw workspace create \
--ws-folder ros2_jazzy \
--ros-distro jazzy \
--ignore-ws-cmd-error \
--env-vars RMW_IMPLEMENTATION=rmw_zenoh_cpp RUST_LOG=zenoh=warn,zenoh_transport=warn 

############################
# Workspace build
############################

# pull the repos for this robot
WORKDIR /home/b-robotized/commissioning/ros2_jazzy/src

# run rosdep install
WORKDIR /home/b-robotized/commissioning/ros2_jazzy
RUN sudo apt update && rosdep update && rosdep install --from-paths src --ignore-src -r -y --rosdistro=jazzy

# build the workspace
RUN rtw workspace use ros2_jazzy && \
  source /opt/ros/jazzy/setup.bash && \
  colcon build --symlink-install --cmake-args -DBUILD_TESTING=OFF


###########################
# Finishing up
############################

# set env variables
ENV ROS_STATIC_PEERS="192.168.28.7"    
# cd into corresponding robot dir
WORKDIR /home/b-robotized/commissioning/ros2_jazzy/src/b_ctrldbox_commissioning
# auto-source on new terminal opening
RUN echo -e "source /opt/ros_team_workspace/setup.bash\nsource /opt/ros_team_workspace/scripts/configuration/terminal_coloring.bash\nrtw ws ros2_jazzy" >> /home/b-robotized/.bashrc
