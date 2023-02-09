library phomemo;

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as m;
import 'package:image/image.dart';

enum PhomemoPrinter{P12Pro,D30,D35,M220}

class Phomemo{
  Phomemo({
    required this.send,
    required this.read
  });

  Future<void> Function(List<int>) send;
  Future<List<int>> Function() read;

  Future<void> printLabel(List<Image?> src, {required PhomemoPrinter printer,Size labelSize = const Size(12,double.infinity),int? spacing, bool rotate = true}) async{
    List<int> bits = [];
    for(int i = 0; i < src.length;i++){
      if(src[i] != null){
        bits += PhomemoHelper().preprocessImage(src[i]!,rotate, labelSize);
        if(spacing != null && PhomemoPrinter.M220 != printer){
          bits += List.filled(spacing*labelSize.width.toInt(), 0x00);
        }
      }
    }
    if(bits.isEmpty) return;
    int chunck = 256;
    await header(labelSize.width.toInt(),bits.length~/labelSize.width);
    for(int i = 0; i < bits.length/chunck;i++){
      if(i*chunck+chunck < bits.length){
        await send(bits.sublist(i*chunck,i*chunck+chunck));
      }
      else{
        await send(bits.sublist(i*chunck,bits.length));
      }
    }
    int end  = PhomemoPrinter.P12Pro == printer?0x0E:0x00;
    await send([0x1b,0x64,end]);
  } 
  Future<void> header(int width,int bytes) async{
    List<int> start = [0x1b,0x40,0x1d,0x76,0x30,0x00,width%256,width~/256,bytes%256,bytes~/256];
    await send(start);
  }
}

class PhomemoHelper{
  PhomemoPrinter getPrinterFromName(String name){
    for(int i = 0; i < PhomemoPrinter.values.length; i++){
      if(name.toLowerCase() == PhomemoPrinter.values[i].name.toLowerCase()){
        return PhomemoPrinter.values[i];
      }
    }
    return PhomemoPrinter.M220;
  }
  Future<Image?> generateImage(
    m.TextSpan text,{
      required Size size,
      int padding = 0,
    }
  ) async{
    m.TextPainter textPainter = m.TextPainter(
      text: text,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr
    )..layout(minWidth: 0, maxWidth: double.infinity);//maxWidth: size.width - 12.0 - 12.0

    final PictureRecorder recorder = PictureRecorder();
    Canvas newCanvas = Canvas(recorder);
    newCanvas.drawColor(m.Colors.white, m.BlendMode.color);
    double ratio = size.height/size.width;

    if(textPainter.width > size.width || size.width == double.infinity){
      size = Size(
        textPainter.width+padding,
        size.width == double.infinity?size.height:(textPainter.width+padding)*ratio
      );
    }

    textPainter.paint(
      newCanvas,
      Offset(
        (size.width- textPainter.width) * 0.5,
        (size.height - textPainter.height) * 0.5,
      ),
    );

    final Picture picture = recorder.endRecording();
    var res = await picture.toImage(
      size.width == double.infinity?(textPainter.width).toInt()+padding:size.width.toInt()+padding, 
      size.height == double.infinity?((textPainter.width+padding)*ratio).toInt():size.height.toInt()
    );
    ByteData? data = await res.toByteData(format: ImageByteFormat.png);

    if (data != null) {
      return decodePng(Uint8List.view(data.buffer));
    }

    return null;
  }

  List<int> preprocessImage(Image src, bool rotate, Size labelSize){
    Image resized = src;
    int newWidth = (labelSize.width*8).toInt();
    if(rotate){
      resized = copyResize(resized, height: newWidth);
      resized = copyRotate(resized,90);
    }
    else{
      resized = copyResize(resized, width: newWidth);
    }
    
    return _toRasterFormat(resized);
  }

  /// Image rasterization
  List<int> _toRasterFormat(Image imgSrc) {
    final Image image = Image.from(imgSrc); // make a copy
    final int widthPx = image.width;
    final int heightPx = image.height;

    grayscale(image);
    invert(image);

    // R/G/B channels are same -> keep only one channel
    final List<int> oneChannelBytes = [];
    final List<int> buffer = image.getBytes(format: Format.rgba);
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