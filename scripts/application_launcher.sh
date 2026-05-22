#!/bin/bash
# VIBE Desktop wrapper script to handle the start of an application inside a container. 
# Allows to add pre and post tasks.
# Usage: ./application_launcher.sh container_name [application_name] [parameters]

# TODO: Add help / parameter check

CONTAINERIMAGE="$1"
APPLICATION="$2"
# Get all additional parameters to pass them on to the application
PARAMETER=$(echo "$@" | cut -d ' ' -f 3-)

if [ ! -z $APPLICATION ]; then
    echo "[Application Launcher] Starting application $APPLICATION from container image $CONTAINERIMAGE..."
else
    echo "[Application Launcher] Starting default application from container image $CONTAINERIMAGE..."
fi

# Pre Tasks

# start the application
echo "[Application Launcher] Starting application..."
if [ -z "$APPLICATION" ]; then
    apptainer run --nv $CONTAINERIMAGE
else
    apptainer exec --nv $CONTAINERIMAGE /opt/launchers/start_$APPLICATION.sh $PARAMETER
fi

# Post Tasks
## Keep terminal open on error
if [ $? != 0 ]; then
  echo
  read -p "Application crash detected! Press any key to close the terminal." -n1 -s
fi
