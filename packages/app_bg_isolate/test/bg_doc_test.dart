// ignore_for_file: avoid_print

import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_flutter_bg_isolate/bg_isolate.dart';
import 'package:tekartik_app_flutter_bg_isolate/src/bg_isolate.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

/// The service port name.
var _portName = 'MyService';

/// The service entry point.
void myBgIsolate(SendPort callerSendPort) {
  print('testBgIsolate');
  final receivePort = initIsolate(callerSendPort, _portName);

  var service = MyService();
  if (receivePort == null) {
    return;
  }
  receivePort.listen((msg) async {
    WidgetsFlutterBinding.ensureInitialized();
    var command = ServiceCommandIn.fromEncodable(msg);

    dynamic result = await service.onCommand(command.method, command.param);
    command.sendPort.send(result);
  });
}

/// The service implementation
class MyService extends AppBgServiceBase {
  @override
  Future<Object?> onCommand(String method, Object? param) async {
    switch (method) {

      /// Your must implement support for this command
      case servicePingMethod:
        return param;
      default:
        throw UnimplementedError();
    }
  }
}

void main() {
  test('doc service', () async {
    var isolate = (await BgIsolateClient.instance(
        context: BgIsolateContext(name: _portName, isolateFn: myBgIsolate)))!;
    await isolate.sendCommand(servicePingMethod);
  });
}
