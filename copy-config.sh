#!/bin/bash

CONFIG_FILE_PATH="$SRCROOT/TestoSim/Config.xcconfig"
SAMPLE_CONFIG_FILE_PATH="$SRCROOT/TestoSim/Config-Sample.xcconfig"

if [ -f "$CONFIG_FILE_PATH" ]; then
  echo "$CONFIG_FILE_PATH exists."
else
  echo "$CONFIG_FILE_PATH does not exist, copying sample"
  cp -v "${SAMPLE_CONFIG_FILE_PATH}" "${CONFIG_FILE_PATH}"
fi 