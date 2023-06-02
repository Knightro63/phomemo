library phomemo;

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Image;
import 'package:image/image.dart' as img;

enum PhomemoPrinter { P12Pro, D30, D35, M220 }

class Phomemo {
  Phomemo({
    required this.send, 
    required this.read,
    this.packetSize = 256
  });

  Future<void> Function(List<int>) send;
  Future<List<int>> Function() read;
  int packetSize;

  Future<void> printLabel(
    List<img.Image?> src,
    {required PhomemoPrinter printer,
      Size labelSize = const Size(12, double.infinity),
      int? spacing,
      bool rotate = true
    }
  ) async {
    List<int> bits = [];
    for (int i = 0; i < src.length; i++) {
      if (src[i] != null) {
        bits += PhomemoHelper().preprocessImage(src[i]!, rotate, labelSize);
        if (spacing != null && PhomemoPrinter.M220 != printer) {
          bits += List.filled(spacing * labelSize.width.toInt(), 0x00);
        }
      }
    }
    if (bits.isEmpty) return;
    await header(labelSize.width.toInt(), bits.length ~/ labelSize.width);
    for (int i = 0; i < bits.length / packetSize; i++) {
      if (i * packetSize + packetSize < bits.length) {
        await send(bits.sublist(i * packetSize, i * packetSize + packetSize));
      } 
      else {
        await send(bits.sublist(i * packetSize, bits.length));
      }
    }
    int end = PhomemoPrinter.P12Pro == printer ? 0x0E : 0x00;
    await send([0x1b, 0x64, end]);
  }

  Future<void> header(int width, int bytes) async {
    List<int> start = [
      0x1b,
      0x40,
      0x1d,
      0x76,
      0x30,
      0x00,
      width % 256,
      width ~/ 256,
      bytes % 256,
      bytes ~/ 256
    ];
    await send(start);
  }
}

class PhomemoHelper {
  PhomemoPrinter getPrinterFromName(String name) {
    for (int i = 0; i < PhomemoPrinter.values.length; i++) {
      if (name.toLowerCase() == PhomemoPrinter.values[i].name.toLowerCase()) {
        return PhomemoPrinter.values[i];
      }
    }
    return PhomemoPrinter.M220;
  }

  Future<img.Image?> generateNameTag(
    m.TextSpan text, {
    required Size size,
    int padding = 0,
    bool withLogo = false,
    required String logoPath,
  }) async {
    m.TextPainter textPainter = m.TextPainter(
        text: text,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr)
      ..layout(
          minWidth: 0,
          maxWidth: double.infinity); //maxWidth: size.width - 12.0 - 12.0

    final PictureRecorder recorder = PictureRecorder();
    Canvas newCanvas = Canvas(recorder);
    newCanvas.drawColor(m.Colors.white, m.BlendMode.color);

    ByteData bd = await rootBundle.load(logoPath);
    Codec codec = await instantiateImageCodecFromBuffer(
      await ImmutableBuffer.fromUint8List(Uint8List.view(bd.buffer)),
    );

    Image codecImage = (await codec.getNextFrame()).image;

    Paint paint = Paint();
    paint.color = m.Colors.black;

    ImagePainter imagePainter = ImagePainter(image: codecImage, painter: paint);
    imagePainter.paint(newCanvas, size);

    textPainter.paint(
      newCanvas,
      Offset(
        (size.width - textPainter.width) / 2,
        size.height / 2,
      ),
    );

    final Picture picture = recorder.endRecording();
    var res = await picture.toImage(size.width.floor(), size.height.floor());

    ByteData? data = await res.toByteData(format: ImageByteFormat.png);

    if (data != null) {
      return img.decodePng(Uint8List.view(data.buffer));
    }

    return null;
  }

