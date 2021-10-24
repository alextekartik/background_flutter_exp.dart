import 'package:tekartik_test_menu_flutter/test_menu_flutter.dart';
import 'package:work_manager_exp3/main.dart';
import 'package:work_manager_exp3/src/client.dart';
import 'package:work_manager_exp3/src/ui.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  mainMenu(() {
    enter(() async {
      service = await getTrackerService();
    });
    //devPrint('MAIN_');
    item('workOnce', () async {
      await service.workOnce();
    });
    item('itemsUpdated', () async {});
    item('listItems', () async {
      var items = (await service.getListItems()).items;
      for (var item in items) {
        write(
            '${item.id.v} ${item.groupId.v} ${item.genId} ${item.timestamp.v}');
      }
    });
    item('initializeWorkmanager', () {
      initializeWorkmanager();
    });
    item('run now', () {
      Workmanager().registerOneOffTask(
        '2',
        periodicTaskName,
      );
    });
    item('run in 15 seconds', () {
      Workmanager().registerOneOffTask(
        '3',
        periodicTaskName,
        initialDelay: const Duration(seconds: 15),
      );
    });
    item('run in 30 seconds', () {
      Workmanager().registerOneOffTask(
        '4',
        periodicTaskName,
        initialDelay: const Duration(seconds: 30),
      );
    });
  }, showConsole: true);
}
