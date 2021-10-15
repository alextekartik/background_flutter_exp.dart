import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_bg_isolate/bg_isolate.dart';
import 'package:tekartik_app_flutter_sqflite/sqflite.dart';
import 'package:work_manager_exp/src/tracker_bg_model.dart';
import 'package:work_manager_exp/src/tracker_bg_service.dart';

import 'import.dart';

void trackerBgIsolate(SendPort callerSendPort) {
  print('_trackerBgIsolate');
  final receivePort = initIsolate(callerSendPort, trackerPortName);

  var service = TrackerBgService(databaseFactory);
  if (receivePort == null) {
    return;
  }
  receivePort.listen((msg) async {
    WidgetsFlutterBinding.ensureInitialized();
    var command = ServiceCommandIn.fromEncodable(msg);

    dynamic result = await service.onCommand(command.method, command.param);
    if (result is CvModel) {
      result = result.toMap();
    }
    // devPrint('result: ${result.runtimeType} $result');

    command.sendPort.send(result);
  });
}