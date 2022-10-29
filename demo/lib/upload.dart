import 'dart:async';

import 'package:demo/stream_subscription_controller.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter/cupertino.dart';

void _print(Object? object) {
  print(object);
}

class UploadController extends ChangeNotifier {
  final String endpoint;
  final String category;
  final PlatformFile file;
  final Map<String, dynamic> headers;
  UploadController({
    this.endpoint = 'https://xverse.storkparties.com/upload',
    this.headers = const {},
    this.category = 'test',
    required this.file,
  });

  /* Platform File */
  int get _fileSize => file.size;
  String get _fileName => file.name;

  /* Dio */
  static String _uploadID = '';
  String get uploadID => _uploadID;

  static String _uploadPath = '';
  String get uploadPath => _uploadPath;

  static CancelToken? _currentCancelToken;

  /* Data */
  static final ValueNotifier<bool> _isPendingRestart = ValueNotifier(false);
  ValueNotifier<bool> get pendingRestartNotifier => _isPendingRestart;

  static final ValueNotifier<bool> _isPaused = ValueNotifier(false);
  ValueNotifier<bool> get isManualPaused => _isPaused;

  /* Upload Progress */
  static int _totalChunkSent = 0;
  static double _uploadProgressNotifier = 0;
  double get uploadProgressNotifier => _uploadProgressNotifier;
  void _computeUploadProgress(int count, _) {
    _totalChunkSent += count;
    _uploadProgressNotifier = count / _fileSize;
    _setUploadTimeStamp();
    notifyListeners();
  }

  /* Upload time stamp */
  static List<int> _uploadTimeStamps = [];
  void _setUploadTimeStamp() {
    if (_uploadTimeStamps.length < 2) {
      _uploadTimeStamps.add(DateTime.now().millisecondsSinceEpoch);
    } else {
      _uploadTimeStamps.removeAt(0);
      _uploadTimeStamps.add(DateTime.now().millisecondsSinceEpoch);
    }
  }

  double get uploadSpeed {
    if (_uploadTimeStamps.length < 2) {
      return 0;
    }
    final int timeDifference = _uploadTimeStamps[1] - _uploadTimeStamps[0];
    final int sizeDifference = _fileSize - _totalChunkSent;
    return sizeDifference / timeDifference;
  }

  /* Chunk Progress */
  static int _rangeStart = 0;
  static Uint8List? _savedChunk;

  static double _streamProgressNotifier = 0;
  double get streamProgressNotifier => _streamProgressNotifier;
  void _computeStreamProgress(int sent) {
    _print('stream progress: $_rangeStart / $_fileSize');
    _streamProgressNotifier = sent / _fileSize;
    notifyListeners();
  }
  // Compute time it takes to upload a chunk and return a time estimation for completion.

  /* Stream */
  static StreamSubscription<Uint8List>? _streamSubscription;
  void _initStreamSubscription(void Function(Uint8List) onData) {
    if (file.readStream == null) {
      throw Exception('$_fileName File does not contains a stream.');
    }

    _streamSubscription = file.readStream!.listen(
      onData,
      onError: (Object error, StackTrace stackTrace) {
        print('Stream error $error');
      },
      cancelOnError: false,
      onDone: () {
        _print('Done');
      },
    );
  }

  void _cancelRequest() {
    if (_currentCancelToken == null) {
      throw Exception('Request not in progress');
    }

    _currentCancelToken?.cancel();
  }

  void start() async {
    // if (_paused || _offline || _stopped) return;
    if (_uploadID.isEmpty) {
      await _getUploadID();
    }

    _initStreamSubscription((Uint8List chunk) {
      _streamSubscription?.pause();

      _manageChunk(chunk).then(manageStream).catchError((error) {
        _print(error);
      });
    });
  }

  void pause() async {
    _streamSubscription?.pause();
    _isPaused.value = true;
  }

  void resume() async {
    _streamSubscription?.resume();
    _isPaused.value = false;
  }

  void abort() async {
    _cancelRequest();
  }

  void restart() {
    if (_streamSubscription == null) {
      throw Exception('Stream subscription is null');
    }

    if (_savedChunk == null) {
      // Invalidate the upload.
      throw Exception('There is no chunk to retrieve, aborting');
    }

    // Notify client we can restart.
    _isPendingRestart.value = false;

    _manageChunk(_savedChunk!).then(manageStream).catchError((error) {
      _print(error);
    });
  }

  Future<void> _getUploadID() async {
    final response = await _requestUploadID();

    if (response.statusCode == 200) {
      _uploadID = response.data['uploadId'];
      _uploadPath = response.data['fileName'];
    } else {
      throw Exception('Failed to get upload ID');
    }
  }

  Future<Response> _requestUploadID() {
    final Map<String, dynamic> postHeaders = {
      ...headers,
    };

    _setCancelToken();

    return Dio().post(
      endpoint,
      options: Options(
        headers: postHeaders,
        validateStatus: (status) {
          return status == 200;
        },
      ),
      data: {
        'category': category,
        'filename': _fileName,
        'filesize': _fileSize,
      },
      cancelToken: _currentCancelToken,
    );
  }

  void manageStream(bool success) {
    if (success) {
      _streamSubscription?.resume();
    } else {
      _isPendingRestart.value = true;
    }
  }

  Future<bool> _manageChunk(
    Uint8List chunk, [
    int attempt = 0,
  ]) async {
    final next = _rangeStart + chunk.length;
    _computeStreamProgress(next);

    try {
      await _sendChunk(
        chunk: chunk,
        rangeStart: _rangeStart,
        rangeEnd: _rangeStart + chunk.length - 1,
      );

      _rangeStart += chunk.length;
      return true;
    } catch (e) {
      _print(e);
      if (attempt < 3) {
        _print('$chunk, $start, ${attempt++}');
        return _manageChunk(chunk, attempt++);
      }

      _savedChunk = chunk;
      return false;
    }
  }

  Future<Response> _sendChunk({
    required Uint8List chunk,
    required int rangeStart,
    required int rangeEnd,
  }) {
    if (_uploadID.isEmpty) {
      throw Exception('Upload is empty');
    }

    final putHeaders = {
      'upload-id': _uploadID,
      Headers.contentLengthHeader: chunk.length,
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
      data: Stream.value(chunk),
      onReceiveProgress: _onReceiveProgress,
      onSendProgress: _computeUploadProgress,
      cancelToken: _currentCancelToken,
    );
  }

  void _setCancelToken() {
    try {
      _currentCancelToken = CancelToken();
    } catch (e) {
      _print(e);
      throw Exception('Cancel Token not assignable, aborting');
    }
  }

  bool _validateStatus(int? status) {
    if (status == null) {
      return false;
    }

    return status == 200;
  }

  // We recieve the signal that the stream is ready to continue.
  void _onReceiveProgress(int count, int total) {
    _print('onReceiveProgress: $count/$total');
  }
}
