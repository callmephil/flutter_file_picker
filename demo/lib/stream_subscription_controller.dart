import 'dart:async' show StreamSubscription;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/cupertino.dart';
export 'dart:typed_data' show Uint8List;

///
enum StatusType {
  onStart,
  onPause,
  onResume,
  onCancel,
  onError,
  onDone,
}

/// Might be useful to not use int as reference to the size and limit it to max 1GB.
/// https://suragch.medium.com/working-with-bytes-in-dart-6ece83455721
typedef BufferSize = int;
const BufferSize kb = 1024;
const BufferSize mb = kb * kb;
const BufferSize gb = mb * mb;
const BufferSize kMaxBufferSize = 100 * mb;

///
typedef IntCallback = void Function(int value);

typedef FutureVoidCallback = Future<void> Function();

///
typedef FutureIntCallback = Future<void> Function(int value);

///
typedef FutureUint8ListCallback = Future<void> Function(Uint8List value);

///
typedef StatusCallback = void Function(StatusType);

///
typedef Uint8ListStream = Stream<Uint8List>;

// TODO: ERROR MANAGEMENT
class StreamSubscriptionController {
  final Uint8ListStream stream;
  final StatusCallback? onStatusChanged;
  final FutureUint8ListCallback onProgress;
  final FutureVoidCallback? onStart;
  final FutureVoidCallback? onPause;
  final FutureVoidCallback? onCancel;
  final int? size;
  const StreamSubscriptionController(
    this.stream, {
    this.size = 0,
    this.onStatusChanged,
    this.onStart,
    this.onPause,
    this.onCancel,
    required this.onProgress,
  });

  static bool _isDone = false;
  static bool _isStarted = false;
  static bool _isCanceled = false;
  static bool _isManualPause = false;
  static int _currentChunk = 0;
  static int _currentLength = 0;

  static StreamSubscription<Uint8List>? _subscription;
  bool get isStarted => _isStarted;
  bool get isPaused => _isManualPause;
  bool get isCanceled => _isCanceled;
  bool get isDone => _isDone;
  bool get isActive => !isStarted && !isCanceled && !isDone;

  int get dataSent => _currentLength;
  int get currentChunk => _currentChunk;
  int get chunkLength => size! ~/ kMaxBufferSize;
  ValueNotifier<double> get progress => ValueNotifier(
        _currentLength / size!,
      );

  void start() async {
    if (!isActive) {
      return;
    }

    if (onStart != null) {
      await onStart?.call();
    }
    _subscription = stream.listen(null, cancelOnError: true);

    onStatusChanged?.call(StatusType.onStart);
    _isStarted = true;

    _subscription?.onData((data) async {
      _currentChunk++;
      _currentLength += data.length;
      _subscription?.pause(onProgress.call(
        data,
      ));
    });

    _subscription?.onDone(() {
      _isDone = true;
      onStatusChanged?.call(StatusType.onDone);
    });

    _subscription?.onError((e) {
      print('Stream Error: $e');
      onStatusChanged?.call(StatusType.onError);
    });
  }

  void pause() {
    _subscription?.pause();
    _isManualPause = true;
    onStatusChanged?.call(StatusType.onPause);
  }

  void resume() {
    if (_isManualPause) {
      _isManualPause = false;
      _subscription?.resume();
    }
    // When manually paused, we must resume it twice.
    // It is safe to resume, even if it is not paused
    _subscription?.resume();

    onStatusChanged?.call(StatusType.onResume);
  }

  void cancel() {
    _subscription?.cancel();
    clear();
    onStatusChanged?.call(StatusType.onCancel);
  }

  void clear() {
    _isStarted = false;
    _isCanceled = false;
    _isManualPause = false;
    _currentChunk = 0;
    _currentLength = 0;
    _subscription = null;
  }

  void dispose() {
    if (_subscription != null) {
      _subscription?.cancel();
      clear();
    }
  }
}
