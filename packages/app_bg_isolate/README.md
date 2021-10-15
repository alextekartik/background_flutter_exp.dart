App flutter background isolate

## Getting Started

### Setup

```yaml
dependencies:
  tekartik_app_flutter_bg_isolate:
    git:
      url: git://github.com/alextekartik/background_flutter_exp.dart
      ref: main
      path: packages/app_bg_isolate
    version: '>=0.2.2'
```

### Usage

You need to declare at least a port name and an isolate entry point:

```dart
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
```

Then each client must find the isolate to send command to using:

```dart
var isolate = (await BgIsolate.instance(
        context: BgIsolateContext(name: _portName, isolateFn: myBgIsolate)))!;
/// Try the generic ping command
await isolate.sendCommand(servicePingMethod);
```