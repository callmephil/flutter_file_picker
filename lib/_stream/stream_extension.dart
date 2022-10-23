import 'dart:io' show File;

import 'package:file_picker/_stream/stream_options.dart';

// ? Duplicate of _openReadStream in file_picker_web.dart.
extension FileStreamIO on File {
  Stream<List<int>> openReadStream(Bytes chunkSize) async* {
    int size = await length();

    // if the chunk size is bigger than the file size, we just read the whole file
    if (chunkSize >= size) {
      yield await openRead().first;
      return;
    }

    // if the chunk size is smaller than the file size, we read the file in chunks.
    // the last chunk is the reminder of the sum of all yielded chunks - [size].
    int start = 0;
    while (start < size) {
      final end = start + chunkSize > size ? size : start + chunkSize;
      final chunk = openRead(start, end);
      yield await chunk.first;
      start += chunkSize;
    }
  }
}
