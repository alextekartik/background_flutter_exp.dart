// Copied from https://github.com/simolus3/moor/issues/399
import 'dart:isolate';
import 'dart:ui';

class Log {
  bool on = false;
  void warning(String s, [Object? exception, StackTrace? st]) {
    // ignore: avoid_print
    print('W $s${exception == null ? '' : '($exception)'}');
  }

  void finest(String s) {
    // ignore: avoid_print
    print('F $s');
  }

  void info(String s) {
    // ignore: avoid_print
    print('I $s');
  }
}

var _log = Log();

typedef BgIsolateFunction = void Function(SendPort callerSendPort);

class BgIsolateContext {
  late final BgIsolateFunction isolateFn;

  /// required
  final String name;

  /// Default to [true]
  final bool createIsolate;

  BgIsolateContext(
      {required this.isolateFn, required this.name, this.createIsolate = true});
}

class BgIsolateClient {
  BgIsolateClient._(this._sendPort);

  final SendPort _sendPort;

  static Future<BgIsolateClient?> instance({
    required BgIsolateContext context,
    bool createIsolate = true,
  }) async {
    final po = await _retrieveIsolateSendPort(
        createIsolate: createIsolate, context: context);

    if (po == null) {
      return null;
    }

    return BgIsolateClient._(po);
  }

  /// Should return the same object
  Future<Object?> ping([Object? param]) {
    return sendCommand(servicePingMethod, param);
  }

  /// Send a command and read the response
  Future<Object?> sendCommand(String command, [Object? param]) async {
    final rp = ReceivePort();
    _sendPort.send(ServiceCommandIn(rp.sendPort, command, param).toEncodable());
    return await rp.first;
  }

  static Future<SendPort?> _retrieveIsolateSendPort({
    // Create the isolate when needed.
    bool createIsolate = true,
    required BgIsolateContext context,
  }) async {
    final lookup = IsolateNameServer.lookupPortByName(context.name);

    if (lookup != null) {
      final rp = ReceivePort();
      lookup
          .send(ServiceCommandIn(rp.sendPort, servicePingMethod).toEncodable());
      try {
        // 10s timeout...
        await rp.first.timeout(const Duration(milliseconds: 10000));
        return lookup;
      } catch (e) {
        if (_log.on) {
          _log.warning(
              'isolate unresponsive. Force terminate, unregister and respawn');
        }
        lookup.send(
            ServiceCommandIn(rp.sendPort, serviceKillMethod).toEncodable());
        IsolateNameServer.removePortNameMapping(context.name);
      }
    }

    if (!createIsolate) {
      return null;
    }

    if (_log.on) {
      _log.finest('Isolate not running yet');
    }
    try {
      // At the moment, spawning isolates is blocked by various issues.
      // On Android, spawned isolates will not have access to Flutter plugins.
      // On iOS, the spawning is most likely blocked thanks to https://github.com/flutter/flutter/issues/14815.
      return _assignCurrentIsolate(context: context);
    } catch (e, stackTrace) {
      if (_log.on) {
        _log.warning('ISOLATE SPAWN FAILED - SOME BG BROKEN', e, stackTrace);
      }
      return Future.error('someIsolate init failed');
    }
  }

  static Future<SendPort> _assignCurrentIsolate(
      {required BgIsolateContext context}) async {
    final rp = ReceivePort();
    context.isolateFn(rp.sendPort);
    return await rp.first as SendPort;
  }
}

ReceivePort? initIsolate(SendPort callerSendPort, String name) {
  final newIsolateReceivePort = ReceivePort();
  // Register the port by name
  final res = IsolateNameServer.registerPortWithName(
    newIsolateReceivePort.sendPort,
    name,
  );
  if (!res) {
    if (_log.on) {
      _log.info('can not register the isolate send port - already registered?');
    }
    callerSendPort.send(null);
    return null;
  }

  callerSendPort.send(newIsolateReceivePort.sendPort);
  return newIsolateReceivePort;
}

const servicePingMethod = 'ping';
const serviceKillMethod = 'kill';

/// In parameter
class ServiceCommandIn {
  late final SendPort sendPort;
  late final String method;
  late final Object? param;

  ServiceCommandIn(this.sendPort, this.method, [this.param]);

  /// We always serialize parameters.
  factory ServiceCommandIn.fromEncodable(dynamic message) {
    /// Assume a list
    var list = message as List;
    var sendPort = list[0] as SendPort;
    var method = list[1] as String;
    Object? param;
    if (list.length > 2) {
      param = list[2];
    }
    return ServiceCommandIn(sendPort, method, param);
  }
  List toEncodable() {
    return [sendPort, method, param];
  }

  @override
  String toString() => '$method $param';
}
