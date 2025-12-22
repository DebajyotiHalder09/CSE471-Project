// Stub file for web - File operations are not available on web
class File {
  File(String path);
  Future<void> writeAsBytes(List<int> bytes) async {}
  String get path => '';
}

