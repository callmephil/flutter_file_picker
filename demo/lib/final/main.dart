import 'package:demo/final/widgets/file_upload_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

typedef BufferSize = int;
const BufferSize kb = 1024;
const BufferSize mb = kb * kb;
const BufferSize gb = mb * mb;
const BufferSize kMaxBufferSize = 5 * mb;

void main() {
  runApp(
    const MaterialApp(
      home: DemoScreen(),
    ),
  );
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final ValueNotifier<List<FileUploadWidget>> _files = ValueNotifier([]);

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
