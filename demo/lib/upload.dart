import 'dart:async';

import 'package:demo/stream_subscription_controller.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter/cupertino.dart';

void _print(Object? object) {
  print(object);
}

class UploadController {
  final String endpoint;
  final String category;
  final PlatformFile file;
  final Map<String, dynamic> headers;
  const UploadController({
    this.endpoint = 'https://xverse.storkparties.com/upload',
    this.headers = const {},
    this.category = 'test',
    required this.file,
  });

  /* Platform File */
  int get _fileSize => file.size;
  String get _fileName => file.name;
  Stream<Uint8List> get _stream => file.readStream!;

  /* Dio */
  static String _uploadID = '';
  String get uploadID => _uploadID;

  static String _uploadPath = '';
  String get uploadPath => _uploadPath;

  static CancelToken? _currentCancelToken;

  /* Data */
  static final ValueNotifier<bool> _isPendingRestart = ValueNotifier(false);
  ValueNotifier<bool> get isPendingRestart => _isPendingRestart;

  static final ValueNotifier<bool> _isPaused = ValueNotifier(false);
  ValueNotifier<bool> get isManualPaused => _isPaused;

  /* Upload Progress */
  static final ValueNotifier<double> _uploadProgressNotifier =
      ValueNotifier(0.0);
  ValueNotifier<double> get progressNotifier => _uploadProgressNotifier;

  /* Chunk Progress */
  static Uint8List? _savedChunk;
  int get _chunkCount => (_fileSize / 100 * 1024 * 1024).ceil();
  static final ValueNotifier<int> _streamProgressNotifier = ValueNotifier(0);
  ValueNotifier<int> get streamProgressNotifier => _streamProgressNotifier;
  // Compute time it takes to upload a chunk and return a time estimation for completion.

  void _cancelRequest() {
    if (_currentCancelToken == null) {
      throw Exception('Request not in progress');
    }

    _currentCancelToken?.cancel();
  }

  start() async {
    // if (_paused || _offline || _stopped) return;
    if (_uploadID.isEmpty) {
      _getUploadID();
    }

    StreamSubscription<Uint8List> subscription = _stream.listen(
      null,
      cancelOnError: false,
    );

    int rangeStart = 0;
    subscription.onData((chunk) async {
      // We pause the stream and decide what we should do.
      subscription.pause();

      // Compute the next chunk size. (sent + chunk.length - 1)
      await _manageChunk(
        chunk, // Uint8List
        rangeStart, // updated after a chunk has been fully sent
        rangeStart + chunk.length - 1, // Range end is computed here.
      ).then((success) {
        // on success
        if (success) {
          // we update the chunkID
          _streamProgressNotifier.value++;
          // we update the rangeStart so we can compute the end of the next chunk.
          rangeStart += chunk.length;

          // we resume stream.
          subscription.resume();
        } else {
          // on failure of retries.
          // we notify the client that it needs manual restart.
          _isPendingRestart.value = true;
          // when a restart is pending the ui must request a restart or a full shutdown.
          // we must expose a shutdown to the client so they can cancel the upload. (any time via the cancelToken).
          // when the client cancel the upload we must destroy the upload instance and display canceled to the user.
          // when the client dispose if the upload is canceled we must remove it from the list.

        }
      }).catchError((error) {
        return null;
      });
    });
    subscription.onError((e) {
      _print('Stream error: $e');
    });

    subscription.onDone(() {
      _print('Done');
    });
  }

  Future<bool> _manageChunk(Uint8List chunk, int start, int end,
      [int attempt = 0]) async {
    // if failed -> callManageUpload again until success or max attempts reached
    // if success continue with start()
    // * if offline -> throw catch -> catch -> retry < repeat until success or max attempts reached >
    // ? offline must notify the client that it is offline and that it will retry.

    // ! while not offline, not manually paused, not manually canceled we manage the chunk.

    try {
      final response = await _sendChunk(
        rangeStart: start,
        rangeEnd: end,
      );

      // look if we are on the last chunk and get the url after it resolved.

      return true;
    } catch (e) {
      print(e);
      // Update attempts
      if (attempt < 3) {
        return _manageChunk(chunk, start, end, attempt + 1);
      }

      _savedChunk = chunk;
      // Save the chunk that has failed.
      // do not close the stream.
      // If max attempts reached, return false
      return false;
    }
  }

  void _getUploadID() async {
    final Map<String, dynamic> postHeaders = {
      ...headers,
    };

    final response = await Dio().postUri(
      Uri.parse(endpoint),
      options: Options(
        headers: postHeaders,
        contentType: 'application/json',
      ),
      data: {
        'fileName': _fileName,
        'fileSize': _fileSize,
        'category': category,
      },
      cancelToken: _currentCancelToken,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get upload ID');
    }

    if (response.data == null) {
      throw Exception('_getUploadID: Response data is null');
    }

    if (response.data?['uploadID'] == null) {
      throw Exception('_getUploadID: Failed to get upload ID');
    }

    if (response.data?['fileName'] == null) {
      throw Exception('_getUploadID: Failed to get upload Path');
    }

    _uploadID = response.data?['uploadID'];
    _uploadPath = response.data?['fileName'];
  }

  Future<Response> _sendChunk({
    Uint8List? chunk,
    required int rangeStart,
    required int rangeEnd,
  }) async {
    if (_uploadID.isEmpty) {
      throw Exception('Upload ID not set');
    }

    final putHeaders = {
      'upload-id': _uploadID,
      Headers.contentLengthHeader: chunkStream.length,
      'content-type': 'application/octet-stream',
      'content-range': 'bytes $rangeStart-$rangeEnd/$_fileSize',
      ...headers,
    };

    // We need a cancel token for each request.
    _setCancelToken();

    // Debug
    _print(putHeaders.toString());

    return Dio().putUri(
      Uri.parse(endpoint),
      options: Options(
        headers: putHeaders,
        followRedirects: false,
        validateStatus: _validateStatus,
      ),
      data: Stream.value(_getValidatedChunk),
      onReceiveProgress: _onReceiveProgress,
      onSendProgress: _onSendProgress,
      cancelToken: _currentCancelToken,
    );
  }

  Uint8List _getValidatedChunk(Uint8List? currChunk) {
    if (currChunk != null) {
      return currChunk;
    }

    if (_savedChunk != null) {
      return _savedChunk!;
    }

    // Invalidate the upload.
    throw Exception('There is no chunk to send --aborting');
  }

  void _setCancelToken() {
    _currentCancelToken = CancelToken();
  }

  bool _validateStatus(int? status) {
    if (status == null) {
      return false;
    }

    return status == 200;
  }

  void _onReceiveProgress(int count, int total) {
    _print('onReceiveProgress: $count/$total');
  }

  void _onSendProgress(int count, int total) {
    _print('onSendProgress: $count/$total');
  }
}
