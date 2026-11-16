# Start from pre-build rtw-layer image layer
ARG BASE_IMAGE=ghcr.io/b-robotized/b_controlled_box_commissioning_containers/rtw-tools:jazzy
FROM ${BASE_IMAGE}
ARG ROBOT_MANUFACTURER

# Use bash as the default shell
SHELL ["/bin/bash", "-c"]

#########################
# root user
#########################
# ssh forwarding from host works only as root user, so we do our vcs import that needs the authentication right here, before switching to b-robotized user.
RUN mkdir -p -m 0700 /root/.ssh && \
    ssh-keyscan code.b-robotized.com >> /root/.ssh/known_hosts

WORKDIR /home/b-robotized/comissioning/ros2_jazzy/src
COPY dobot.jazzy.repos .
RUN --mount=type=ssh \
  vcs import . < dobot.jazzy.repos
RUN clone_robot_dir "https://github.com/b-robotized/b_ctrldbox_commissioning.git" "dobot" "b_ctrldbox_commissioning/"
RUN chown -R b-robotized:b-robotized /home/b-robotized/comissioning

############################
# now go to our generic user.
USER b-robotized
#########################

WORKDIR /home/b-robotized/comissioning

# commissioning workspace
# `yes` is here to confirm the existing repo we createt via `vcs import` as root user.
RUN yes | rtw workspace create --ws-folder ros2_jazzy --ros-distro jazzy --ignore-ws-cmd-error

############################
# Workspace build
############################

# pull the repos for this robot
WORKDIR /home/b-robotized/comissioning/ros2_jazzy/src

# additionally, pull only the ros2_controllers_test_nodes package from ros2_controllers
RUN git clone -n --depth=1 --filter=tree:0 https://github.com/ros-controls/ros2_controllers.git && \
  cd ros2_controllers && \
  git sparse-checkout set --no-cone /ros2_controllers_test_nodes && \
  git checkout

# run rosdep install
WORKDIR /home/b-robotized/comissioning/ros2_jazzy
RUN sudo apt update && \
    rosdep update && rosdep install --from-paths src --ignore-src -r -y \
    --skip-keys "warehouse_ros_mongo"

# build the workspace
RUN rtw workspace use ros2_jazzy && \
  source /opt/ros/jazzy/setup.bash && \
  colcon build --symlink-install


###########################
# Finishing up
############################

# set env variables
ENV ROS_STATIC_PEERS="192.168.28.28"
# cd into corresponding robot dir
WORKDIR /home/b-robotized/comissioning/ros2_jazzy/src/b_ctrldbox_commissioning/dobot
# auto-source on new terminal opening
RUN echo -e "source /opt/ros_team_workspace/setup.bash\nsource /opt/ros_team_workspace/scripts/configuration/terminal_coloring.bash\nrtw ws ros2_jazzy" >> /home/b-robotized/.bashrc
