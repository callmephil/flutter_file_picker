// Helpers
import 'dart:async';

// utils: Debugging only
void _print(Object? object) {
  print(object);
}

typedef OnSuccess = void Function();
// ! Should return a resolvable Future + Predicted
/// You must call streamControl.pause() if you want to wait another function.
typedef OnProgress = void Function(
    List<int> data, double? progress, int? chunkNumber, int? accumulated);

/// Unimplemented
typedef OnAttempt = void Function(int chunkNumber, int chunkSize);

/// Unimplemented
typedef OnAttemptFailure = void Function(
    String message, int chunkNumber, int attempsLeft);

/// Unimplemented
typedef OnCanceled = void Function();

/// Unimplemented
typedef OnPaused = void Function();

/// Unimplemented
typedef OnResumed = void Function();

extension Computable on double {
  double toPercent() => this * 100;
}

class Controls {
  ///
  final OnSuccess? onSuccess;

  ///
  final OnProgress? onProgress;

  ///
  final OnAttempt? onAttempt;

  ///
  final OnAttemptFailure? onAttemptFailure;

  Controls({
    this.onSuccess,
    this.onProgress,
    this.onAttempt,
    this.onAttemptFailure,
  });
}

class StreamControl {
  ///
  final Stream<List<int>> stream;

  ///
  final int fileSize;

  ///
  final int chunkSize;

  final StreamSubscription<List<int>> _subscription;
  StreamControl(
    this.stream, {
    required this.fileSize,
    required this.chunkSize,
  }) : _subscription = stream.asBroadcastStream().listen(
              (_) {},
              cancelOnError: false,
            );

  bool get isPaused => _subscription.isPaused;

  // utils.
  void _pause() => _subscription.pause();
  void _cancel() => _subscription.cancel();
  // ! This should be private and be executed after each onProgress..Predicted Event
  void resume() => _subscription.resume();

  int get _totalChunk => (fileSize / chunkSize).ceil();
  double get _progress => (_totalBytesSent / fileSize).toPercent();

  int _currentChunk = 0;
  int _totalBytesSent = 0;

  void readStream(
    Controls controls, {
    int startChunk = 0,
  }) {
    _subscription.onData((data) async {
      _currentChunk++;
      _totalBytesSent += data.length;
      if (_currentChunk < startChunk) {
        _print('skipped chunk $_currentChunk');
        return;
      }

      _print('Chunk $_currentChunk of $_totalChunk');

      _pause();
      if (controls.onProgress != null) {
        controls.onProgress!(data, _progress, _currentChunk, _totalBytesSent);
      }
    });

    _subscription.onError((e) {
      _print('onError $e');
    });

    if (controls.onSuccess != null) {
      _subscription.onDone(() {
        controls.onSuccess?.call();
      });
    }
  }
}
