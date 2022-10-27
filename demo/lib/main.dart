import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

enum StatusType {
  onStart,
  onPause,
  onResume,
  onCancel,
  onError,
  onDone,
}

typedef FutureCallback = Future<void> Function(int);

class StreamSubscriptionController {
  final Stream<Uint8List> stream;
  Function(StatusType type)? onStatusChanged;
  FutureCallback onProgress;
  StreamSubscriptionController(
    this.stream, {
    this.onStatusChanged,
    required this.onProgress,
  });

  bool _isCanceled = false;
  bool _isManualPause = false;

  StreamSubscription<Uint8List>? _subscription;
  bool get isCanceled => _isCanceled;
  bool get isPaused => _isManualPause;

  void start() {
    print('pre-process');
    _subscription = stream.listen((_) {
      print('started');
    }, cancelOnError: true);

    _subscription?.onData((data) async {
      _subscription?.pause(onProgress.call(
        data.length,
      ));
      // _subscription?.resume();
    });

    _subscription?.onDone(() {
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
      _subscription?.resume();
    }
    // When manually paused, we must resume it twice.
    // It is safe to resume, even if it is not paused
    _subscription?.resume();

    onStatusChanged?.call(StatusType.onResume);
  }

  void cancel() {
    _subscription?.cancel();
    _isCanceled = true;
    onStatusChanged?.call(StatusType.onCancel);
  }

  void dispose() {
    if (_subscription != null) {
      _subscription?.cancel();
      _subscription = null;
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int fileSize = 0;
  StreamSubscriptionController? _streamController;

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withReadStream: true,
      readStreamChunkSize: 1 * 1024 * 1024,
      onFileLoading: (p0) => print(p0),
    );
    final file = result?.files.first;
    if (file == null) {
      return;
    }

    setState(() {
      counter = 0;
      fileSize = file.size;
    });

    if (file.readStream == null) {
      return;
    }

    _streamController = StreamSubscriptionController(
      file.readStream!,
      onStatusChanged: (type) => print(type),
      onProgress: (size) async {
        print('ticking');
        await delayedPrint(size);
        print('after await');
      },
    );

    // _subscription = file.readStream!.listen(null, cancelOnError: true);
    // _subscription?.onData((data) async {
    //   _subscription?.pause();
    //   await delayedPrint(data.length);
    //   _subscription?.resume();
    // });
    // _subscription?.onError((err) {
    //   print(err);
    // });
    // _subscription?.onDone(() {
    //   print('done');
    // });
  }

  int counter = 0;
  void _updateCounter(int len) {
    if (!mounted) {
      return;
    }

    setState(() {
      counter += len;
    });
  }

  Future delayedPrint(int object) {
    return Future.delayed(const Duration(milliseconds: 5000), () {
      print(object);
      _updateCounter(object);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: [
            progress,
            controls,
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFile,
        tooltip: 'Pick File',
        child: counter < fileSize
            ? CircularProgressIndicator(
                color: Colors.white,
                value: (counter / fileSize),
              )
            : const Icon(Icons.add),
      ),
    );
  }

  Widget get progress {
    if (_streamController == null) {
      return const SizedBox();
    }
    int progress = ((counter / fileSize) * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sent: $counter'),
        Text('Expected: $fileSize'),
        Text('Progress: $progress%')
      ],
    );
  }

  Widget get controls {
    if (_streamController == null) {
      return const SizedBox();
    }

    return Row(
      children: [
        ElevatedButton(
          onPressed: _streamController!.start,
          child: const Text('Start'),
        ),
        ElevatedButton(
          onPressed: _streamController!.isPaused
              ? _streamController!.resume
              : _streamController!.pause,
          child: Text(_streamController!.isPaused ? 'Resume' : 'Pause'),
        ),
        ElevatedButton(
          onPressed: _streamController!.cancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
