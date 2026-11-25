import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

Future<String> persistImage(XFile image) async {
  final bytes = await image.readAsBytes();
  final mimeType =
      image.mimeType ??
      switch (p.extension(image.name).toLowerCase()) {
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.gif' => 'image/gif',
        _ => 'image/jpeg',
      };
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}

ImageProvider<Object>? storedImageProvider(String path) {
  if (!path.startsWith('data:image/')) return null;
  return NetworkImage(path);
}