  Future<img.Image?> generateImage(
    m.TextSpan text, {
    required Size size,
    int padding = 0,
    bool withLogo = false,
  }) async {
    m.TextPainter textPainter = m.TextPainter(
        text: text,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr)
      ..layout(
          minWidth: 0,
          maxWidth: double.infinity); //maxWidth: size.width - 12.0 - 12.0

    final PictureRecorder recorder = PictureRecorder();
    Canvas newCanvas = Canvas(recorder);
    newCanvas.drawColor(m.Colors.white, m.BlendMode.color);
    double ratio = size.height / size.width;

    if (textPainter.width > size.width || size.width == double.infinity) {
      size = Size(
          textPainter.width + padding,
          size.width == double.infinity
              ? size.height
              : (textPainter.width + padding) * ratio);
    }

    textPainter.paint(
      newCanvas,
      Offset(
        (size.width - textPainter.width) * 0.5,
        (size.height - textPainter.height) * 0.5,
      ),
    );

    final Picture picture = recorder.endRecording();
    var res = await picture.toImage(
        size.width == double.infinity
            ? (textPainter.width).toInt() + padding
            : size.width.toInt() + padding,
        size.height == double.infinity
            ? ((textPainter.width + padding) * ratio).toInt()
            : size.height.toInt());
    ByteData? data = await res.toByteData(format: ImageByteFormat.png);

    if (data != null) {
      return img.decodePng(Uint8List.view(data.buffer));
    }

    return null;
  }

  List<int> preprocessImage(img.Image src, bool rotate, Size labelSize) {
    img.Image resized = src;
    int newWidth = (labelSize.width * 8).toInt();
    if (rotate) {
      resized = img.copyResize(resized, height: newWidth);
      resized = img.copyRotate(resized, angle: 90);
    } else {
      resized = img.copyResize(resized, width: newWidth);
    }

    return _toRasterFormat(resized);
  }

  /// Image rasterization
  List<int> _toRasterFormat(img.Image imgSrc) {
    final img.Image image = img.Image.from(imgSrc); // make a copy
    final int widthPx = image.width;
    final int heightPx = image.height;

    img.grayscale(image);
    img.invert(image);

    // R/G/B channels are same -> keep only one channel
    final List<int> oneChannelBytes = [];
    final List<int> buffer = image.getBytes();//image.getBytes(format: img.Format.rgba);
    for (int i = 0; i < buffer.length; i += 4) {
      oneChannelBytes.add(buffer[i]);
    }
    int pxPerLine = 8;
    // Add some empty pixels at the end of each line (to make the width divisible by 8)
    if (widthPx % pxPerLine != 0) {
      final targetWidth = (widthPx + pxPerLine) - (widthPx % pxPerLine);
      final missingPx = targetWidth - widthPx;
      final extra = Uint8List(missingPx);
      for (int i = 0; i < heightPx; i++) {
        final pos = (i * widthPx + widthPx) + i * missingPx;
        oneChannelBytes.insertAll(pos, extra);
      }
    }

    // Pack bits into bytes
    return _packBitsIntoBytes(oneChannelBytes);
  }

  /// Merges each 8 values (bits) into one byte
  List<int> _packBitsIntoBytes(List<int> bytes) {
    const pxPerLine = 8;
    final List<int> res = <int>[];
    const threshold = 127; // set the greyscale -> b/w threshold here
    for (int i = 0; i < bytes.length; i += pxPerLine) {
      int newVal = 0;
      for (int j = 0; j < pxPerLine; j++) {
        newVal = _transformUint32Bool(
          newVal,
          pxPerLine - j,
          bytes[i + j] > threshold,
        );
      }
      res.add(newVal ~/ 2);
    }
    return res;
  }

  /// Replaces a single bit in a 32-bit unsigned integer.
  int _transformUint32Bool(int uint32, int shift, bool newValue) {
    return ((0xFFFFFFFF ^ (0x1 << shift)) & uint32) |
        ((newValue ? 1 : 0) << shift);
  }
}

class ImagePainter extends CustomPainter {
  final Image image;
  Paint painter;

  ImagePainter({required this.image, required this.painter});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.drawImage(image, const Offset(35, 35), painter);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
