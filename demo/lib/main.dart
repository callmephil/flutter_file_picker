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

Future delayedPrint(Object? object) {
  return Future.delayed(const Duration(seconds: 1), () {
    print(object);
  });
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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

    final subscription = file.readStream!.listen(null);
    subscription.onData((data) {
      print('Listening');
      subscription.pause(delayedPrint(data.length));
    });
    subscription.onDone(() {
      print('done');
    });
  }

  int counter = 0;
  void _updateCounter() {
    if (!mounted) {
      return;
    }

    setState(() {
      counter++;
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
          Text('Counted $counter times'),
          ElevatedButton(
            onPressed: _updateCounter,
            child: const Text('Increment'),
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
