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
  ValueNotifier<double> uploadProgress = ValueNotifier(0);
  ValueNotifier<double> streamProgress = ValueNotifier(0);
  ValueNotifier<UploadStatus> status = ValueNotifier(UploadStatus.notStarted);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      if (mounted) {
        uploadProgress.value = widget.controller.uploadProgress;
        streamProgress.value = widget.controller.streamProgress;
        status.value = widget.controller.status;
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
                UploadWebControls(
                  controller: controller,
                  status: status,
                ),
              ],
            ),
          ),
          ProgressIndicator(
            key: ValueKey(controller.file.name),
            status: status,
            streamProgress: streamProgress,
            uploadProgress: uploadProgress,
          ),
        ],
      ),
    );
  }
}

class UploadWebControls extends StatelessWidget {
  final UploadController controller;
  final ValueNotifier<UploadStatus> status;
  const UploadWebControls({
    super.key,
    required this.status,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: status,
      builder: (_, value, __) {
        switch (value) {
          case UploadStatus.notStarted:
            return Row(
              children: [
                TextButton(
                  onPressed: () {
                    controller.start();
                  },
                  child: const Text('Start'),
                ),
                TextButton(
                  onPressed: () {
                    // controller.abort();
                  },
                  child: const Text('Remove'),
                ),
              ],
            );
          case UploadStatus.active:
            return Row(
              children: [
                TextButton(
                  onPressed: () {
                    controller.pause();
                  },
                  child: const Text('Pause'),
                ),
                TextButton(
                  onPressed: () {
                    controller.abort();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          case UploadStatus.paused:
            return Row(
              children: [
                TextButton(
                  onPressed: () {
                    controller.restart();
                  },
                  child: const Text('Resume'),
                ),
                TextButton(
                  onPressed: () {
                    controller.abort();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          case UploadStatus.completed:
            return const Text('Upload Completed');
          case UploadStatus.canceled:
            return const Text('Upload Canceled');
          case UploadStatus.failed:
            return const Text('Upload Failed, Retrying...');
          default:
            return const SizedBox();
        }
      },
    );
  }
}

// when all the chunks have been sent and the upload progress is at 1 show green
// when the chunks are being sent show and the upload progress is < 1 show yellow
// when upload progress is < 1 override the yellow with blue.
// when the upload is canceled show red
class ProgressIndicator extends StatelessWidget {
  final ValueNotifier<UploadStatus> status;
  final ValueNotifier<double> streamProgress, uploadProgress;

  const ProgressIndicator({
    super.key,
    required this.status,
    required this.streamProgress,
    required this.uploadProgress,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: status,
      builder: (_, value, child) {
        return ColoredBox(
          key: key,
          color: value == UploadStatus.failed ? Colors.red : Colors.grey[200]!,
          child: child,
        );
      },
      child: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: streamProgress,
            builder: (_, value, __) {
              return LinearProgressIndicator(
                value: value,
                color: Colors.yellow[300],
                backgroundColor: Colors.transparent,
                minHeight: 5,
              );
            },
          ),
          ValueListenableBuilder(
            valueListenable: uploadProgress,
            builder: (_, value, __) {
              return LinearProgressIndicator(
                value: value,
                color: value == 1 ? Colors.green : Colors.blue,
                backgroundColor: Colors.transparent,
                minHeight: 5,
              );
            },
          ),

          // Second indicator says the progress of the upload
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

    _uploadControllers.addAll(
      List.from(
        result.files.map(
          (file) {
            return UploadController(file: file);
          },
        ),
      ),
    );

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
      padding: const EdgeInsets.all(8),
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
