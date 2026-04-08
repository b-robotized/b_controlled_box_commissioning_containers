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

WORKDIR /home/b-robotized/comissioning/ros2_jazzy/src
COPY kuka.jazzy.repos .
RUN --mount=type=ssh \
  vcs import . < kuka.jazzy.repos
# clones a single named dir from a github repo - only fetches the workspace directory for this specific robot.
RUN clone_robot_dir "https://github.com/b-robotized/b_ctrldbox_commissioning.git" "kuka" "b_ctrldbox_commissioning/"
RUN chown -R b-robotized:b-robotized /home/b-robotized/comissioning

############################
# now go to our generic user.
USER b-robotized
#########################

WORKDIR /home/b-robotized/comissioning

# commissioning workspace
# `yes` is here to confirm the existing repo we created via `vcs import` as root user.
RUN yes | rtw workspace create \
--ws-folder ros2_jazzy \
--ros-distro jazzy \
--ignore-ws-cmd-error \
--env-vars RMW_IMPLEMENTATION=rmw_zenoh_cpp RUST_LOG=zenoh=warn,zenoh_transport=warn 

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
RUN sudo apt update && rosdep update && rosdep install --from-paths src --ignore-src -r -y

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
WORKDIR /home/b-robotized/comissioning/ros2_jazzy/src/b_ctrldbox_commissioning
# auto-source on new terminal opening
RUN echo -e "source /opt/ros_team_workspace/setup.bash\nsource /opt/ros_team_workspace/scripts/configuration/terminal_coloring.bash\nrtw ws ros2_jazzy" >> /home/b-robotized/.bashrc
