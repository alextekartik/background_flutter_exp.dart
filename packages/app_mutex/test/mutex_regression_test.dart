import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';
import 'package:tekartik_app_flutter_mutex/src/mutex.dart' show MutexImpl;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clientId parameter', () {
    final mutex = Mutex('m_client', clientId: 'my_client') as MutexImpl;
    expect(mutex.clientId, 'my_client');
  });

  test('getData<int> missing key fails', () async {
    final mutex = Mutex('m_data');
    await expectLater(
      mutex.getData<int>('missing').timeout(const Duration(seconds: 3)),
      throwsA(isA<TypeError>()),
    );
  });

  test('synchronized timeout while held', () async {
    final holder = Mutex('m_sync');
    final other = Mutex('m_sync');
    await holder.acquire();
    try {
      await expectLater(
        other
            .synchronized((_) => 1, timeout: const Duration(milliseconds: 500))
            .timeout(const Duration(seconds: 3)),
        throwsA(
          isA<MutexException>().having((e) => e.timeout, 'timeout', isTrue),
        ),
      );
    } finally {
      await holder.release();
    }
  });

  test('slow but alive mutex isolate (50ms ping reply)', () async {
    const name = 'm_slow';
    final fake = ReceivePort();
    final received = <Object?>[];
    fake.listen((message) {
      received.add(message is List ? message[1] : message);
      if (message is List) {
        final reply = message[0] as SendPort;
        // alive, answers in 50ms (more than 10ms, less than 1s)
        Timer(
          const Duration(milliseconds: 50),
          () => reply.send(message[1] == 'ping' ? null : true),
        );
      }
    });
    IsolateNameServer.removePortNameMapping(name);
    IsolateNameServer.registerPortWithName(fake.sendPort, name);
    try {
      final mutex = Mutex(name);
      await mutex.acquire();
      expect(received, ['ping', 'acquire']);
      expect(IsolateNameServer.lookupPortByName(name), fake.sendPort);
      await mutex.release();
      expect(received, ['ping', 'acquire', 'release']);
    } finally {
      IsolateNameServer.removePortNameMapping(name);
      fake.close();
    }
  });
}
