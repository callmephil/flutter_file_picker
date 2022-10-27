import 'dart:async';

import 'package:demo/stream_subscription_controller.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  StreamSubscriptionController? _streamController;

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withReadStream: true,
      readStreamChunkSize: kMaxBufferSize,
      onFileLoading: (p0) => print(p0),
    );
    final file = result?.files.first;
    if (file == null) {
      print('file is null');
      return;
    }

    if (file.readStream == null) {
      print('file readStream is null');
      return;
    }

    await Future.delayed(Duration(seconds: 5));

    final broadCastStream = file.readStream!.asBroadcastStream();

    final subscription1 = broadCastStream.listen(
      (event) {
        print('Stream 1 ${event.length}');
      },
      onDone: () => print('done subscription 1'),
    );

    final subscription2 = broadCastStream.listen(
      (event) {
        print('Stream 2 ${event.length}');
      },
      onDone: () => print('done subscription 2'),
    );

    final subscription3 = broadCastStream.listen(
      (event) {
        print('Stream 3 ${event.length}');
      },
      onDone: () => print('done subscription 3'),
    );

    final subscription4 = broadCastStream.listen(
      (event) {
        print('Stream 4 ${event.length}');
      },
      onDone: () => print('done subscription 4'),
    );

    final subscription5 = broadCastStream.listen(
      (event) {
        print('Stream 5 ${event.length}');
      },
      onDone: () => print('done subscription 5'),
    );

    // _streamController = StreamSubscriptionController(
    //   file.readStream!,
    //   size: file.size,
    //   onStatusChanged: (type) {
    //     print(type.name);
    //     setState(() {});
    //     switch (type) {
    //       case StatusType.onStart:
    //         break;
    //       case StatusType.onPause:
    //         // Should also cancel the onProgress callback
    //         break;
    //       case StatusType.onResume:
    //         break;
    //       case StatusType.onCancel:
    //         setState(() {});
    //         break;
    //       case StatusType.onError:
    //         break;
    //       case StatusType.onDone:
    //         break;
    //     }
    //   },
    //   onStart: () async {
    //     await delayedPrint('onStart');
    //   },
    //   onProgress: (data) async {
    //     print('ticking');
    //     await delayedPrint(data.length);
    //     // setState(() {});
    //   },
    // );

    // setState(() {});
  }

  Future delayedPrint<T>(T object, [int delay = 500]) {
    print('Processing delay: $delay');
    return Future.delayed(Duration(milliseconds: delay), () {
      print('Future Results: $object');
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
        child: _streamController != null
            ? ValueListenableBuilder(
                valueListenable: _streamController!.progress,
                builder: (context, value, child) {
                  print(value);
                  return CircularProgressIndicator(
                    color: Colors.white,
                    value: value,
                  );
                },
              )
            : const Icon(Icons.add),
      ),
    );
  }

  Widget get progress {
    if (_streamController == null) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sent: ${_streamController?.dataSent}'),
        Text('Expected: ${_streamController?.size}'),
        Text('Progress: ${_streamController?.progress.value}%')
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
