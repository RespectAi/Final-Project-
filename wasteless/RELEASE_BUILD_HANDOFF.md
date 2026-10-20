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
     - Android 12 and later: exact-alarm special access for precise reminders.
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

4. `pubspec.yaml` and `pubspec.lock`
   - Upgrades `flutter_local_notifications` to 17.2.4 to fix Android SDK
     compilation and use the supported scheduling API.
   - Replaces `flutter_native_timezone` 2.0.0 with `flutter_timezone` 3.0.1,
     which supports the current Flutter Android embedding.
5. `android/app/src/main/AndroidManifest.xml`
   - Declares boot/exact-alarm permissions and notification receivers so
     scheduled reminders can be restored after device reboot.

## What was verified

- Dart files were formatted successfully.
- Static analysis was run successfully with no reported Dart errors.
- The Android build advanced past the NDK error and both legacy-plugin
  namespace/Kotlin configuration errors.
- The release build accepted licenses and installed missing SDK components:
  - Android SDK Build-Tools 34.0.0
  - Android SDK Platform 35 (revision 2)
  - Android SDK Platform 34 (revision 3)
- The final release APK built successfully and its signature was verified.

## Build attempts and blockers encountered

| Order | Result | Resolution |
| --- | --- | --- |
| 1 | NDK `26.3.11579264` had no `source.properties`. | Switched the project to installed NDK `27.0.12077973`. |
| 2 | `flutter_local_notifications 12.0.4` had no Android namespace and failed Java compilation because `bigLargeIcon(null)` became ambiguous. | Upgraded to `flutter_local_notifications 17.2.4`, which includes the Android overload fix. |
| 3 | `flutter_native_timezone 2.0.0` had no Android namespace and referenced Flutter's removed Android `Registrar` API. | Replaced it with the maintained `flutter_timezone 3.0.1` fork. |
| 4 | The old timezone plugin requested unsupported Kotlin `1.3.50` and targeted a removed embedding API. | Removed that plugin and its compatibility workarounds. |
| 5 | Build tools/platforms needed by Gradle were absent. | Gradle installed the required Android SDK components; the final build then succeeded. |

The earlier Linux plugin metadata warning was non-fatal and did not affect APK
output.

## Final build result

The release build completed successfully:

```powershell
flutter build apk --release --no-pub -v
```

The first complete build took 8m 51s because Gradle downloaded and installed
missing Android SDK/build dependencies. The verbose log advanced throughout
resource compilation, desugaring, packaging, and assembly; the process exited
with code 0. An orphaned Flutter process from an earlier attempt was holding the
Flutter cache lock and blocking new Flutter commands before they reached Gradle.
It was stopped before the successful run.

The output APK is:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Absolute path:

```text
C:\Users\Moses\Documents\PLP Febuary Chort\Python2\Flutter Assignment\Final-Project-\wasteless\build\app\outputs\flutter-apk\app-release.apk
```

The APK is 25,609,203 bytes. `apksigner` verified its v1 and v2 signatures, and
Android package metadata reports `com.example.wasteless`, version `1.0.0`
(code 1), minimum SDK 21, and target SDK 35. It uses the debug key configured
by the existing release build type, so it can be installed for testing and
sideloading. Store distribution should use the publisher's private signing key.
SHA-256: `B0341DE541E3254E087842EF73CF4B12232B9E62504CE0BFC15904C727DABB7D`.

The final build log is written to:

```text
build\release-build.log
```

It ends with `BUILD SUCCESSFUL` and Flutter's `Built ...app-release.apk` line.

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

Keep `flutter_local_notifications` and `flutter_timezone` updated within their
compatible version ranges as the Android SDK and Flutter toolchain evolve.
