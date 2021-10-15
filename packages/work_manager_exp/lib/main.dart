import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:work_manager_exp/src/import.dart';
import 'package:work_manager_exp/src/tracker_bg_model.dart';
import 'package:work_manager_exp/src/tracker_bg_service_client.dart';
import 'package:workmanager/workmanager.dart';

// Global client
var client = TrackerBgServiceClient();

const periodicTaskName = 'periodicTask';
const runOnceTaskName = 'runOnceTask';

Future<void> serviceRun(String tag) async {
  var client = TrackerBgServiceClient();
  print('Workmanager starting serviceRun');
  await client.ping('test1');
  await client.workOnce(tag);
  await client.ping('test2');
  print('Workmanager ending serviceRun');
}

void callbackDispatcher() {
  print('Workmanager callbackDispatcher()');
  Workmanager().executeTask((task, inputData) async {
    print('Workmanager task $task');
    switch (task) {
      case Workmanager.iOSBackgroundTask:
        stderr.writeln('The iOS background fetch was triggered');
        await serviceRun('ios');
        break;
      case periodicTaskName:
        stderr.writeln('The Android periodic triggered');
        await serviceRun('back');
        break;
      case runOnceTaskName:
        stderr.writeln('The Android manually triggered');
        await serviceRun('trig');
        break;
    }
    var success = true;
    return Future.value(success);
  });
}

void initializeWorkmanager() {
  Workmanager().initialize(
      callbackDispatcher, // The top level function, aka callbackDispatcher
      isInDebugMode:
          isDebug // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
      );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
  }
  initTrackerBuilders();
  initializeWorkmanager();
  // Periodic task registration, android only
  if (Platform.isAndroid) {
    try {
      await Workmanager().registerPeriodicTask(
        '100',
        periodicTaskName,
      );
    } catch (e) {
      print('Error #e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.dark(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          //prim: Colors.blue,
          ),
      home: const TrackItemListPage(),
    );
  }
}

class TrackItemListPage extends StatefulWidget {
  const TrackItemListPage({Key? key}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are

  @override
  State<TrackItemListPage> createState() => _TrackItemListPageState();
}

enum MenuAction {
  clear,
  runNow,
  runIn15s,
  runIn30s,
}

class _TrackItemListPageState extends State<TrackItemListPage> {
  final _itemList = BehaviorSubject<ItemListResponse>();

  @override
  void dispose() {
    _itemList.close();
    super.dispose();
  }

  @override
  void initState() {
    sleep(0).then((_) async {
      while (mounted) {
        try {
          var items = await client.listItems();
          //devPrint(items);
          if (!mounted) {
            return;
          }
          _itemList.add(items);
          // ignore: unused_local_variable
          var result = await client.itemsUpdated(items.lastChangeId.v!);
        } catch (e) {
          print(e);
        }
      }
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _workOnce() {
    client.workOnce('front');
  }

  void snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _triggerIn(BuildContext context, int seconds) async {
    await Workmanager().registerOneOffTask(
      seconds.toString(),
      runOnceTaskName,
      initialDelay: Duration(seconds: seconds),
    );
    snack(context, 'Triggered in $seconds seconds');
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: const Text('Track items'),
        actions: [
          PopupMenuButton<MenuAction>(
            itemBuilder: (context) => [
              PopupMenuItem<MenuAction>(
                  value: MenuAction.clear,
                  child: const Text('Clear'),
                  onTap: () {
                    client.clearItems();
                  }),
              if (Platform.isAndroid) ...[
                PopupMenuItem<MenuAction>(
                  value: MenuAction.runNow,
                  child: const Text('Trigger now'),
                  onTap: () {
                    _triggerIn(context, 0);
                  },
                ),
                PopupMenuItem<MenuAction>(
                  value: MenuAction.runIn15s,
                  child: const Text('Trigger in 15s'),
                  onTap: () {
                    _triggerIn(context, 15);
                  },
                ),
                PopupMenuItem<MenuAction>(
                    value: MenuAction.runIn30s,
                    onTap: () {
                      _triggerIn(context, 30);
                    },
                    child: const Text('Trigger in 30s')),
              ]
            ],
          ),
        ],
      ),
      body: StreamBuilder<ItemListResponse>(
          stream: _itemList,
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            var groupList = snapshot.data!.groups.reversed.toList();
            return ListView.builder(
                itemCount: groupList.isEmpty ? 1 : groupList.length,
                itemBuilder: (context, index) {
                  if (groupList.isEmpty) {
                    return const ListTile(
                      title: Center(child: Text('no group data')),
                    );
                  }
                  var item = groupList[index];
                  var timestamp = item.first.timestamp.v!;

                  var startTimestamp = DateTime.tryParse(timestamp)!;
                  var lastTimestamp =
                      DateTime.tryParse(item.last.timestamp.v!)!;
                  var durationText =
                      lastTimestamp.difference(startTimestamp).toString();
                  var dotIndex = durationText.lastIndexOf('.');
                  if (dotIndex != -1) {
                    durationText = durationText.substring(0, dotIndex);
                  }
                  var subtitle =
                      '${item.length} ${item.first.groupId.v} $durationText';
                  return ListTile(
                    leading: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.first.tag.v ?? 'back'),
                        Text(item.first.groupId.v?.toString() ?? ''),
                      ],
                    ),
                    title: Text(timestamp),
                    subtitle: Text(subtitle),
                  );
                });
            /*
            var list = snapshot.data!.items;

            return ListView.builder(
                itemCount: list.isEmpty ? 1 : list.length,
                itemBuilder: (context, index) {
                  if (list.isEmpty) {
                    return const ListTile(
                      title: Center(child: Text('no data')),
                    );
                  }
                  var item = list[index];
                  return ListTile(title: Text(item.timestamp.v!));
                });*/
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: _workOnce,
        tooltip: 'Worn once',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
