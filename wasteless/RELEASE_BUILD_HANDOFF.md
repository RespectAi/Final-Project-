# Release Build and Notification Handoff

## Objective

Create an installable Android release APK and make expiry notifications reliable on real devices.

## Notification work completed

The app uses `flutter_local_notifications` for local scheduled expiry reminders. It does **not** use Firebase Cloud Messaging or require internet access to deliver a reminder that has already been scheduled.

The following changes were made:

1. `lib/main.dart`
   - Initializes local notifications with iOS permissions disabled at initialization.
   - Explicitly requests notification permission after initialization:
     - Android 13 and later: `POST_NOTIFICATIONS` prompt.
     - iOS/macOS: alert, badge, and sound permissions.
   - Restores scheduled expiry notifications when the user reaches the home screen.

2. `lib/services/supabase_service.dart`
   - Consolidates reminder creation in `_scheduleExpiryReminder`.
   - Uses stable notification IDs based on the inventory item UUID.
   - Makes expiry reminders one-time notifications. The previous
     `matchDateTimeComponents: DateTimeComponents.dateAndTime` caused an
     incorrect yearly repetition.
   - Cancels the relevant notification when an inventory item is deleted.
     This also covers the existing waste and donation flows because they call
     `deleteInventoryItem`.
   - Rebuilds current reminders at application startup. It clears stale
     reminders first, then schedules valid future reminders for the signed-in
     user's current inventory.
   - Logs notification scheduling failures through `debugPrint` rather than
     silently ignoring them.

3. `android/app/build.gradle.kts`
   - Enables core-library desugaring, which the installed notifications package
     requires for scheduled notifications.
   - Adds `com.android.tools:desugar_jdk_libs:2.1.5`.
   - Pins NDK `27.0.12077973`, because the Flutter-selected NDK `26.3.11579264`
     on this machine is incomplete (its `source.properties` file is missing).

4. `android/build.gradle.kts`
   - Supplies Android namespaces to two old plugins that do not declare one:
     - `flutter_local_notifications` -> `com.dexterous.flutterlocalnotifications`
     - `flutter_native_timezone` -> `com.whelksoft.flutter_native_timezone`
   - Forces the legacy timezone plugin to use Kotlin Gradle Plugin `2.1.0`.
     The plugin requested Kotlin `1.3.50`, while the installed Android Gradle
     Plugin 8.7.3 requires Kotlin 1.5.20 or newer.

## What was verified

- Dart files were formatted successfully.
- Static analysis was run successfully with no reported Dart errors.
- The Android build advanced past the NDK error and both legacy-plugin
  namespace/Kotlin configuration errors.
- The release build automatically accepted licenses and installed missing:
  - Android SDK Build-Tools 34.0.0
  - Android SDK Platform 35 (revision 2)
  - Android SDK Platform 34 installation was in progress at the last check.

## Build attempts and blockers encountered

| Order | Result | Resolution |
| --- | --- | --- |
| 1 | NDK `26.3.11579264` had no `source.properties`. | Switched the project to installed NDK `27.0.12077973`. |
| 2 | `flutter_local_notifications 12.0.4` had no Android namespace. | Added project-level namespace compatibility configuration. |
| 3 | `flutter_native_timezone 2.0.0` had no Android namespace. | Added project-level namespace compatibility configuration. |
| 4 | `flutter_native_timezone` requested unsupported Kotlin `1.3.50`. | Forced Kotlin Gradle Plugin `2.1.0`. |
| 5 | Build tools/platforms needed by Gradle were absent. | Gradle began installing the required Android SDK components automatically. |

The non-fatal repeated warning about `flutter_local_notifications_linux` does
not affect Android APK output. It is a legacy package metadata warning emitted
while Flutter scans desktop platforms.

## Current state

The background command launched for the final attempt was:

```powershell
flutter build apk --release
```

At the final observation it was still running while Gradle installed Android
SDK Platform 34. It had not yet reported a new compilation error and no APK
had been produced at that time.

When successful, the expected output is:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Absolute path:

```text
C:\Users\Moses\Documents\PLP Febuary Chort\Python2\Flutter Assignment\Final-Project-\wasteless\build\app\outputs\flutter-apk\app-release.apk
```

The final build log is written to:

```text
build\release-build.log
```

## Real-device test checklist

1. Install `app-release.apk` on an Android phone.
2. Open WasteLess and allow notification permission when prompted.
3. On Android 12 and later, if reminders do not fire at the exact time, enable
   the app's **Alarms & reminders** special access in Android Settings.
4. Add an item whose reminder time is a few minutes in the future.
5. Close/background the app and wait for the reminder.
6. Delete the item and confirm its future reminder no longer appears.
7. Reopen the app and confirm valid future reminders are restored.

## Recommended future maintenance

The build compatibility settings are intentionally limited to the current
machine/toolchain. The durable maintenance task is to upgrade
`flutter_local_notifications` and `flutter_native_timezone` to modern versions
that natively support the installed Android Gradle Plugin and Kotlin version.
