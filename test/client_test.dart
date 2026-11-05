// The network wrapper against a local server: a block in front of the API
// is temporary, Paystrater's own 403 is a set-up problem.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paystrater_flutter/src/client.dart';

void main() {
  late HttpServer server;
  late PaystraterClient client;
  var body = '';

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      request.response
        ..statusCode = 403
        ..write(body);
      await request.response.close();
    });
    client = PaystraterClient(
        publishableKey: 'pk_test_x',
        apiBase: Uri.parse('http://127.0.0.1:${server.port}'));
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test('treats a 403 with no Paystrater error body as temporary', () async {
    body = '<html>Forbidden</html>';
    final res = await client.startTransferToPay({'chainId': 8453});
    expect(res.error?.kind, ErrorKind.network);
    expect(res.error?.status, 403);
  });

  test("keeps Paystrater's own 403 as the set-up problem it is", () async {
    body = jsonEncode({
      'isError': true,
      'error': {'message': 'Invalid API key provided', 'status': 403}
    });
    final res = await client.startTransferToPay({'chainId': 8453});
    expect(res.error?.kind, ErrorKind.api);
    expect(res.error?.message, 'Invalid API key provided');
  });
}
