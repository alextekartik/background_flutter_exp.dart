import 'package:dev_test/package.dart';
import 'package:path/path.dart';

Future main() async {
  for (var dir in [
    'app_mutex',
    // 'work_manager_exp',
  ]) {
    await packageRunCi(join('..', 'packages', dir));
  }
  await packageRunCi('.');
}
