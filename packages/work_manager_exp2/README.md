# work_manager_exp2

Work manager experiment 2:

- A task performs the following operations
  - perform a long http request
  - perform a long sqlite transaction
  - Do this in a loop for about 2mn
  - Show a notification (after 20s)
- When not running, it uses background fetch to run Every 15 mn, it has the tag "back"
- When running it is run in the foreground, it has the tag "front"
- When launched from the UI (Floating action button), it has the tag "ui"

It uses a global mutex that prevents the background operation to run
when the foreground application is running

# Dependencies:

- workmanager: for background operation every 15mn
- sqflite_common_ffi/sqlite3_flutter_libs for database operation
- flutter_local_notification: for notifications
