import 'dart:html' as html show File, FileReader;
import 'dart:io' as io show File;

import 'package:file_picker/_stream/stream_options.dart';

extension FileStreamWeb on html.File {
  Stream<List<int>> openReadStream(Bytes chunkSize) async* {
    final reader = html.FileReader();

    // if the chunk size is bigger than the file size, we just read the whole file
    if (chunkSize >= size) {
      reader.readAsArrayBuffer(this);
      await reader.onLoadEnd.first;
      yield reader.result as List<int>;
      return;
    }

    // if the chunk size is smaller than the file size, we read the file in chunks
    int start = 0;
    while (start < size) {
      final end = start + chunkSize > size ? size : start + chunkSize;
      final blob = slice(start, end);
      reader.readAsArrayBuffer(blob);
      await reader.onLoad.first;
      yield reader.result as List<int>;
      start += chunkSize;
    }
  }
}

extension FileStreamIO on io.File {
  Stream<List<int>> openReadStream(Bytes chunkSize) async* {
    int size = await length();

    // if the chunk size is bigger than the file size, we just read the whole file
    if (chunkSize >= size) {
      yield await openRead().first;
      return;
    }

    // if the chunk size is smaller than the file size, we read the file in chunks
    int start = 0;
    while (start < size) {
      final end = start + chunkSize > size ? size : start + chunkSize;
      final chunk = openRead(start, end);
      yield await chunk.first;
      start += chunkSize;
    }
  }
}
