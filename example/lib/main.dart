import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      home: const MyHomePage(title: 'Phomemo Demo'),
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
  GlobalKey key = GlobalKey();
  late Bluetooth bluetooth;
  BluetoothOptions? bleOptions;

  bool isConnected = false;

  bool printing = false;
  String search = '';
  TextEditingController textController = TextEditingController();
  List<TextEditingController> sizeController = [TextEditingController(text: double.infinity.toString()),TextEditingController(text: '12.0')];
  Size labelSize = const Size(double.infinity,12);
  Uint8List? image;

  List<DropdownMenuItem<dynamic>> items = [];
  PhomemoPrinter printer = PhomemoPrinter.p12pro;
  List<bool> fixedLabel = [false,true];

  String showType = 'Example';

  @override
  void initState() {
    bluetooth = Bluetooth(
      onUpdate: _bleUpdate,
      names: ['P12Pro','D35','D30','Q155E2AQ1100400'] /// 'Q--------------' Place the name of the m-type (m110,m120,m220) printer here. This is displayed on the front of the printer.
    );

    for(final printer in PhomemoPrinter.values){
      items.add(DropdownMenuItem(
        value: printer,
        child: Text(
          printer.name, 
          overflow: TextOverflow.ellipsis,
        )
      ));
    }
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
  Future<void> printPhomemo({Uint8List? image,String? name,Size? size})async{
    size ??= const Size(double.infinity,12);
    if(printing) return;
    printing = true;
    Phomemo label = Phomemo(send: bluetooth.write);
    PhomemoPrinter printer = PhomemoHelper.getPrinterFromName(bluetooth.device!.platformName);
    img.Image? letter;
    if(showType == 'Custom'){
      letter = await textToImage(name,size);
    }
    else{
      letter = await PhomemoHelper.generateImageFromWidget(key);
    }

    await label.printLabel(
      [letter],
      printer: printer,
      spacing: 5,
      labelSize: labelSize,
      rotate: !PhomemoPrinter.isMType(printer) // do not rotate the image if using the m-type printer
    ).then((value){
      printing = false;
    });
  }

  Future<img.Image?> textToImage(String? text,Size size) async{
    img.Image? letter = text != null?await PhomemoHelper.generateImageFromText(
      TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'MuseoSans',
          fontSize: 34,
          color: Colors.black
        ),
      ),
      size: size*8,
    ):null;

    return letter;
  }

  Widget getWidget(){
    late Widget child;
    switch (printer) {
      case PhomemoPrinter.d35:
      case PhomemoPrinter.d30:
      case PhomemoPrinter.p12pro:
        child =  Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              const Icon(Icons.add_photo_alternate_outlined),
              labelSize.width == double.infinity?const Text('This is an Example of the printer printing!'):labelSize.width > 35?const Text('Example!'):const Text('Ex!')
            ],
          ),
        );
        break;
      default:
        child = Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.centerLeft,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.black,width: 2)
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.add_photo_alternate_outlined),
                SizedBox(
                  height: 20,
                ),
                Text(
                  'This is an Example of the printer printing!',
                  textAlign: TextAlign.center,
                )
              ],
            ),
          ),
        );
    }

    return Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height:35,
                  padding: const EdgeInsets.only(left: 7.5,right: 7.5),
                  margin: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton <dynamic>(
                      isExpanded: true,
                      items: items,
                      value: printer,
                      isDense: true,
                      onChanged: (d){
                        setState(() {
                          printer = d;

                          switch (printer) {
                            case PhomemoPrinter.d30:
                              labelSize = const Size(40, 12);
                              fixedLabel = [true,true];
                              break;
                            case PhomemoPrinter.d35:
                              labelSize = const Size(25, 12);
                              fixedLabel = [false,true];
                              break;
                            case PhomemoPrinter.p12pro:
                              labelSize = const Size(double.infinity, 12);
                              fixedLabel = [false,true];
                              break;
                            case PhomemoPrinter.m110:
                            case PhomemoPrinter.m120:
                            case PhomemoPrinter.m220:
                              labelSize = const Size(50, 80);
                              fixedLabel = [false,false];
                              break;
                            default:
                          }

                          sizeController[0].text = labelSize.width.toString();
                          sizeController[1].text = labelSize.height.toString();
                        });
                      },
                    ),
                  ),
                ),
                Container(
                  width: 120,
                  height:35,
                  padding: const EdgeInsets.only(left: 7.5,right: 7.5),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton <String>(
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Example',
                          child: Text(
                            'Example', 
                            overflow: TextOverflow.ellipsis,
                          )
                        ),
                        DropdownMenuItem(
                          value: 'Custom',
                          child: Text(
                            'Custom', 
                            overflow: TextOverflow.ellipsis,
                          )
                        )
                      ],
                      value: showType,
                      isDense: true,
                      onChanged: (d){
                        setState(() {
                          showType = d!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            showType == 'Custom'?Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              width: 320,
              height: 35,
              alignment: Alignment.center,
              child: TextField(
                keyboardType: TextInputType.multiline,
                maxLines: 1,
                autofocus: false,
                controller: textController,
                onChanged: (t)async {
                  image = img.encodePng((await textToImage(
                    textController.text,
                    labelSize
                  ))!);
                  setState(() {
                    
                  });
                },
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
            ):getWidget(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Tape Size: ',
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                  width: 80,
                  height: 35,
                  alignment: Alignment.center,
                  child: TextField(
                    readOnly: fixedLabel[0],
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                    ],
                    maxLines: 1,
                    autofocus: false,
                    controller: sizeController[0],
                    onChanged: (t){
                      labelSize = Size(sizeController[0].text != ''?double.parse(sizeController[0].text):double.infinity, sizeController[1].text != ''?double.parse(sizeController[1].text):12);
                      setState(() {
                        
                      });
                    },
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
                      hintText: 'width'
                    ),
                  )
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                  width: 80,
                  height: 35,
                  alignment: Alignment.center,
                  child: TextField(
                    readOnly: fixedLabel[1],
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                    ],
                    maxLines: 1,
                    autofocus: false,
                    controller: sizeController[1],
                    onChanged: (t){
                      labelSize = Size(sizeController[0].text != ''?double.parse(sizeController[0].text):double.infinity, sizeController[1].text != ''?double.parse(sizeController[1].text):12);
                      setState(() {
                        
                      });
                    },
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
                      hintText: 'height'
                    ),
                  )
                ),
              ],
            ),
            if(showType == 'Custom')Container(
              width: (labelSize.width * 3)+30,
              height: (labelSize.height * 3)+30,
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
              color: Theme.of(context).focusColor,
              child: Container(
                width: (labelSize.width * 3),
                height: (labelSize.height * 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  image: image == null?null:DecorationImage(image: MemoryImage(image!))
                ),
                alignment: Alignment.centerLeft,
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async{
          if(bluetooth.deviceConnected()){
            labelSize = Size(sizeController[0].text != ''?double.parse(sizeController[0].text):double.infinity, sizeController[1].text != ''?double.parse(sizeController[1].text):12);
            printPhomemo(
              name: textController.text,
              size: labelSize
            );
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
