import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;
  final List<RequestOptions> requests = [];

  int requestsTo(String host) =>
      requests.where((r) => r.uri.host == host).length;

  int requestsOtherThan(String host) =>
      requests.where((r) => r.uri.host != host).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, [int status = 200]) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
