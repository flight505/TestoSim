#!/bin/bash
# TestoSim simulator management - closes all running simulators
# Usage: ./close-simulators.sh

echo "Checking for running simulators..."
RUNNING_SIMS=$(xcrun simctl list devices | grep -i "booted" | wc -l)

if [ $RUNNING_SIMS -gt 0 ]; then
    echo "Found $RUNNING_SIMS running simulator(s). Shutting down..."
    xcrun simctl shutdown all
    echo "All simulators are now closed."
else
    echo "No running simulators found."
fi 