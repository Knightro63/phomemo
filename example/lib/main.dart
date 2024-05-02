import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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

  bool isConnected = false;

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
    bluetooth.dispose();
    super.dispose();
  }
  void _bleUpdate(BluetoothOptions options) {
    //setState(() {
      bleOptions = options;
    //});
    switch (options) {
      case BluetoothOptions.disconnected:
          setState(() {

          });
        break;
      case BluetoothOptions.connected:
        setState(() {

        });
        break;
      case BluetoothOptions.dataReceived:
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
    Phomemo label = Phomemo(send: bluetooth.write, read: bluetooth.read, packetSize: 128);
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
            Text(
              bluetooth.deviceConnected()?'Type below the text you wish to print.':'Press floating action button to connect to a phomemo printer.',
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              width: 320,
              height: 35,
              alignment: Alignment.center,
              child: bluetooth.deviceConnected()?TextField(
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
              ):Container()
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async{
          if(bluetooth.deviceConnected()){
            printPhomemo(name: textController.text);
          }
          else if(!bluetooth.isScanning && bluetooth.device == null){
            if(
              ((Platform.isMacOS || Platform.isIOS) && await Permission.bluetooth.request().isGranted) 
              || (Platform.isAndroid && await Permission.bluetoothScan.request().isGranted && await Permission.bluetoothConnect.request().isGranted)
            ){
              bluetooth.startScan();
            }
          }
          else if(bluetooth.isScanning && bluetooth.device == null){
            bluetooth.stopScan();
          }
        },
        tooltip: bluetooth.deviceConnected()?'Print':'Search',
        child: Icon(bluetooth.deviceConnected()?Icons.print:((!bluetooth.isScanning && bluetooth.device == null)?Icons.bluetooth_disabled_rounded:Icons.bluetooth_audio)),
      ),
    );
  }
}
