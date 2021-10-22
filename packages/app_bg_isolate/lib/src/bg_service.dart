import 'package:tekartik_common_utils/common_utils_import.dart';

import 'bg_isolate.dart';

final _log = Log();

class AppBgServiceException {
  final String message;

  AppBgServiceException(this.message);

  @override
  String toString() => 'AppBgServiceException($message)';
}

/// Base services
abstract class AppBgServiceBase {
  /// Set to false when killed by client
  var isKilled = false;

  /// Default command handling
  Future<Object?> onCommand(String method, Object? param) async {
    switch (method) {
      case servicePingMethod:
        return param;
      case serviceKillMethod:
        isKilled = true;
        return null;
      default:
        throw UnimplementedError();
    }
  }
}

/// This services [sendCommand] takes care of restarting the bg isolate
/// if needed
class AppBgServiceClientBase {
  final BgIsolateContext context;
  BgIsolateClient? instance;

  final _lock = Lock();

  AppBgServiceClientBase(this.context);

  // Lock must be hold
  Future<Object?> _sendCommand(String method, Object? param,
      {bool newIsolate = false}) async {
    // devPrint('waiting for isolate');
    BgIsolateClient? isolate;
    await _lock.synchronized(() async {
      if (newIsolate) {
        instance = null;
      }
      isolate = instance ?? await BgIsolateClient.instance(context: context);
    });

    if (isolate == null) {
      // devPrint('no isolate');
      throw AppBgServiceException('cannot find isolate');
    }

    try {
      // devPrint('client sending command $method $param');
      var result = await isolate!.sendCommand(method, param);
      // devPrint('client result: $result');
      return result;
    } catch (e) {
      // devPrint('client send error $e');
      rethrow;
    }
  }

  /// Ping.
  Future<T> ping<T>(T message) async {
    return (await sendCommand(servicePingMethod, message)) as T;
  }

  /// Kill.
  Future<void> kill() async {
    await sendCommand(serviceKillMethod);
  }

  Future<Object?> sendCommand(String method, [Object? param]) async {
    try {
      return await _sendCommand(method, param);
    } catch (e, st) {
      _log.warning('send failed retrying', e, st);
      instance = null;
      return await _sendCommand(method, param, newIsolate: true);
    }
  }
}
