library phomemo;

import 'dart:ui';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Image;
import 'package:image/image.dart' as img;

/// Phomemo printes that have been tested and are supported
enum PhomemoPrinter { p12pro, d30, d35, m220 }

/// [packetSize] the max size of the information you wish to send to the printer 
/// 256 is the largest value. Other values are 8,16,32,128
/// 
/// [send] is the function from the ble package you are using to send the information
/// 
/// [read] is the function that gets info from the printer
class Phomemo {
  Phomemo({
    required this.send, 
    this.read,
    this.packetSize = 256
  });

  Future<void> Function(List<int>) send;
  Future<List<int>> Function()? read;
  int packetSize;

  /// sends the packts to the label maker
  /// 
  /// [src] is the image that is being sent
  /// 
  /// [printer] is the type of printer being used
  /// 
  /// [labelSize] is the size of the label.
  /// 
  /// [spacing] is the spacing inbetween labels if printing more than one
  /// 
  /// [rotate] use this if the label is printing left to right. Otherwise it is printing top to bottom
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
        if (spacing != null && PhomemoPrinter.m220 != printer) {
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
    int end = PhomemoPrinter.p12pro == printer ? 0x0E : 0x00;
    await send([0x1b, 0x64, end]);
  }

  /// The start information for the printer
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

/// This is a helper to create lables from text or images
class PhomemoHelper {

  /// If the name is a String convert to [PhomemoPrinter] enum.
  PhomemoPrinter getPrinterFromName(String name) {
    for (int i = 0; i < PhomemoPrinter.values.length; i++) {
      if (name.toLowerCase() == PhomemoPrinter.values[i].name.toLowerCase()) {
        return PhomemoPrinter.values[i];
      }
    }
    return PhomemoPrinter.m220;
  }

  /// If using the m220 and wish to have a name tag created.
  /// 
  /// [text] is the text in the center of the nametag
  /// 
  /// [size] is the size of the nametag
  /// 
  /// [padding] is the padding around the nametag
  /// 
  /// [logoPath] is the path of the logo you wish to put onto the nametag
  Future<img.Image?> generateNameTag(
    m.TextSpan text, {
    required Size size,
    int padding = 0,
    String? logoPath,
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

    if(logoPath != null){
      ByteData bd = await rootBundle.load(logoPath);
      Codec codec = await instantiateImageCodecFromBuffer(
        await ImmutableBuffer.fromUint8List(Uint8List.view(bd.buffer)),
      );

      Image codecImage = (await codec.getNextFrame()).image;

      Paint paint = Paint();
      paint.color = m.Colors.black;

      ImagePainter imagePainter = ImagePainter(image: codecImage, painter: paint);
      imagePainter.paint(newCanvas, size);
    }

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

  /// Generate Image from Text in the corrected lable size format.
  Future<img.Image?> generateImage(
    m.TextSpan text, {
    required Size size,
    int padding = 0
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

  /// Process the image to a readable format for the printer
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
    img.Image image = img.Image.from(imgSrc); // make a copy
    final int widthPx = image.width;
    final int heightPx = image.height;

    img.grayscale(image);
    img.invert(image);
    image = image.convert(format:img.Format.uint8,numChannels: 4);

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
