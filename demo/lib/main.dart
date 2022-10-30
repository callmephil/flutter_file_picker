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
  final PlatformFile file;
  const FileUploadWidget({
    super.key,
    required this.file,
  });

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  late final UploadController _uploadController = UploadController(
    file: widget.file,
  );

  @override
  void initState() {
    super.initState();
    _uploadController.addListener(() {
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

  @override
  Widget build(BuildContext context) {
    // if (_uploadController == null) {
    //   return const Center(child: Text('No file selected'));
    // }

    return Container(
      key: ValueKey(widget.file.name),
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
                          widget.file.name,
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(widget.file.size / 1024).ceilToDouble()}kb | ${_uploadController.uploadSpeed}kb/s,',
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
                        _uploadController.start();
                      },
                      child: const Text('Start'),
                    ),
                    // -----------
                    // Same state
                    TextButton(
                      onPressed: () {
                        _uploadController.pause();
                      },
                      child: const Text('Pause'),
                    ),
                    TextButton(
                      onPressed: () {
                        _uploadController.resume();
                      },
                      child: const Text('Resume'),
                    ),
                    // -----------
                    // Same State
                    TextButton(
                      onPressed: () {
                        _uploadController.restart();
                      },
                      child: const Text('Restart'),
                    ),
                    // Must have a popup to confirm
                    TextButton(
                      onPressed: () {
                        _uploadController.abort();
                      },
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        _uploadController.abort();
                      },
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ColoredBox(
            color: _uploadController.status == UploadStatus.canceled
                ? Colors.red
                : Colors.grey[200]!,
            child: Stack(
              children: [
                LinearProgressIndicator(
                  value: _uploadController.streamProgress,
                  color: Colors.yellow[300],
                  backgroundColor: Colors.transparent,
                  minHeight: 5,
                ),
                // Second indicator says the progress of the upload
                LinearProgressIndicator(
                  value: _uploadController.uploadProgress,
                  color: _uploadController.uploadProgress == 1
                      ? Colors.green
                      : Colors.blue,
                  backgroundColor: Colors.transparent,
                  minHeight: 5,
                ),
              ],
            ),
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
  final ValueNotifier<List<FileUploadWidget>> _files = ValueNotifier([]);

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

    final files = result.files.map((file) {
      return FileUploadWidget(key: ValueKey(file.name), file: file);
    }).toList();

    _files.value = List.from(_files.value)..addAll(files);
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
            child: ValueListenableBuilder(
              valueListenable: _files,
              builder: (context, value, child) {
                print('update');
                if (value.isEmpty) {
                  return const Center(child: Text('No file selected'));
                }
                return ListView.builder(
                  key: const ValueKey('file-list'),
                  itemCount: value.length,
                  padding: const EdgeInsets.all(25),
                  itemBuilder: (context, index) {
                    return value[index];
                  },
                );
              },
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
