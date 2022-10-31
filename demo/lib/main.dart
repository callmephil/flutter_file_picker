import 'dart:async';

import 'package:demo/stream_subscription_controller.dart';
import 'package:demo/upload.dart';
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
      home: const DemoPage(),
    );
  }
}

class FileUploadWidget extends StatefulWidget {
  final UploadController controller;
  const FileUploadWidget({
    super.key,
    required this.controller,
  });

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    //
    super.dispose();
  }

  UploadController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    // if (_uploadController == null) {
    //   return const Center(child: Text('No file selected'));
    // }

    print(widget.key);

    return Container(
      key: widget.key,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.rectangle,
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.image_outlined, size: 48),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.controller.file.name,
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(controller.file.size / 1024).ceilToDouble()}kb | ${controller.uploadSpeed}kb/s,',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),

                // should be a status notifier, based on that we render 3 different states
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        controller.start();
                      },
                      child: const Text('Start'),
                    ),
                    // -----------
                    // Same state
                    TextButton(
                      onPressed: () {
                        controller.pause();
                      },
                      child: const Text('Pause'),
                    ),
                    TextButton(
                      onPressed: () {
                        controller.resume();
                      },
                      child: const Text('Resume'),
                    ),
                    // -----------
                    // Same State
                    TextButton(
                      onPressed: () {
                        controller.restart();
                      },
                      child: const Text('Restart'),
                    ),
                    // Must have a popup to confirm
                    TextButton(
                      onPressed: () {
                        controller.abort();
                      },
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        controller.abort();
                      },
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ProgressIndicator(
            key: ValueKey(controller.file.name),
            status: controller.status,
            streamProgress: controller.streamProgress,
            uploadProgress: controller.uploadProgress,
          ),
        ],
      ),
    );
  }
}

class ProgressIndicator extends StatelessWidget {
  final UploadStatus status;
  final double streamProgress, uploadProgress;

  const ProgressIndicator({
    super.key,
    required this.status,
    required this.streamProgress,
    required this.uploadProgress,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: key,
      color: status == UploadStatus.canceled ? Colors.red : Colors.grey[200]!,
      child: Stack(
        children: [
          LinearProgressIndicator(
            value: streamProgress,
            color: Colors.yellow[300],
            backgroundColor: Colors.transparent,
            minHeight: 5,
          ),
          // Second indicator says the progress of the upload
          LinearProgressIndicator(
            value: uploadProgress,
            color: uploadProgress == 1 ? Colors.green : Colors.blue,
            backgroundColor: Colors.transparent,
            minHeight: 5,
          ),
        ],
      ),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => DemoPageState();
}

class DemoPageState extends State<DemoPage> {
  final List<UploadController> _uploadControllers = [];

  @override
  void initState() {
    super.initState();
  }

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withReadStream: true,
      readStreamChunkSize: kMaxBufferSize,
      onFileLoading: (p0) => print(p0),
    );

    if (result == null) {
      return;
    }

    if (result.files.isEmpty) {
      print('No file selected');
      return;
    }

    final files = result.files;
    _uploadControllers.add(UploadController(file: files.first));
    setState(() {});
    // for (var file in files) {
    //   _controllers.add(
    //     UploadController(file: file),
    //   );
    // }
    // if (mounted) {
    //   setState(() {});
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Stream Demo'),
      ),
      body: Column(
        children: [
          const Text('Upload list'),
          Expanded(
            child: UploadList(
              controllers: _uploadControllers,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFile,
        tooltip: 'Pick File',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class UploadList extends StatefulWidget {
  final List<UploadController> controllers;
  const UploadList({super.key, required this.controllers});

  @override
  State<UploadList> createState() => _UploadListState();
}

class _UploadListState extends State<UploadList> {
  @override
  Widget build(BuildContext context) {
    return ListView.custom(
      key: const ValueKey('upload-list'),
      childrenDelegate: SliverChildBuilderDelegate(
        (context, index) {
          final controller = widget.controllers[index];
          return FileUploadWidget(
            key: ValueKey(controller.file.name),
            controller: controller,
          );
        },
        childCount: widget.controllers.length,
        findChildIndexCallback: (key) {
          if (key is ValueKey) {
            final value = key.value;
            if (value is UploadController) {
              return widget.controllers.indexOf(value);
            }
          }
          return null;
        },
      ),
    );
  }
}
