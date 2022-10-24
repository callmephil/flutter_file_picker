import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void _print(Object? object) {
  print(object);
}

class FilePickerStream extends StatefulWidget {
  const FilePickerStream({Key? key}) : super(key: key);

  @override
  State<FilePickerStream> createState() => _FilePickerStreamState();
}

class _FilePickerStreamState extends State<FilePickerStream> {
  void _setState(void Function() fn) {
    if (!mounted) return;

    setState(fn);
  }

  void _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withReadStream: true,
        onFileLoading: (FilePickerStatus status) {
          _print(status);
        },
        streamOptions: StreamOptions(
          chunkSize: 10.mb,
        ),
      );

      if (result == null) {
        return;
      }

      final file = result.files.first;
      _readStream(file);
    } on PlatformException catch (e) {
      _print('Unsupported operation: $e');
    } catch (e) {
      _print('Unknown error: $e');
    }
  }

  void _clearCachedFiles() async {
    try {
      final result = await FilePicker.platform.clearTemporaryFiles();
      if (result == null) {
        return;
      }

      if (result) {
        _print('Temporary files cleared');
      } else {
        _print('Temporary files not cleared');
      }
    } on PlatformException catch (e) {
      _print('Unsupported operation$e');
    } catch (e) {
      _print('Unknown error$e');
    }
  }

  void _readStream(PlatformFile file) async {
    try {
      final stream = file.readStream;
      if (stream == null) {
        return;
      }

      final streamControl = StreamControl(
        stream,
        fileSize: file.size,
        chunkSize: file.streamOptions!.chunkSize,
      );

      const int startChunk = 0;
      final controls = Controls(
        onSuccess: () {
          _print('onSuccess');
        },
        onProgress: (data, progress, chunkNumber, accumulated) async {
          await Future.delayed(const Duration(milliseconds: 250), () async {
            _print(
              '''onProgress: 
            -> data: start - ${data.first} | end - ${data.last}, 
            -> length: ${data.length}, 
            -> progress: $progress, 
            -> chunkNumber: $chunkNumber, 
            -> accumulated: $accumulated''',
            );
            // ! .resume() should be private and
            // ! should be called inside readStream instead.
            // ! should be dependant of a 'predicted' to be executed.
            streamControl.resume();
          });
        },
        onAttempt: (_, __) {
          _print('onAttempt');
        },
        onAttemptFailure: (_, __, ___) {
          _print('onAttemptFailure');
        },
      );

      streamControl.readStream(
        controls,
        startChunk: startChunk,
      );
    } on PlatformException catch (e) {
      _print('Unsupported operation$e');
    } catch (e) {
      _print('Unknown error$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _pickFile,
          child: const Text('Pick file'),
        ),
      ),
    );
  }
}
