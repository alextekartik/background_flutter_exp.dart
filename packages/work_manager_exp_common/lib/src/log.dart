bool debugShowStackTrace = false;

/// Log some data
void log(String tag, Object message) {
  // ignore: avoid_print
  print('/$tag $message');
}

@Deprecated('Dev only')
void devLog(String tag, Object message) {
  log(tag, message);
}

void printStackTrace(StackTrace st) {
  if (debugShowStackTrace) {
    // ignore: avoid_print
    print(st);
  }
}
