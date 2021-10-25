import 'package:process_run/shell.dart';
import 'package:tekartik_android_utils/adb_log.dart';

var packageName = 'com.tekartik.bg_service_exp';

Future main() async {
  var env = ShellEnvironment()
    ..vars['ANDROID_LOG_TAGS'] =
        'AlarmManagerService:S PowerManagerService:S skia:S eglCodecCommon:S EGL_emulation:S *:V';
  shellEnvironment = env;
  await adbLog(AdbLogOptions(package: packageName, serial: 'any'));
}
