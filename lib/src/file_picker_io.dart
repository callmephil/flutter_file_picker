import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final MethodChannel _channel = MethodChannel(
  'miguelruivo.flutter.plugins.filepicker',
  Platform.isLinux || Platform.isWindows || Platform.isMacOS
      ? const JSONMethodCodec()
      : const StandardMethodCodec(),
);

const EventChannel _eventChannel =
    EventChannel('miguelruivo.flutter.plugins.filepickerevent');

/// An implementation of [FilePicker] that uses method channels.
class FilePickerIO extends FilePicker {
  static const String _tag = 'MethodChannelFilePicker';
  static StreamSubscription? _eventSubscription;

  @override
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileLoading,
    bool? allowCompression = true,
    bool allowMultiple = false,
    bool? withData = false,
    bool? withReadStream = false,
    bool lockParentWindow = false,
    int readStreamChunkSize = 1000 * 1000,
  }) =>
      _getPath(
        type,
        allowMultiple,
        allowCompression,
        allowedExtensions,
        onFileLoading,
        withData,
        withReadStream,
        readStreamChunkSize,
      );

  @override
  Future<bool?> clearTemporaryFiles() async =>
      _channel.invokeMethod<bool>('clear');

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    try {
      return await _channel.invokeMethod('dir', {});
    } on PlatformException catch (ex) {
      if (ex.code == "unknown_path") {
        print(
            '[$_tag] Could not resolve directory path. Maybe it\'s a protected one or unsupported (such as Downloads folder). If you are on Android, make sure that you are on SDK 21 or above.');
      }
    }
    return null;
  }

  Future<FilePickerResult?> _getPath(
    FileType fileType,
    bool allowMultipleSelection,
    bool? allowCompression,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool? withData,
    bool? withReadStream,
    int readStreamChunkSize,
  ) async {
    final String type = describeEnum(fileType);
    if (type != 'custom' && (allowedExtensions?.isNotEmpty ?? false)) {
      throw Exception(
          'You are setting a type [$fileType]. Custom extension filters are only allowed with FileType.custom, please change it or remove filters.');
    }
    try {
      _eventSubscription?.cancel();
      if (onFileLoading != null) {
        _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
              (data) => onFileLoading((data as bool)
                  ? FilePickerStatus.picking
                  : FilePickerStatus.done),
              onError: (error) => throw Exception(error),
            );
      }

      final List<Map>? result = await _channel.invokeListMethod(type, {
        'allowMultipleSelection': allowMultipleSelection,
        'allowedExtensions': allowedExtensions,
        'allowCompression': allowCompression,
        'withData': withData,
      });

      if (result == null) {
        return null;
      }

      final List<PlatformFile> platformFiles = <PlatformFile>[];

      for (final Map platformFileMap in result) {
        platformFiles.add(
          PlatformFile.fromMap(
            platformFileMap,
            readStream: withReadStream!
                ? _openFileReadStream(
                    File(platformFileMap['path']),
                    readStreamChunkSize,
                  )
                : null,
          ),
        );
      }

      return FilePickerResult(platformFiles);
    } on PlatformException catch (e) {
      print('[$_tag] Platform exception: $e');
      rethrow;
    } catch (e) {
      print(
          '[$_tag] Unsupported operation. Method not found. The exception thrown was: $e');
      rethrow;
    }
  }

  Stream<Uint8List> _openFileReadStream(File file, int chunkSize) async* {
    int length = await file.length();
    // int chunkCount = (length / chunkSize).ceil();
    // implement randomAccess
    RandomAccessFile randomAccessFile = file.openSync(mode: FileMode.read);

    // file is 13 * 1024 * 1024 bytes
    // we want to read 5 * 1024 * 1024 bytes at a time
    // so we need to read 3 chunks
    // chunk 1: setPositionSync(0) & yield readSync(0 - 5 * 1024 * 1024)
    // chunk 2: positionSync(1)  & yield readSync(5 * 1024 * 1024 - 10 * 1024 * 1024)
    // chunk 3: positionSync(2)  & yield readSync(10 * 1024 * 1024 - 13 * 1024 * 1024)
    //
    int start = 0;
    while (length > 0) {
      if (start > 0) {
        await randomAccessFile.setPosition(start);
      }
      int next = length > chunkSize ? chunkSize : length;
      length -= next;
      yield randomAccessFile.readSync(next);
      start += next;
    }
    await randomAccessFile.close();

    // final RandomAccessFile randomAccessFile = await file.open();
    // try {
    //   while (length > 0) {
    //     final int toRead = length > chunkSize ? chunkSize : length;
    //     final Uint8List data = await randomAccessFile.read(toRead);
    //     length -= toRead;
    //     yield data;
    //   }
    // } finally {
    //   await randomAccessFile.close();
    // }
  }
}
