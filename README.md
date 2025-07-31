# phomemo
[![Pub Version](https://img.shields.io/pub/v/phomemo)](https://pub.dev/packages/phomemo)
[![analysis](https://github.com/Knightro63/phomemo/actions/workflows/flutter.yml/badge.svg)](https://github.com/Knightro63/phomemo/actions/)
[![Star on Github](https://img.shields.io/github/stars/Knightro63/phomemo.svg?style=flat&logo=github&colorB=deeppink&label=stars)](https://github.com/Knightro63/phomemo)
[![License: BSD](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin to create information to send to phomemo printers.

## Getting started

To get started with phomemo add the package to your pubspec.yaml file.

### Generate a widget image
Generates an image to send to the printer to print. Set the size as the size of the label. The example below has a height of 12mm with a infinately long length.
```dart
GlobalKey key = GlobalKey();
Size labelSize = const Size(double.infinity,12);

Widget widget = Container(
  width: (labelSize.width * 3)+30,
  height: (labelSize.height * 3)+30,
  margin: const EdgeInsets.only(top:5),
  padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
  color: Theme.of(context).focusColor,
  child: RepaintBoundary(
    key: key,
    child: child,
  )
);

img.Image? image = await PhomemoHelper.generateImageFromWidget(key);
```

### Generate a text image
Generates an image to send to the printer to print. Set the size as the size of the label. The example below has a height of 12mm with a infinately long length.
```dart
img.Image? text = await PhomemoHelper.generateImageFromText(
  TextSpan(
    text: 'text here',
    style: const TextStyle(
      fontSize: 34,
      color: Colors.black
    ),
  ),
  size: Size(double.inifity,12), //Change this to the lable size
);
```

### Send info to the printer
Generate the data to send to the printer. Put the function to send to your printer in the class itself. In this case it is sending to a ble printer usng flutter_blue_plus.

```dart
Phomemo label = Phomemo(send: bluetooth.write, read: bluetooth.read);
PhomemoPrinter printer = helper.getPrinterFromName(bluetooth.device!.name);

await label.printLabel(
  [img.decodePng(qrCode!.buffer.asUint8List()),letter],// the images to send to the printer
  printer: printer, //The printer that will be printed on
  spacing: 5, //space between images. Only works for D30, and D35 printers
  rotate: printer != PhomemoPrinter.m220 // do not rotate the image if using the m220 or m110
  labelSize: Size(double.infinity,12), //size of the label
);
```
## Example

Find the example app [here](https://github.com/Knightro63/phomemo/tree/main/example).

## Contributing

Contributions are welcome.
In case of any problems look at [existing issues](https://github.com/Knightro63/phomemo/issues), if you cannot find anything related to your problem then open an issue.
Create an issue before opening a [pull request](https://github.com/Knightro63/phomemo/pulls) for non trivial fixes.
In case of trivial fixes open a [pull request](https://github.com/Knightro63/phomemo/pulls) directly.

## Additional Information

This plugin is only for creating the information to send to phomemo printers. This has been tested on P12Pro, D35, D30, M10 and M220.
