// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';

/// Adds one to a counter shared by all the isolates, one at a time.
Future<int> addOne(String _) async {
  var mutex = Mutex('example_counter');
  return await mutex.synchronized((mutex) async {
    var value = await mutex.getData<int?>('counter') ?? 0;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await mutex.setData('counter', value + 1);
    return value + 1;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([for (var i = 0; i < 4; i++) compute(addOne, '$i')]);
  print(await Mutex('example_counter').getData<int>('counter')); // 4
}
