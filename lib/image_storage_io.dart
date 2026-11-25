import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> persistImage(XFile image) async {
  final directory = await getApplicationDocumentsDirectory();
  final imagesDirectory = await Directory(p.join(directory.path, 'item_images'))
      .create(recursive: true);
  final extension = p.extension(image.path);
  final destination = p.join(
    imagesDirectory.path,
    '${DateTime.now().microsecondsSinceEpoch}$extension',
  );
  await File(image.path).copy(destination);
  return destination;
}

ImageProvider<Object>? storedImageProvider(String path) {
  final file = File(path);
  return file.existsSync() ? FileImage(file) : null;
}
