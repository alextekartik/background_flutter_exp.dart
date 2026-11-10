# work_manager_exp3

Work manager experiment 3:

- A task performs the following operations
  - perform a long http request
  - perform a long sqlite transaction
  - Do this in a loop for about 2mn
  - Show a notification (after 20s)
- When not running, it uses background fetch to run Every 15 mn, it has the tag "back"
- When running it is run in the foreground, it has the tag "front"
- When launched from the UI (Floating action button), it has the tag "ui"

A global mutex protects database operation.

# Dependencies:

- workmanager: for background operation every 15mn
- sqflite (Android, iOS, macOS) and sqflite_common_ffi (Linux, Windows) for database operation
- flutter_local_notification: for notifications

## Android build

The `android/` project still applies the Flutter Gradle plugin the old way
(`apply from: .../flutter.gradle`, Gradle 6.7): current Flutter versions
refuse it ("You are applying Flutter's main Gradle plugin imperatively"), so
it does not build for Android until `android/` is regenerated
(`flutter create --platforms android .`) and its manifest, workmanager
(and Firebase) settings ported.
