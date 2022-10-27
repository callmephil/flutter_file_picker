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
  int fileSize = 0;
  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withReadStream: true,
      readStreamChunkSize: 100 * 1024 * 1024,
      onFileLoading: (p0) => print(p0),
    );
    final file = result?.files.first;
    if (file == null || file.readStream == null) {
      return;
    }

    setState(() {
      fileSize = file.size;
    });

    final subscription = file.readStream!.listen(null);
    subscription.onData((data) {
      subscription.pause(delayedPrint(data.length));
    });
    subscription.onDone(() {
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
    return Future.delayed(const Duration(seconds: 1), () {
      // print(object);
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
          if (counter < fileSize)
            CircularProgressIndicator.adaptive(
              value: (counter / fileSize) * 100,
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
