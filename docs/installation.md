# Installation

Welcome to SpineLeaf! You can install the application either by downloading pre-compiled binaries or by building it from the source code.

## Download Pre-compiled Binaries

For most users, downloading the pre-compiled binary is the easiest way to get started.

[Download the latest release for Android and IOS here](https://github.com/PippyUrkel/SpineLeaf/releases)  

## Build from Source

If you prefer to compile the application yourself, you will need the Flutter SDK installed on your system.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Version 3.0.0 or higher)
- Appropriate toolchains for your platform (e.g., Android Studio for Android, Xcode for iOS/macOS, Visual Studio for Windows).

### Build Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/PippyUrkel/spineleaf.git
   cd spineleaf
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application locally:**
   ```bash
   flutter run
   ```

4. **Build the release version:**
   Choose your target platform below to build the final executable.

   - **Android (APK):** `flutter build apk --release`
   - **Android (AppBundle):** `flutter build appbundle --release`
   - **iOS:** `flutter build ios --release`
   - **macOS:** `flutter build macos --release`
   - **Windows:** `flutter build windows --release`
   - **Linux:** `flutter build linux --release`
