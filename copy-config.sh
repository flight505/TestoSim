#!/bin/bash

# Copy xcconfig file if needed
CONFIG_XCCONFIG_PATH="$SRCROOT/TestoSim/Config.xcconfig"
SAMPLE_XCCONFIG_PATH="$SRCROOT/TestoSim/Config-Sample.xcconfig"

if [ -f "$CONFIG_XCCONFIG_PATH" ]; then
  echo "$CONFIG_XCCONFIG_PATH exists."
else
  echo "$CONFIG_XCCONFIG_PATH does not exist, copying sample"
  cp -v "${SAMPLE_XCCONFIG_PATH}" "${CONFIG_XCCONFIG_PATH}"
fi

# Copy plist file if needed
CONFIG_PLIST_PATH="$SRCROOT/TestoSim/Config.plist"
SAMPLE_PLIST_PATH="$SRCROOT/TestoSim/Config-Sample.plist"

if [ -f "$CONFIG_PLIST_PATH" ]; then
  echo "$CONFIG_PLIST_PATH exists."
else
  echo "$CONFIG_PLIST_PATH does not exist, copying sample"
  cp -v "${SAMPLE_PLIST_PATH}" "${CONFIG_PLIST_PATH}"
fi 