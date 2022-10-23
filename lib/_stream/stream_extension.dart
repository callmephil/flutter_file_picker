import 'dart:async';
import 'dart:io' show File;

import 'package:file_picker/_stream/stream_options.dart';

// Transform a stream of bytes into a stream of chunks of bytes.
Future<List<int>> _streamTransformer(Stream<List<int>> source) async {
  final list = <int>[];
  await for (final chunk in source) {
    for (final byte in chunk) {
      list.add(byte);
    }
  }
  return list;
}

// ? Duplicate of _openReadStream in file_picker_web.dart.
extension FileStreamIO on File {
  Stream<List<int>> openReadStream(Bytes chunkSize) async* {
    int size = await length();

    // if the chunk size is bigger than the file size, we just read the whole file
    if (chunkSize >= size) {
      yield readAsBytesSync();
      return;
    }

    // if the chunk size is smaller than the file size, we read the file in chunks.
    // the last chunk is the reminder of the sum of all yielded chunks - [size].
    int start = 0;
    while (start < size) {
      final end = start + chunkSize > size ? size : start + chunkSize;
      // We need to convert the Stream<List<int>> to a List<int> to be able to yield it.
      final chunk = await _streamTransformer(openRead(start, end));

      yield chunk;
      start += chunkSize;
    }
  }
}
