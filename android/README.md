# Water Sort Puzzle

A mobile-friendly Flutter implementation of the Water Sort Puzzle game.

## Rules
- Each bottle holds up to 5 colored units. The level starts with most bottles
  fully filled with mixed colors plus two empty bottles.
- Tap a source bottle, then a destination bottle to pour.
- A pour is valid only if the destination is empty, or its top color matches
  the source's top color, and the destination has free space.
- Pouring transfers **all** contiguous same-color units from the top of the
  source that fit into the destination, in a single move.
- You win when every bottle is either empty or full of a single color.

## Project layout
```
lib/
  main.dart                  # MaterialApp entry
  game/
    bottle.dart              # Bottle model
    game_state.dart          # GameState + rules
  widgets/
    bottle_widget.dart       # Tube visual
  screens/
    home_screen.dart         # Difficulty selector
    game_screen.dart         # Play area, Reset, Win dialog
```

## First-time setup on macOS

```bash
# 1. Install Flutter (includes Dart)
brew install --cask flutter

# 2. Install Android SDK command-line tools and platform-tools
brew install --cask android-commandlinetools
brew install --cask android-platform-tools

# 3. Install JDK 17 (Android Gradle Plugin still requires 17; JDK 26 is too new)
brew install --cask zulu@17

# 4. Configure environment (add to ~/.zshrc)
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"

# 5. Install required SDK pieces and accept licenses
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
flutter doctor --android-licenses

# 6. Verify
flutter doctor
```

## Generate Android platform folder and run

The `android/` platform code is generated, not checked in. From this directory:

```bash
flutter create . --platforms=android --project-name water_sort_puzzle
flutter pub get
flutter run            # on a connected device / running emulator
```

To pick an emulator:
```bash
flutter emulators                 # list
flutter emulators --launch <id>   # launch one
```

## Reset vs. Play Again
- The **Reset** icon in the AppBar restarts the current level with the same
  starting layout.
- The **Play Again** button in the win dialog generates a brand-new random
  level.
