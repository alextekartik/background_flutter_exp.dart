import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/rxdart.dart';
import 'package:work_manager_exp4/main.dart';
import 'package:work_manager_exp_common/log.dart';

import 'client.dart';
import 'globals.dart';
import 'import.dart';

const _channelId = 'exp_push';
const channel = AndroidNotificationChannel(
  _channelId, // id
  'Push Notifications', // title
  description: 'Channel for push notifications.', // description
  importance: Importance.max,
);

const String _tag = 'fcm';
bool debugPushMessaging = false; //devWarning(true);

class PushNotificationInfo extends CvModelBase {
  @override
  List<CvField> get fields => [];
}

/// To handle as soon as we can
/// We receive it too late on start
PushNotificationInfo? launchPushNotification;

enum PushMessagingEventType {
  onMessage,
  onLaunch,
  onResume,
}

class PushMessagingEvent {
  final PushMessagingEventType type;
  final PushNotificationInfo info;

  PushMessagingEvent({required this.type, required this.info});

  @override
  String toString() => '$type $info';
}

/// Managing the push service
class PushMessagingService {
  FirebaseMessaging? _firebaseMessaging;
  final _tokenSubject = BehaviorSubject<String>();
  StreamSubscription? _tokenSubscription;
  final _pushMessagingEventSubject = PublishSubject<PushMessagingEvent>();

  Stream<PushMessagingEvent> get eventStream => _pushMessagingEventSubject;
  // testing only
  @Deprecated('Dev only')
  Sink<PushMessagingEvent> get eventSink => _pushMessagingEventSubject;
  Stream<String> get tokenStream => _tokenSubject.distinct();

  bool _inited = false;
  final _lock = Lock();
  // Should be call after runApp is called, when
  Future<void> init() async {
    if (!_inited) {
      await _lock.synchronized(() async {
        if (!_inited) {
          _inited = true;
          await _init();
        }
      });
    }
  }

  Future<void> _init() async {
    await Firebase.initializeApp();
    _firebaseMessaging = FirebaseMessaging.instance;
    // devLog(_tag, 'FCM init messaging');

    if (Platform.isIOS) {
      await _initIOSPermission();
    }
    _firebaseMessaging!.getToken().then((token) {
      if (token != null) {
        _tokenSubject.add(token);
      }
    }).unawait();

    _tokenSubscription = _firebaseMessaging!.onTokenRefresh.listen((token) {
      _tokenSubject.add(token);
    });

    void _addMessage(
        Map<String, dynamic> message, PushMessagingEventType type) {
      if (isDebug) {
        log(_tag, '$type message ${json.encode(message)}');
      }
      // We don't know the context yet
      _pushMessagingEventSubject.add(PushMessagingEvent(
          type: type, info: PushNotificationInfo(/*message*/)));
    }

    // If set for testing, push it
    if (launchPushNotification != null) {
      _addMessage(
          launchPushNotification!.toMap(), PushMessagingEventType.onLaunch);
    }

    /*
    if (isTopicDebug) {
      await _firebaseMessaging!.subscribeToTopic(fcmTestTopicDebug);
    }
    if (!gProd) {
      await _firebaseMessaging!.subscribeToTopic(fcmTestTopicDev);
    }*/

    void _handleMessage(RemoteMessage message) {
      if (isDebug) {
        log(_tag, '_handleMessage:$message');
        log(_tag, message.data);
      }
      gAppNotificationSubject.add(message.data);
    }

    // It is assumed that all messages contain a data field with the key 'type'
    Future<void> setupInteractedMessage() async {
      // Get any messages which caused the application to open from
      // a terminated state.
      var initialMessage = await FirebaseMessaging.instance.getInitialMessage();

      // If the message also contains a data property with a "type" of "chat",
      // navigate to a chat screen
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }

      // Also handle any interaction when the app is in the background via a
      // Stream listener
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
      //final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (isDebug) {
          log(_tag, 'onMessage:$message');
          log(_tag, message.data);
        }
        var notification = message.notification;
        var android = message.notification?.android;

        // If `onMessage` is triggered with a notification, construct our own
        // local notification to show to users using the created channel.
        if (notification != null && android != null) {
          gFlutterLocalNotificationsPlugin.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  //channel.description,
                  icon: android.smallIcon,
                  // other properties...
                ),
              ),
              payload: jsonEncode(message.data));
        }
        serviceBgRun(service, 'fg_push');
      });
    }

    await setupInteractedMessage();
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true, // Required to display a heads up notification
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _initIOSPermission() async {
    await _firebaseMessaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  void dispose() {
    _tokenSubject.close();
    _pushMessagingEventSubject.close();
    _tokenSubscription?.cancel();
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
  try {
    var service = await getTrackerService();

    stderr.writeln('The background notification was triggered');
    await serviceBgRun(service, 'bg_push');
  } catch (e, st) {
    print(e);
    print(st);
  }
}
