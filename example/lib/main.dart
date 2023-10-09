import 'package:flutter/material.dart';

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

  Future<void> printPhomemo({Uint8List? qrcode,String? name, Size? size})async{// = const Size(double.infinity,12)
    size ??= const Size(double.infinity,12);
    if(printing) return;
    printing = true;
    Phomemo label = Phomemo(send: bluetooth.write, read: bluetooth.read);
    PhomemoHelper helper = PhomemoHelper();
    PhomemoPrinter printer = helper.getPrinterFromName(bluetooth.device!.name);
    
    if(printer == PhomemoPrinter.D35 && size.width == double.infinity){
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
    img.Image? qr = qrcode != null?img.decodePng(qrcode):null;
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
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
