/// Minimal 8-bit RGB (no alpha) PNG encoder, so store images carry no alpha
/// channel (App Store rejects it) without adding a dependency.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c & 1 == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List _chunk(String type, List<int> data) {
  final body = [...ascii.encode(type), ...data];
  final out = BytesBuilder()
    ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
    ..add(body)
    ..add((ByteData(4)..setUint32(0, _crc32(body))).buffer.asUint8List());
  return out.toBytes();
}

/// Encodes straight RGBA [rgba] (`width * height * 4` bytes) as an RGB PNG,
/// dropping alpha. Callers must have composited onto an opaque background.
Uint8List encodeRgbPng(Uint8List rgba, int width, int height) {
  // Filter type 1 (Sub) per row compresses flat UI areas well.
  final raw = Uint8List(height * (1 + width * 3));
  var o = 0;
  for (var y = 0; y < height; y++) {
    raw[o++] = 1;
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      for (var c = 0; c < 3; c++) {
        final prev = x == 0 ? 0 : rgba[i - 4 + c];
        raw[o++] = (rgba[i + c] - prev) & 0xFF;
      }
    }
  }
  final header = (ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2)); // colour type 2 = RGB
  return (BytesBuilder()
        ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
        ..add(_chunk('IHDR', header.buffer.asUint8List()))
        ..add(_chunk('IDAT', ZLibCodec(level: 9).encode(raw)))
        ..add(_chunk('IEND', const [])))
      .toBytes();
}
