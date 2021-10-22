import 'package:flutter_test/flutter_test.dart';
import 'package:work_manager_exp_common/generate_id_rest_client.dart';

void main() {
  test('generate_id', () async {
    var result = await callRestGenerateId();
    expect(result.id.v, isNotNull);
    expect(result.timestamp.v, isNotNull);
  });
}
