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
            // progress,
            // controls,
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
}
