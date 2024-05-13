library phomemo;

import 'dart:ui';
import 'package:flutter/material.dart' as m;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Image;
import 'package:image/image.dart' as img;

/// Phomemo printes that have been tested and are supported
enum PhomemoPrinter { p12pro, d30, d35, m220 }

/// [packetSize] the max size of the information you wish to send to the printer 
/// 256 is the largest value. Other values are 8,16,32,128
/// 
/// [send] is the function from the ble package you are using to send the information
class Phomemo {
  Phomemo({
    required this.send, 
    this.packetSize = 128
  });

  Future<void> Function(List<int>) send;
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
    if (rotate) {
      labelSize = Size(labelSize.height,labelSize.width);
    }
    List<int> bits = [];
    for (int i = 0; i < src.length; i++) {
      if (src[i] != null) {
        bits += PhomemoHelper._preprocessImage(src[i]!, rotate, labelSize);
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
  /// to capture widget to image by GlobalKey in RenderRepaintBoundary
  static Future<img.Image?> generateImageFromWidget(GlobalKey containerKey) async {
    try {
      /// boundary widget by GlobalKey
      RenderRepaintBoundary? boundary = containerKey.currentContext?.findRenderObject() as RenderRepaintBoundary?; 

      /// convert boundary to image
      final image = await boundary!.toImage(pixelRatio: 6);

      /// set ImageByteFormat
      final data = await image.toByteData(format: ImageByteFormat.png);
      return _byteDataToImage(data);

    } catch (e) {
      rethrow;
    }
  }

  /// If the name is a String convert to [PhomemoPrinter] enum.
  static PhomemoPrinter getPrinterFromName(String name) {
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
  static Future<img.Image?> generateNameTag(
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
    final res = await picture.toImage(size.width.floor(), size.height.floor());
    final data = await res.toByteData(format: ImageByteFormat.png);

    return _byteDataToImage(data);
  }

  @Deprecated("Use generateImageFromText")
  static Future<img.Image?> generateImage(
    m.TextSpan text, {
    required Size size,
    int padding = 0
  }) async {
    return generateImageFromText(
      text,
      size: size,
      padding:padding
    );
  }
  /// Generate Image from Text in the corrected lable size format.
  static Future<img.Image?> generateImageFromText(
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
          maxWidth: double.infinity);

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
    final res = await picture.toImage(
        size.width == double.infinity
            ? (textPainter.width).toInt() + padding
            : size.width.toInt() + padding,
        size.height == double.infinity
            ? ((textPainter.width + padding) * ratio).toInt()
            : size.height.toInt());
    final data = await res.toByteData(format: ImageByteFormat.png);

    return _byteDataToImage(data);
  }

  /// Process the image to a readable format for the printer
  static List<int> _preprocessImage(img.Image src, bool rotate, Size labelSize) {
    late img.Image resized = src;

    if (rotate) {
      resized = img.copyRotate(resized, angle: 90);
    } 
    
    resized = img.copyResize(resized, width: (labelSize.width*8).toInt());
    img.grayscale(resized);
    img.invert(resized);
    resized = resized.convert(format:img.Format.uint8 ,numChannels: 1);

    // Pack bits into bytes
    return _packBitsIntoBytes(resized.getBytes());
  }

  static img.Image? _byteDataToImage(ByteData? data){
    if (data != null) {
      return img.decodePng(Uint8List.view(data.buffer));
    }
    return null;
  }

  /// Merges each 8 values (bits) into one byte
  static List<int> _packBitsIntoBytes(List<int> bytes) {
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
  static int _transformUint32Bool(int uint32, int shift, bool newValue) {
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
