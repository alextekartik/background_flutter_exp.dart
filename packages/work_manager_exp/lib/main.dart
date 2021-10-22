import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:work_manager_exp/src/import.dart';
import 'package:work_manager_exp/src/tracker_bg_service_client.dart';
import 'package:work_manager_exp_common/tracker_db.dart';
import 'package:workmanager/workmanager.dart';

// Global client
var client = TrackerBgServiceClient();

const periodicTaskName = 'periodicTask';
const runOnceTaskName = 'runOnceTask';

extension _StringBuffer on StringBuffer {
  void add(Object text) {
    if (isNotEmpty) {
      write(', ');
    }
    write(text);
  }
}

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

  final groupExpandedMap = <int, bool>{};

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
            if (groupList.isEmpty) {
              return const ListTile(
                title: Center(child: Text('no data yet')),
              );
            }
            // devPrint('groups: ${groupList.length}');
            var groupIds = Set.from(groupList.map((group) => group.groupId));
            groupExpandedMap
                .removeWhere((key, value) => !groupIds.contains(key));
            return SingleChildScrollView(
              child: ExpansionPanelList(
                expansionCallback: (int index, bool isExpanded) {
                  setState(() {
                    groupExpandedMap[groupList[index].groupId] = !isExpanded;
                  });
                },
                children: groupList
                    .map((group) => ExpansionPanel(
                          headerBuilder: (context, isExpanded) {
                            var timestamp = group.items.first.anyTimestamp;
                            var startTimestamp = DateTime.tryParse(timestamp)!;
                            var lastTimestamp = DateTime.tryParse(
                                group.items.last.anyTimestamp)!;
                            var durationText = lastTimestamp
                                .difference(startTimestamp)
                                .toString();
                            var dotIndex = durationText.lastIndexOf('.');
                            if (dotIndex != -1) {
                              durationText =
                                  durationText.substring(0, dotIndex);
                            }

                            var localDateTime =
                                startTimestamp.toLocal().toIso8601String();
                            var dateTimeText = localDateTime
                                .substring(0, 19)
                                .replaceAll('T', ' ');

                            var subtitle =
                                'Duration $durationText (${group.items.length} actions)';
                            return ListTile(
                              leading: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    group.items.first.tag.v ?? 'back',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  // Text(item.first.groupId.v?.toString() ?? ''),
                                ],
                              ),
                              title: Text(dateTimeText),
                              subtitle: Text(subtitle),
                            );
                          },
                          body: Column(
                              children: group.items.map(
                            (item) {
                              String dateTimeText;
                              try {
                                dateTimeText = DateTime.parse(item.anyTimestamp)
                                    .toLocal()
                                    .toIso8601String()
                                    .substring(11, 19);
                              } catch (_) {
                                dateTimeText = '<none>';
                              }
                              var sb = StringBuffer();
                              sb.add(dateTimeText);

                              var title = sb.toString();
                              sb = StringBuffer();
                              sb
                                ..add('pid: ${item.processId.v}')
                                ..add('isolate: ${item.isolateName.v}');
                              var subtitle = sb.toString();
                              return ListTile(
                                dense: true,
                                leading: const SizedBox(
                                  width: 32,
                                ),
                                title: Text(title),
                                subtitle: Text(subtitle),
                              );
                            },
                          ).toList()),
                          isExpanded: groupExpandedMap[group.groupId] ??= false,
                        ))
                    .toList(),
              ),
            );
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: _workOnce,
        tooltip: 'Worn once',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
