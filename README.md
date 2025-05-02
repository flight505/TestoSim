# TestoSim

TestoSim is a testosterone pharmacokinetics simulation app that helps visualize injection protocols and predict hormone levels.

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