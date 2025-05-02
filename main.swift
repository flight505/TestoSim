// TestoSim - Progress Report
// ===========================
// Last Updated: May 2, 2025

/*
FIXES IMPLEMENTED:

1. Core Data Configuration
   - Changed codeGenerationType from "class" to "category" to prevent duplicate file errors
   - Kept custom CoreData class files in Models directory
   - Prevented regenerating CoreData files from model editor to avoid conflicts

2. CloudKit Integration
   - Temporarily disabled CloudKit integration to prevent crashes
   - Changed to standard NSPersistentContainer instead of NSPersistentCloudKitContainer
   - Added task in guide2.md to re-enable properly in the future

3. PK Model Restoration
   - Restored compoundFromEster method with proper error handling
   - Added safety checks to prevent crashes during TestosteroneEster to Compound matching
   - Application now correctly uses advanced PK model when a matching compound is found
   - Falls back to legacy calculation when no match is found

4. Simulator Management
   - Created helper scripts to prevent multiple simulator instances:
     * build-test.sh - Builds without launching simulators (for use with SweetPad)
     * close-simulators.sh - Closes all running simulators
     * launch-test.sh - Launches app in a single, specific simulator instance

TESTING APPROACH:
- Made incremental changes with frequent testing
- Focused on fixing one issue at a time
- Updated documentation to track progress and outstanding tasks
- Use SweetPad for building and running when possible

NEXT STEPS:
1. Test the PK model accuracy with different compounds
2. Implement Bayesian calibration functionality
3. Re-enable CloudKit integration with proper configuration

*/

// This file serves as documentation only and is not part of the build
