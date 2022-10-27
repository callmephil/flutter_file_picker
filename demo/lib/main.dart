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

enum EmitType {
  onStart,
  onPause,
  onResume,
  onCancel,
  onError,
  onDone,
}

typedef FutureCallback = Future<void> Function(int);

class UploadController {
  final Stream<Uint8List> stream;
  Function(EmitType type)? onEmitter;
  FutureCallback onTick;
  UploadController(
    this.stream, {
    this.onEmitter,
    required this.onTick,
  });

  bool _isCanceled = false;
  bool _isManualPause = false;

  StreamSubscription<Uint8List>? _subscription;
  bool get isCanceled => _isCanceled;
  bool get isPaused => _subscription?.isPaused ?? false || _isManualPause;

  void start() {
    _subscription = stream.listen((_) {
      print('started');
    }, cancelOnError: true);

    _subscription?.onData((data) async {
      _subscription?.pause();
      await onTick.call(data.length);
      _subscription?.resume();
    });

    _subscription?.onDone(() {
      onEmitter?.call(EmitType.onDone);
    });

    _subscription?.onError((e) {
      print('Stream Error: $e');
      onEmitter?.call(EmitType.onError);
    });
  }

  void pause() {
    _subscription?.pause();
    _isManualPause = true;
    onEmitter?.call(EmitType.onPause);
  }

  void resume() {
    if (_isManualPause) {
      _subscription?.resume();
    }
    // When manually paused, we must resume it twice.
    // It is safe to resume, even if it is not paused
    _subscription?.resume();

    onEmitter?.call(EmitType.onResume);
  }

  void cancel() {
    _subscription?.cancel();
    _isCanceled = true;
    onEmitter?.call(EmitType.onCancel);
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
  StreamSubscription<Uint8List>? _subscription;

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

    _subscription = file.readStream!.listen(null, cancelOnError: true);
    _subscription?.onData((data) async {
      _subscription?.pause();
      await delayedPrint(data.length);
      _subscription?.resume();
    });
    _subscription?.onError((err) {
      print(err);
    });
    _subscription?.onDone(() {
      print('done');
    });
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
    return Future.delayed(const Duration(milliseconds: 1000), () {
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
      body: Row(
        children: [
          Text('Sent: $counter/$fileSize'),
          ElevatedButton(
            onPressed: () {
              _subscription?.cancel();
              _subscription?.resume();
            },
            child: const Text('Cancel'),
          ),
        ],
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
}
