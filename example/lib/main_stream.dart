import 'package:file_picker_example/src/file_picker_stream.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    Wakelock.enable();
  }

  runApp(
    MaterialApp(
      home: const FilePickerStream(),
    ),
  );
}
