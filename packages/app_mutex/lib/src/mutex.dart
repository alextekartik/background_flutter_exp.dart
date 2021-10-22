import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:nanoid/nanoid.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

var _timeout = const Duration(milliseconds: 1000);

class Log {
  bool on = false; // devWarning(true);
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

/// Cross isolate mutex
abstract class Mutex {
  factory Mutex(String name, {String? clientId}) =>
      MutexImpl(name, clientId: clientId);
  String get name;

  /// Acquire
  ///
  /// if timeout is reached both cancelled and timeout is set in the exception
  Future<void> acquire({bool Function()? cancel, Duration? timeout});

  /// Release
  Future<void> release();

  /// Used as a lock.
  Future<T> synchronized<T>(FutureOr<T> Function(Mutex mutex) action,
      {bool Function()? cancel, Duration? timeout});

  /// Set some shared data.
  Future<void> setData<T>(String key, T data);

  /// Get some shared data.
  Future<T> getData<T>(String key);
}

var killCommand = 'kill';
var pingCommand = 'ping';
var acquireCommand = 'acquire';
var releaseCommand = 'release';
var setCommand = 'set';
var getCommand = 'get';

/// First param is a sendport, second is the name
void _mutexIsolate(List param) {
  String? currentClientId;
  var callerSendPort = param[0] as SendPort;
  var name = param[1] as String;
  final receivePort = ReceivePort();
  var data = <String, Object?>{};
  // First thing, send receivePort to caller
  receivePort.listen((message) {
    // kill is a special command without response
    if (message == killCommand) {
      Isolate.current.kill();
      return;
    }
    var sendParam = message as List;
    var sendPort = sendParam[0] as SendPort;
    var param = sendParam[1];
    if (param == pingCommand) {
      sendPort.send(null);
    } else if (param == acquireCommand) {
      var clientId = sendParam[2] as String;
      if (currentClientId == null) {
        currentClientId = clientId;
        sendPort.send(true);
      } else {
        sendPort.send(false);
      }
    } else if (param == releaseCommand) {
      var clientId = sendParam[2] as String;
      if (currentClientId == clientId) {
        currentClientId = null;
        sendPort.send(true);
      } else {
        sendPort.send(false);
      }
    } else if (param == setCommand) {
      var key = sendParam[2] as String;
      var value = sendParam[3];
      if (value == null) {
        data.remove(key);
      } else {
        data[key] = value;
      }
      sendPort.send(true);
    } else if (param == getCommand) {
      var key = sendParam[2] as String;
      sendPort.send(data[key]);
    }
  });

  final res = IsolateNameServer.registerPortWithName(
    receivePort.sendPort,
    name,
  );
  if (!res) {
    if (_log.on) {
      _log.info('can not register the isolate send port - already registered?');
    }
    callerSendPort.send(null);
    Isolate.current.kill();
    return;
  }

  callerSendPort.send(receivePort.sendPort);
}

class MutexImpl implements Mutex {
  @override
  final String name;

  late final String clientId;
  MutexImpl(this.name, {String? clientId}) {
    this.clientId = nanoid();
  }

  SendPort? _sendPort;
  Future<T> _send<T>(Object? param) async {
    while (true) {
      try {
        var sendPort = _sendPort ??= await _getMutexIsolateSendPort();

        final rp = ReceivePort();
        var responseFuture = rp.first;
        sendPort.send([rp.sendPort, if (param is List) ...param else param]);
        var response = await responseFuture.timeout(_timeout);
        return response as T;
      } catch (e) {
        if (_log.on) {
          _log.warning('$e command $param failed, try again');
        }
        // Force fetching the port again
        // Race condition should be ok
        _sendPort = null;
      }
    }
  }

  Future<SendPort> _getMutexIsolateSendPort() async {
    while (true) {
      final lookup = IsolateNameServer.lookupPortByName(name);

      if (lookup != null) {
        final receivePort = ReceivePort();
        lookup.send([receivePort.sendPort, pingCommand]);
        try {
          // 1 second timeout
          await receivePort.first.timeout(_timeout);
          return lookup;
        } catch (e) {
          if (_log.on) {
            _log.warning(
                '$e isolate unresponsive. Force terminate, unregister and respawn');
          }
          try {
            lookup.send(killCommand);
          } catch (_) {}
          IsolateNameServer.removePortNameMapping(name);
        }
      }
      final receivePort = ReceivePort();
      var sendPortFuture = receivePort.first;

      await Isolate.spawn(_mutexIsolate, [receivePort.sendPort, name],
          debugName: 'mutex_isolate_${Random().nextInt(10000000)}');
      try {
        // 1 second timeout
        var sendPort = await sendPortFuture.timeout(_timeout) as SendPort?;
        if (sendPort != null) {
          return sendPort;
        }
      } catch (e) {
        if (_log.on) {
          _log.warning('$e isolate unresponsive. try again');
        }
      }
    }
  }

  final _acquireLock = Lock();
  @override
  Future<void> acquire({bool Function()? cancel, Duration? timeout}) async {
    var sw = Stopwatch()..start();
    while (true) {
      var result = await _acquireLock.synchronized(() async {
        var result = await _send<bool>([acquireCommand, clientId]);
        if (!result) {
          if (cancel != null && cancel()) {
            throw MutexException._(
                cancelled: true, message: 'Acquired cancelled');
          }
          if (timeout != null) {
            if (sw.elapsed.inMilliseconds > timeout.inMilliseconds) {
              throw MutexException._(
                  timeout: true, cancelled: true, message: 'Acquired timeout');
            }
          }
        }
        return result;
      });
      if (result) {
        break;
      }
      await sleep(100);
    }
  }

  /// Run in critical section
  @override
  Future<T> synchronized<T>(FutureOr<T> Function(Mutex mutex) action,
      {bool Function()? cancel, Duration? timeout}) async {
    try {
      await acquire(cancel: cancel);
      return await action(this);
    } finally {
      try {
        await release();
      } catch (_) {}
    }
  }

  @override
  Future<void> release() async {
    var result = await _send<bool>([releaseCommand, clientId]);
    if (!result) {
      throw MutexException._(
          notAcquired: true, message: 'Release not acquired');
    }
  }

  @override
  Future<T> getData<T>(String key) async {
    return (await _send<T>([getCommand, key]));
  }

  @override
  Future<void> setData<T>(String key, T data) async {
    await _send<bool>([setCommand, key, data]);
  }
}

/// Mutex exception during acquired.
class MutexException implements Exception {
  final bool cancelled;
  final bool timeout;
  final bool notAcquired;
  final String message;

  MutexException._(
      {this.cancelled = false,
      this.timeout = false,
      this.notAcquired = false,
      required this.message});
  @override
  String toString() => message;
}
