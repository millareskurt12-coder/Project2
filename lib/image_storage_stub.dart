import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';

Future<String> persistImage(XFile image) {
  throw UnsupportedError('Image storage is not supported on this platform.');
}

ImageProvider<Object>? storedImageProvider(String path) => null;
