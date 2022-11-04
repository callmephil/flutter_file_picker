import 'dart:async';

import 'package:demo/stream_subscription_controller.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter/cupertino.dart';

void _print(Object? object) {
  print(object);
}

enum UploadStatus {
  notStarted,
  active,
  paused,
  completed,
  canceled,
  failed,
}

const _maxAttempt = 3;

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

  /* Statuses */
  UploadStatus _status = UploadStatus.notStarted;
  UploadStatus get status => _status;
  void _setStatus(UploadStatus status) {
    _status = status;
    notifyListeners();
  }

  /* Upload Progress */
  static int _totalChunkSent = 0;
  static double _uploadProgress = 0;
  double get uploadProgress => _uploadProgress;
  void _computeUploadProgress(int count, _) {
    _totalChunkSent += count;
    _uploadProgress = count / _fileSize;
    _setUploadTimeStamp();
    notifyListeners();
  }

  // We recieve the signal that the stream is ready to continue.
  void _onReceiveProgress(int count, int total) {
    _print('onReceiveProgress: $count/$total');
  }

  /* Upload time stamp */
  static final List<int> _uploadTimeStamps = [];
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

  static double _streamProgress = 0;
  double get streamProgress => _streamProgress;
  void _computeStreamProgress(int read) {
    _print('stream progress: $_rangeStart / $_fileSize');
    _streamProgress = read / _fileSize;
    notifyListeners();
  }
  // Compute time it takes to upload a chunk and return a time estimation for completion.

  /* Stream */
  static StreamSubscription<Uint8List>? _streamSubscription;
  void _initStreamSubscription(void Function(Uint8List) onData) {
    if (file.readStream == null) {
      // throw Exception('$_fileName File does not contains a stream.');
    }

    _streamSubscription = file.readStream!.listen(
      onData,
      onError: (Object error, StackTrace stackTrace) {
        // print('Stream error $error');
      },
      cancelOnError: false,
      onDone: () {
        _print('Done');
      },
    );
  }

  void _cancelActiveRequest() {
    if (_currentCancelToken == null) {
      print('No active request to cancel.');
      // throw Exception('Request not in progress');
    }

    _currentCancelToken?.cancel();
  }

  void start() async {
    // if (_paused || _offline || _stopped) return;
    if (_status == UploadStatus.canceled) return;

    if (_uploadID.isEmpty) {
      await _getUploadID();
    }

    _setStatus(UploadStatus.active);

    _initStreamSubscription((Uint8List chunk) {
      _streamSubscription?.pause();

      _manageChunk(chunk).then(manageStream).catchError((error) {
        _print(error);
      });
    });
  }

  void pause() async {
    // if (_status != UploadStatus.active) return;

    if (!_streamSubscription!.isPaused) {
      _streamSubscription?.pause();
    }

    if (status != UploadStatus.paused) {
      _setStatus(UploadStatus.paused);
      // TODO: determine if we should cancel the request or continue it for data consumption.
      _cancelActiveRequest();
    }
  }

  // Check if it's manually paused or not.
  void resume() async {
    _streamSubscription?.resume();
    _setStatus(UploadStatus.active);
  }

  void abort({bool failed = false}) {
    try {
      if (failed) {
        // When failed we can still retry.
        _setStatus(UploadStatus.failed);
      } else {
        _streamSubscription?.cancel();
        _currentCancelToken!.cancel(Exception('Upload cancelled by the user'));
        _setStatus(UploadStatus.canceled);
        _clear();
      }
      notifyListeners();
    } catch (e) {
      print('canceled');
    }
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  void _clear() {
    _streamSubscription = null;
    _currentCancelToken = null;
    _uploadProgress = 0;
    _streamProgress = 0;
    _totalChunkSent = 0;
    _rangeStart = 0;
    _uploadID = '';
    _uploadPath = '';
    _uploadTimeStamps.clear();
    _savedChunk = null;
    notifyListeners();
  }

  void restart() {
    if (_streamSubscription == null) {
      print('Stream is null');
      return;
      // throw Exception('Stream subscription is null');
    }

    if (_savedChunk == null) {
      print('No saved chunk');
      return;
      // Invalidate the upload.
      // throw Exception('There is no chunk to retrieve, aborting');
    }

    // Notify client we can restart.
    // _isPendingRestart.value = false;
    _setStatus(UploadStatus.active);

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
      // throw Exception('Failed to get upload ID');
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
      // _isPendingRestart.value = true;
    }
  }

  Future<bool> _manageChunk(
    Uint8List chunk, [
    int attempt = 0,
  ]) async {
    if (status == UploadStatus.canceled) {
      return false;
    }

    final next = _rangeStart + chunk.length;
    _computeStreamProgress(next);

    try {
      final response = await _sendChunk(
        chunk: chunk,
        rangeStart: _rangeStart,
        rangeEnd: _rangeStart + chunk.length - 1,
      );

      if (response.statusCode != 200) {
        if (status == UploadStatus.failed) {
          return false;
        }

        if (attempt < _maxAttempt) {
          _print('Failed to send chunk, retrying...');

          return Future.delayed(
            const Duration(seconds: 1),
            () => _manageChunk(chunk, attempt),
          );
        } else if (status != UploadStatus.active) {
          return false;
        }
      }

      _rangeStart += chunk.length;
      return true;
    } on DioError catch (e) {
      switch (e.type) {
        case DioErrorType.cancel:
          if (status == UploadStatus.paused) {
            if (status != UploadStatus.failed) {
              _savedChunk = chunk;
            }
            return false;
          }
          break;
        case DioErrorType.sendTimeout:
          _print('SendTime, retrying...');
          break;

        case DioErrorType.receiveTimeout:
          _print('Timeout, retrying...');
          break;

        case DioErrorType.connectTimeout:
          _print('Connection timeout');
          break;
        case DioErrorType.other:
          _print('Other error');
          break;
        // default:
        case DioErrorType.response:
          _print('response error');
          // TODO: Handle this case.
          break;
      }
      print('ManageChunk Exception $e');
      abort(failed: true);
      return false;
    }
  }

  Future<Response> _sendChunk({
    required Uint8List chunk,
    required int rangeStart,
    required int rangeEnd,
  }) {
    if (_uploadID.isEmpty) {
      // throw Exception('Upload is empty');
    }

    final putHeaders = {
      'upload-id': _uploadID,
      Headers.contentLengthHeader: chunk.length,
      'content-type': 'application/octet-stream',
      'content-range': 'bytes $rangeStart-$rangeEnd/$_fileSize',
      ...headers,
    };

    // We need a cancel token for each new request.
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
    _currentCancelToken = CancelToken();
  }

  bool _validateStatus(int? status) {
    if (status == null) {
      return false;
    }

    print('request status: $status');

    return status == 200;
  }
}
