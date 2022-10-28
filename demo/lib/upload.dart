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

  // Has to store internally
  // UploadID
  static String _uploadID = '';
  static String _uploadPath = '';
  static bool _isPendingRestart = false;
  static int _currentChunkID = 0;
  static CancelToken? _currentCancelToken;
  // Attempts

  // Has to listen for connection changes

  // Has to expose onProgress as a stream
  static final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);
  ValueNotifier<double> get progressNotifier => _progressNotifier;
  // Compute time it takes to upload a chunk and return a time estimation for completion.

  // Has to return done(url) or error

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

    StreamSubscription<Uint8List> subscription = _stream.listen(
      null,
      cancelOnError: false,
    );

    int rangeStart = 0;
    subscription.onData((chunk) async {
      // We pause the stream and decide what we should do.
      subscription.pause();

      /* Lifecycle */
      // ? if client is disposed (page change, picking different file). cancel the request and destroy the instance.
      // ? We should not cancel upload if the client is not active. (switching app, tabs)
      // ! Must implement .dispose() method.

      /* PRE UPLOAD PROCCESS (INIT) */
      // * Get the upload id.
      // ! Must implement .getUploadID() method.
      // ? if it fail. attempt retry,
      // ? if it fails again, notify the client for manual init restart.
      // ! Must implement .restart() method.
      // ? if it succeeds, initalise _streamSubscription and continue.
      // ! Must initialise a new cancelation token for every requests.

      /* START UPLOAD PROCCESS */
      // * Listen to _streamSubscription
      // * Notify the client that we are starting the upload.
      // * Pause the stream
      // ? if the stream fail, we must cancel the process and notify the client for re-picking.
      // * Manage the chunk.

      // Should be called manageResponse*
      /* MANAGE CHUNK PROCCESS */
      // * listen for connection changes.
      // ! Must implement ConnectionStatusSingleton
      // ? if the connection is offline, retry _manageChunk() after 5 seconds.
      // ? if failure -> notify client with _isPendingRestart = true (the stream is already paused).
      // ! Note: We should not pause the stream a second time. if we do so, we will need to resume it a second time.
      // ! Must implement .resume() method.
      // * Send the chunk to the server and wait for response.
      // ! Must implement .sendChunk() method.
      // ? if errors occurs retry to send the chunk.
      // ? if errors occurs again, notify the client for manual restart.
      // ? if success. update chunkID & startingRange and resume the stream.

      /* SEND CHUNK PROCESS */
      // * initialise dio PUT request.
      // * send the chunk as a stream.
      // * manage progress.
      // ? We have 2 type of progress.
      // ? 1. Chunk progress (the upload progress of the current chunk).
      // ! Must implement .manageUploadProgress() Method.
      // ? 2. Stream progress (the upload progress of the whole stream).
      // ! Must implement .manageStreamProgress() Method.
      // * manage the cancelation token.
      // ! Must initialise a new cancelation token for every requests.
      // ? If cancel is called, cancel the request and notify the client for manual restart.
      // ? If the client destroy the u.i manually dispose. (ex: delete the file, change page, etc.)
      // * Manage response.
      // ? We must ensure the function is

      /* MANUAL RESUME PROCCESS */
      // ? we must expose a manual resume method.
      // ? we must expose a resume listener. variable isManualResumed.
      // ? We must set _isManualPaused = false
      // * if we resume and we have canceled the request
      // * if the chunk has finished then we should resume the listener
      // * otherwise we must restart the upload from the last chunk before running the stream.

      /* MANUAL PAUSE PROCCESS */
      // ! Must implement .pause() method.
      // ? we must expose a pause listener. variable isManualPaused.
      // ? we need to decide if we should cancel the upload or wait till he has finished the chunk.
      // ! note: the above can be avoided if we have smaller chunks. ~ 5 - 10mb. for carrier data.
      // ? On manual pause we set _isManualPaused = true, and we pause the stream.

      /* RESTART PROCCESS */
      // * if isPendingRestart -> must call _manualRestart -> manageChunk -> resume on success. <|> do nothing on failure.
      // ? When manual restart we send a single manageChunk and if success we resume the stream.
      // ? We repeat the whole process again until done or cancel or destroy.

      /* CANCEL PROCCESS */
      // ? we must expose a manual cancel method.
      // ? On cancel we call cancelToken & subscription.cancel() and notify the client that the upload has been canceled.

      /* PENDING RESTART PROCCESS */
      // ! Must implement .restart() method.
      // ? if the client restart the process. we must know if upload id is available or not.
      // ? if upload id is available, we call the .resume() method
      // * Store the chunk in the instance so we can resume it later.
      // ? if cancel -> notify client with _isCanceled -> clear the instance. (destroy on u.i change).

      // ------------------------------------------
      // if offline - Wait and resolve before sending the next chunk.
      // if offline for too long exit
      // if stopped - exit
      // if error - check for manual restart or exit
      // for manual restart we need to expose the function to the u.i
      // for exit we need to expose the function to the u.i
      // upload 5 chunks > sneding chunks 1 2 3 <> offline <attempt 1 2 3>
      // <App is closed> destroy instance < or >
      // pending manual restart > manual restart. > sending chunk 3 <<<

      // Compute the next chunk size. (sent + chunk.length - 1)
      await _manageChunk(
        chunk, // Uint8List
        rangeStart, // updated after a chunk has been fully sent
        rangeStart + chunk.length - 1, // Range end is computed here.
      ).then((success) {
        // on success
        if (success) {
          // we update the chunkID
          _currentChunkID++;
          // we update the rangeStart so we can compute the end of the next chunk.
          rangeStart += chunk.length;

          // we resume stream.
          subscription.resume();
        } else {
          // on failure of retries.
          // we notify the client that it needs manual restart.
          _isPendingRestart = true;
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
    if (_currentChunkID == null) {
      throw Exception('No chunk to send');
    } else {
      chunkStream = Stream<Uint8List>.value(_currentChunkID!);
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
