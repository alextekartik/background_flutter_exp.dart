import 'dart:convert';

import 'package:cv/cv.dart';
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

var generateIdFnName = 'generateId';
var projectId = 'tekartik-net-dev';

class GenerateIdResult extends CvModelBase {
  final id = CvField<String>('id');
  final timestamp = CvField<String>('timestamp');

  @override
  List<CvField> get fields => [id, timestamp];
}

/// Get id server generation à la firestore
///
/// Optional delay to let the server wait so simulate a long call.
Future<GenerateIdResult> callRestGenerateId({int? delayMs}) async {
  var uri = Uri.parse(
      'https://europe-west3-$projectId.cloudfunctions.net/$generateIdFnName');
  if (delayMs != null) {
    uri = uri.replace(queryParameters: {'delay': delayMs.toString()});
  }
  var client = httpClientFactory.newClient();
  var text = await httpClientRead(client, httpMethodGet, uri);
  var json = jsonDecode(text) as Map;
  var result = GenerateIdResult()..fromMap(json);
  print('generated: $result');
  return result;
}
