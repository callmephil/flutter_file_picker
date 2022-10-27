import 'package:demo/stream_subscription_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

void _print(Object? object) {
  print(object);
}

class Upload {
  final String endpoint;
  final Uint8List chunk;
  final int fileSize;
  Upload({
    this.endpoint = 'https://xverse.storkparties.com/upload',
    required this.chunk,
    required this.fileSize,
  });

  // Has to store internally
  // UploadID
  String _uploadID = '';
  // Attempts

  // Has to listen for connection changes

  // Has to expose cancelToken
  // Has to expose onProgress as a stream
  final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);
  ValueNotifier<double> get progressNotifier => _progressNotifier;

  // Has to return done(url) or error

  int get _chunkSize => chunk.length;

  Future<Response> _initialiseUploadRequest({
    required String fileName,
    required int fileSize,
  }) async {
    Map<String, dynamic> body = {
      'fileName': fileName,
      'fileSize': fileSize,
      'category': 'test',
    };

    return await Dio().postUri(
      Uri.parse(endpoint),
      data: body,
    );
  }

  Future<Response> _sendChunk({
    required int rangeStart,
    required int rangeEnd,
    required String uploadID,
  }) async {
    _print('bytes $rangeStart-$rangeEnd/$fileSize');
    var headers = {
      Headers.contentLengthHeader: _chunkSize,
      'content-type': 'application/octet-stream',
      'upload-id': uploadID,
      'content-range': 'bytes $rangeStart-$rangeEnd/$fileSize',
      // 'Authorization': 'Bearer ${store.auth.token}',
      // 'Access-Control-Allow-Origin': '*',
    };

    _print(headers.toString());

    return Dio().putUri(
      Uri.parse(endpoint),
      options: Options(
        headers: headers,
        followRedirects: false,
        validateStatus: (status) {
          _print('RequestStatus: $status');
          return status == 200;
        },
      ),
      data: Stream.value(chunk),
      onReceiveProgress: (count, total) => _print(
        'onReceiveProgress: $count/$total',
      ),
      onSendProgress: (count, total) => _print(
        'onSendProgress: $count/$total',
      ),
    );
  }
}
