typedef Bytes = int;
const Bytes _byte = 1024;

extension Definitions on Bytes {
  int get kb => this * _byte;
  int get mb => this * _byte.kb;
  int get gb => this * _byte.mb;
}

class StreamOptions {
  final Bytes chunkSize;

  StreamOptions({
    this.chunkSize = 1 * _byte * _byte, // 1 MB
  });

  @override
  String toString() {
    return '''
      StreamOptions:
        - chunkSize: $chunkSize
    ''';
  }
}
