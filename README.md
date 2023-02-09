# phomemo

A Flutter plugin to create information to send to phomemo printers.

## Getting started

To get started with phomemo add the package to your pubspec.yaml file.

### Generate a text image
Generates an image to send to the printer to print. Set the size as the size of the label. The example below has a height of 12mm with a infinately long length.
```dart
PhomemoHelper helper = PhomemoHelper();
img.Image? text = await helper.generateImage(
  TextSpan(
    text: 'text here',
    style: const TextStyle(
      fontSize: 34,
      color: Colors.black
    ),
  ),
  size: Size(double.inifity,12),
);
```

### Send info to the printer
Generate the data to send to the printer. Put the function to send to your printer in the class itself. In this case it is sending to a ble printer usng flutter_blue.

```dart
Phomemo label = Phomemo(send: bluetooth.write, read: bluetooth.read);
PhomemoPrinter printer = helper.getPrinterFromName(bluetooth.device!.name);

await label.printLabel(
  [img.decodePng(qrCode!.buffer.asUint8List()),letter],// the images to send to the printer
  printer: printer, //The printer that will be printed on
  spacing: 5, //space between images. Only works for D30, and D35 printers
  rotate: true, //rotate the image that is printing
  labelSize: Size(double.infinity,12), //size of the label
);
```

## Contributing

Feel free to propose changes by creating a pull request.

## Additional Information

This plugin is only for creating the information to send to phomemo printers. This has been tested on P12Pro, D35, D30 and M220.
