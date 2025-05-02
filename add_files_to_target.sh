#!/bin/bash

# This script lists all Swift files in the project that need to be added to the target
# Run this script, then add these files to your target in Xcode

echo "Swift files to add to target:"
echo ""

# Find all Swift files in the TestoSim directory
find ./TestoSim -name "*.swift" | sort

echo ""
echo "Instructions:"
echo "1. In Xcode, select all these files in the Project Navigator (left sidebar)"
echo "2. In the File Inspector (right sidebar, first tab), check the box for TestoSim target"
echo "3. Clean and build the project (Cmd+Shift+K, then Cmd+B)" 