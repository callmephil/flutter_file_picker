import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FileUploadWidget extends StatefulWidget {
  final PlatformFile file;
  const FileUploadWidget({super.key, required this.file});

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
