# appstore2 — a custom, self-hosted Android app store

Two pieces, one shared data format:

| Piece | What it is | Where |
| ----- | ---------- | ----- |
| **OpenAppStore** | Flutter/Android app that reads JSON repository indexes, like F-Droid but yours. Ships with **no sources** — you add the repositories you trust. | `custom_app_store/` |
| **Repo Forge** | Tkinter GUI for creating and editing those JSON indexes. | `tools/repo_forge.py` |
| **Repository format** | The JSON schema both sides agree on. | `docs/repository-format.md` |
| **Example data** | A ready-to-host example index. | `samples/example-repo.json` |

## 1. The repository format

A repository is one JSON file (suggested name `repo.json`) listing apps and their
APK releases. Host it anywhere static. Full reference:
[`docs/repository-format.md`](docs/repository-format.md).

## 2. Generating a repository (Python GUI)

```powershell
python tools/repo_forge.py                     # start empty
python tools/repo_forge.py samples/example-repo.json   # edit the sample
```

Only needs Python 3.9+ with Tkinter (included with the python.org installer).

What you can do:

- Fill in the repository name/description, add apps on the left, edit details,
  description, screenshots, and links on the right.
- Manage releases per app under the **Releases** tab. The **Pick APK file…**
  button fills in the byte size and SHA-256 straight from a local `.apk`.
- **Validate** flags missing IDs, duplicate package names, releases with no URL, etc.
- **JSON preview** shows exactly what will be written; **Save** writes `repo.json`.

## 3. Hosting the index + APKs

Put `repo.json` and your `.apk` files on any web server and make sure the `url`
fields point at the APKs. Quick local test server:

```powershell
cd path\to\repo-root
python -m http.server 8000
```

Then add `http://<your-pc-ip>:8000/repo.json` as a source in the app. (The app
allows cleartext HTTP so local/self-hosted setups work.)

## 4. The OpenAppStore app

### Build an APK

```powershell
$env:Path = "$env:USERPROFILE\flutter-portable\flutter\bin;$env:USERPROFILE\android-portable\jdk-17\bin;$env:Path"
$env:JAVA_HOME  = "$env:USERPROFILE\android-portable\jdk-17"
$env:ANDROID_HOME = "$env:USERPROFILE\android-portable\sdk"
cd custom_app_store
flutter pub get
flutter build apk --release
# output: build\app\outputs\flutter-apk\app-release.apk   (~50 MB, all ABIs)
```

For much smaller, device-specific APKs (~17 MB each) use:

```powershell
flutter build apk --release --split-per-abi
# outputs app-armeabi-v7a-release.apk, app-arm64-v8a-release.apk, app-x86_64-release.apk
```

The release build is signed with the debug keystore (see `android/app/build.gradle.kts`)
so it installs directly. Add your own signing config before publishing.

`flutter doctor` should report the Android toolchain and the portable JDK above.

### Run on a connected device

```powershell
flutter devices
flutter run
```

### App icon

The launcher icon comes from `assets/icon/app_icon.png` (a 1024×1024 PNG
generated from your `icon.jpg`). Android adaptive icons use
`assets/icon/app_icon_foreground.png` (the logo centred at 66% so the system
mask never clips it) on a black background. Regenerate after changing the
artwork:

```powershell
dart run flutter_launcher_icons
```

### How it works

- **Sources tab** — add a repository URL. A bare host gets `/repo.json` appended
  automatically. Enable/disable/rename/remove sources with a toggle and menu.
- **Store tab** — search and category-filter every app from all enabled sources.
  Pull to refresh.
- **App detail** — icon, description, screenshots, links, version history, and an
  **Install / Update / Reinstall** button that shows live download progress.
- **Installed tab** — apps installed through the store, with update indicators.

Installing downloads the APK to the app cache, optionally verifies its SHA-256
against the index, then hands it to the Android package installer via a small
native method channel (`android/.../MainActivity.kt`). Android will ask the user
to allow "install unknown apps" the first time.

Permissions requested: `INTERNET` and `REQUEST_INSTALL_PACKAGES`. Nothing else.

## Portable toolchains

Everything used to build this project lives in two self-contained folders that
you can delete at any time. Nothing is written to the registry and nothing is
added to your PATH permanently — prefix it per shell as shown above.

| Tool | Location | Delete to remove |
| ---- | -------- | ---------------- |
| Flutter 3.47.7 SDK | `%USERPROFILE%\flutter-portable\flutter\` | the whole `flutter-portable` folder |
| Temurin JDK 17 | `%USERPROFILE%\android-portable\jdk-17\` | the whole `android-portable` folder |
| Android SDK, platform-tools, platforms 35 + 36, build-tools 36, NDK r28c, CMake | `%USERPROFILE%\android-portable\sdk\` | the whole `android-portable` folder |

Point Flutter at them once with:

```powershell
flutter config --android-sdk "$env:USERPROFILE\android-portable\sdk"
flutter config --jdk-dir "$env:USERPROFILE\android-portable\jdk-17"
```

## Project layout

```
appstore2/
├─ custom_app_store/            OpenAppStore (Flutter, Android)
│  ├─ lib/
│  │  ├─ models/                Source, StoreApp, AppRelease
│  │  ├─ services/              repo fetch, storage, download + install
│  │  ├─ state/store_state.dart single ChangeNotifier holding everything
│  │  ├─ screens/               store, app detail, sources, installed, about
│  │  ├─ widgets/               icon, list tile, empty state, add-source dialog
│  │  ├─ util/                  JSON helpers, link opening
│  │  ├─ theme.dart             Material 3 theme
│  │  └─ main.dart
│  ├─ test/repository_test.dart      unit tests for URL + JSON parsing
│  ├─ assets/icon/              app_icon.png, app_icon_foreground.png
│  └─ android/                  manifest, MainActivity.kt, FileProvider
├─ tools/repo_forge.py          Tkinter repository editor
├─ docs/repository-format.md    JSON schema reference
└─ samples/example-repo.json    worked example
```


