import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'bluetooth.dart';
import 'package:phomemo/phomemo.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Bluetooth bluetooth;
  BluetoothOptions? bleOptions;

  bool printing = false;
  String search = '';
  TextEditingController textController = TextEditingController();

  @override
  void initState() {
    bluetooth = Bluetooth(
      onUpdate: _bleUpdate,
      names: ['P12Pro','D35','D30']
    );
    super.initState();
  }
  @override
  void dispose() {
    bluetooth.destroy();
    super.dispose();
  }
  void _bleUpdate(BluetoothOptions options) {
    //setState(() {
      bleOptions = options;
    //});
    switch (options) {
      case BluetoothOptions.DISCONNECTED:
          setState(() {

          });
        break;
      case BluetoothOptions.CONNECTED:
        setState(() {

        });
        break;
      case BluetoothOptions.DATA_RECEIVED:
        setState(() {

        });
        break;
      default:
        setState((){

        });
        break;
    }
  }
  Future<void> printPhomemo({Uint8List? image,String? name, Size? size})async{// = const Size(double.infinity,12)
    size ??= const Size(double.infinity,12);
    if(printing) return;
    printing = true;
    Phomemo label = Phomemo(send: bluetooth.write, read: bluetooth.read);
    PhomemoHelper helper = PhomemoHelper();
    PhomemoPrinter printer = helper.getPrinterFromName(bluetooth.device!.name);
    
    if(printer == PhomemoPrinter.d35 && size.width == double.infinity){
      size = Size(25,size.height);
    }

    img.Image? letter = name != null?await helper.generateImage(
      TextSpan(
        text: name,//labelController.text, 
        style: const TextStyle(
          fontFamily: 'MuseoSans',
          fontSize: 34,
          color: Colors.black
        ),
      ),
      size: size*8,
    ):null;
    img.Image? qr = image != null?img.decodePng(image):null;
    await label.printLabel(
      [qr,letter],// 
      printer: printer,
      spacing: 5,
    ).then((value){
      printing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Type below the text you wish to print.',
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              width: 320,
              height: 35,
              alignment: Alignment.center,
              child: TextField(
                keyboardType: TextInputType.multiline,
                maxLines: 1,
                autofocus: false,
                controller: textController,
                decoration: const InputDecoration(
                  isDense: true,
                  filled: true,
                  contentPadding: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(10),
                    ),
                    borderSide: BorderSide(
                        width: 0, 
                        style: BorderStyle.none,
                    ),
                  ),
                  hintText: 'Text'
                ),
              )
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){printPhomemo(name: textController.text);},
        tooltip: 'Print',
        child: const Icon(Icons.print),
      ),
    );
  }
}
