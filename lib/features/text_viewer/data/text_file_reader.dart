import 'dart:io';

class TextFileReader {
  Future<String> readFile(String filePath) async {
    final file = File(filePath);
    return file.readAsString();
  }
}
