# TestoSim

TestoSim is a testosterone pharmacokinetics simulation app that helps visualize injection protocols and predict hormone levels.

## Recent Changes and Updates

### Model Refinements (June 2024)
- **Removed TestosteroneEster Model**: Simplified the codebase by removing the redundant TestosteroneEster model in favor of the more flexible Compound model
- **Protocol Type Selection**: Protocols now clearly identify as either compound-based or blend-based
- **CloudKit Integration**: Fixed container ID issues in CoreDataManager and improved iCloud sync stability
- **UI Improvements**: Updated protocol creation process with a streamlined interface for compound and blend selection
- **Calibration View Fixes**: Resolved compiler issues with CalibrationResultView and parameter naming conflicts
- **Code Cleanup**: Fixed various Swift compiler warnings and improved view composition to avoid "unable to type-check" errors

The app now provides a more consistent experience when creating and managing protocols, with proper support for different compound types and routes of administration.

## Simulator Management

To prevent issues with multiple simulator instances, use the following scripts:

### Build Without Launching (Recommended)

```bash
./build-test.sh [clean]
```

- Use this script to build the application without launching a simulator
- Add `clean` parameter to perform a clean build
- After building, use SweetPad to run the app in a simulator

### Close All Simulators

```bash
./close-simulators.sh
```

- Shuts down all running simulator instances
- Use this if multiple simulators are running and causing issues

### Launch in a Single Simulator

```bash
./launch-test.sh [device_name]
```

- Builds, installs, and launches the app in a specified simulator
- Defaults to "iPhone 16" if no device is specified
- Example: `./launch-test.sh "iPhone 16 Pro"`
- Automatically closes other simulators before launching

## Development Workflow

For the best development experience:

1. Use VS Code with SweetPad extension:
   - Run task "SweetPad: Build" from the command palette (Cmd+Shift+P) or context menu
   - This builds and runs the app in a single simulator instance

2. For command-line builds:
   - Use `./build-test.sh` to build without launching simulators
   - Use `./close-simulators.sh` if you have multiple simulators running

3. For testing specific issues:
   - Use `./launch-test.sh` to launch in a specific simulator
   - This helps isolate issues by using a clean, single simulator instance

## Troubleshooting

If the app crashes during launch:
1. Close all simulators: `./close-simulators.sh`
2. Clean build: `./build-test.sh clean`
3. Launch with a specific device: `./launch-test.sh "iPhone 16"`

If errors still occur, check the device logs:
```bash
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "TestoSim"' --style compact
```

## CloudKit Integration

TestoSim uses CloudKit for cloud data synchronization across devices. This allows users to access their protocols, compounds, and bloodwork results on all their iOS devices.

### Key Features

- User profiles, protocols, and bloodwork data synchronize across devices
- Automatic conflict resolution and merging
- Offline capability with sync when connectivity is restored

### Implementation Details

- The app uses `NSPersistentCloudKitContainer` for Core Data + CloudKit integration
- CloudKit sync can be toggled on/off in the app settings
- Data is stored in the `iCloud.flight505.TestoSim` private database

### Requirements

- User must be signed into iCloud on the device
- iCloud Drive must be enabled
- Proper entitlements are included in the app bundle

### Troubleshooting CloudKit Sync

If data is not syncing properly:

1. Verify the user is signed into iCloud: Settings > Apple ID > iCloud
2. Check iCloud Drive is enabled
3. In the app, toggle CloudKit sync off and back on
4. Restart the app after changing sync settings for changes to take effect

## Compound Selection

TestoSim uses a comprehensive system for selecting compounds:

### Features

- **Compounds Library**: A full database of compounds with accurate pharmacokinetic parameters:
  - Testosterone esters (propionate, enanthate, cypionate, etc.)
  - Other compounds (nandrolone, trenbolone, boldenone, etc.)
  - Various administration routes (intramuscular, subcutaneous, oral, transdermal)

- **Vial Blends**: Support for commercial multi-compound blends:
  - Pre-defined blends like Sustanon 250/350
  - Each component tracked individually with proper pharmacokinetics

### Implementation

- Compounds are modeled with class types, esters, half-lives, and route-specific parameters
- Complete absorption and bioavailability characteristics for each compound and route
- Accurate simulation of single compounds and complex blends 

## API Key Configuration

The TestoSim app uses OpenAI's API for generating insights about hormone protocols and cycles. The app includes a free test API key with a $20 spending limit for all users.

### For Developers

When cloning this repository for development:

1. The app uses a configuration file (`Config.xcconfig`) to store API keys
2. A sample configuration file (`Config-Sample.xcconfig`) is included in the repository
3. On first build, the sample file will be copied to `Config.xcconfig` if it doesn't exist
4. You can optionally replace the placeholder value with your own OpenAI API key

### Security Notes

- The `Config.xcconfig` file is excluded from git in `.gitignore`
- Users can toggle between using their own API key or the test API key in the AI settings 