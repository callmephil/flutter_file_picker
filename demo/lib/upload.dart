import 'package:demo/stream_subscription_controller.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter/cupertino.dart';

void _print(Object? object) {
  print(object);
}

class FileUpload {
  final String endpoint;
  final String category;
  final PlatformFile file;
  final Map<String, dynamic> headers;
  const FileUpload({
    this.endpoint = 'https://xverse.storkparties.com/upload',
    this.headers = const {},
    this.category = 'test',
    required this.file,
  });

  // Has to store internally
  // UploadID
  static String _uploadID = '';
  static String _uploadPath = '';
  static Uint8List? _currentChunk;
  static CancelToken? _currentCancelToken;
  // Attempts

  // Has to listen for connection changes

  // Has to expose onProgress as a stream
  static final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);
  ValueNotifier<double> get progressNotifier => _progressNotifier;
  // Compute time it takes to upload a chunk and return a time estimation for completion.

  // Has to return done(url) or error

  int? get _chunkSize => _currentChunk?.length;
  int get _fileSize => file.size;
  String get _fileName => file.name;
  Stream<Uint8List> get _stream => file.readStream!;
  String get uploadPath => _uploadPath;

  void cancelRequest() {
    if (_currentCancelToken == null) {
      throw Exception('Request not in progress');
    }

    _currentCancelToken?.cancel();
  }

  start() async {
    // if (_paused || _offline || _stopped) return;
    _currentCancelToken = CancelToken();
    if (_uploadID.isEmpty) {
      _getUploadID();
    }

    int rangeStart = 0;
    await for (Uint8List chunk in _stream) {
      // Save current chunk in case of pause, failure.
      _currentChunk = chunk;
      // Compute the next chunk size. (sent + chunk.length - 1)
      int rangeEnd = rangeStart + chunk.length - 1;

      // if paused - Wait before sending the next chunk.
      // if offline - Wait and resolve before sending the next chunk.
      // if offline for too long exit
      // if stopped - exit
      // if error -

      // while not offline, stopped, paused

      _manageChunk(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        chunk: chunk,
      );

      _sendChunk(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ).then((res) {
        return null;
      }, onError: (err) {
        // if (_paused || _offline || _stopped) return;
        _print(err);
      });
      // Compute how many bytes has been sent after an upload is successfull.
      rangeStart += chunk.length;
    }
  }

  Future<bool> _manageChunk(Uint8List chunk, int start, int end,
      [int attempt = 0]) async {
    // if failed -> callManageUpload again until success or max attempts reached
    // if success continue with start()
    try {
      final response = await _sendChunk(
        rangeStart: start,
        rangeEnd: end,
      );

      return true;
    } catch (e) {
      print(e);
      // Update attempts
      if (attempt < 3) {
        return _manageChunk(chunk, start, end, attempt + 1);
      }
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
    required int rangeStart,
    required int rangeEnd,
  }) async {
    if (_uploadID.isEmpty) {
      throw Exception('Upload ID not set');
    }

    late final Stream<Uint8List> chunkStream;
    if (_currentChunk == null) {
      throw Exception('No chunk to send');
    } else {
      chunkStream = Stream<Uint8List>.value(_currentChunk!);
    }

    final putHeaders = {
      'upload-id': _uploadID,
      Headers.contentLengthHeader: _chunkSize,
      'content-type': 'application/octet-stream',
      'content-range': 'bytes $rangeStart-$rangeEnd/$_fileSize',
      ...headers,
    };

    // Debug
    _print(putHeaders.toString());

    return Dio().putUri(
      Uri.parse(endpoint),
      options: Options(
        headers: putHeaders,
        followRedirects: false,
        validateStatus: (status) {
          _print('RequestStatus: $status');
          return status == 200;
        },
      ),
      data: chunkStream,
      // Once the server responds with a 200, the upload is complete
      // this is used to know how many chunk has been sent successfully
      onReceiveProgress: (count, total) => _print(
        'onReceiveProgress: $count/$total',
      ),
      // Current length being sent to the server
      // this is used to calculate the indicator progress
      onSendProgress: (count, total) {
        progressNotifier.value = count / total;
        _print(
          'onSendProgress: $count/$total',
        );
      },
      cancelToken: _currentCancelToken,
    );
  }
}
