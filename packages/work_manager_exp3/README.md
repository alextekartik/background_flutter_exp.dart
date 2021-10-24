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
- sqflite_common_ffi/sqlite3_flutter_libs for database operation
- flutter_local_notification: for notifications
