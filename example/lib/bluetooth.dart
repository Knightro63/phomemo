import 'dart:async';
import 'package:flutter_blue/flutter_blue.dart';

enum BluetoothOptions {
  SEARCHING,
  CONNECTING,
  CONNECTED,
  RECEIVED_SERVICES,
  DISCONNECTED,
  DATA_RECEIVED,
  STOP_SEARCHING
}

typedef BluetoothCallback = void Function(BluetoothOptions options);

class Bluetooth {
  Bluetooth({
    required BluetoothCallback onUpdate,
    List<Guid>? services,
    this.names
  }) {
    guid = services ?? [];
    _onUpdate = onUpdate;
    flutterBlue.state.listen((onData) {
      state = onData;
    });
  }
  List<String>? names;
  List<Guid> guid = [];
  late BluetoothCallback _onUpdate;
  BluetoothDeviceState deviceState = BluetoothDeviceState.disconnected;
  BluetoothState state = BluetoothState.unknown;
  FlutterBlue flutterBlue = FlutterBlue.instance;

  BluetoothDevice? device;
  List<BluetoothCharacteristic>? characteristic;
  ScanResult? scanResults;
  List<BluetoothService> services = [];

  bool hasDevices = false;
  bool hasServices = false;

  bool deviceConnected() {
    return (deviceState == BluetoothDeviceState.connected);
  }

  void startScan() {
    print("Starting Scan on App Bar");
    if (state == BluetoothState.on) {
      _btScan();
    }
  }
  void _btScan() {
    print("Scanning");
    bool allowScan = true;
    bool didStop = false;
    _onUpdate(BluetoothOptions.SEARCHING);
    flutterBlue.scan(
      scanMode: ScanMode.balanced,
      timeout: const Duration(minutes: 2), 
      withServices: guid,
      allowDuplicates: false
    ).listen((scanResult) {
      if(allowScan){
        if(guid.isNotEmpty){
          scanResults = scanResult;
          stopScan("Connecting Guid");
          _connect(scanResult.device);
          didStop = true;
          allowScan = false;
        }
        else if(names != null){
          for(int i = 0; i < names!.length;i++){
            if(scanResult.device.name.toLowerCase() == names![i].toLowerCase()){
              scanResults = scanResult;
              stopScan("Connecting Name");
              _connect(scanResult.device);
              allowScan = false;
              didStop = true;
              break;
            }
          }
        }
        else{
          print(scanResult.device.name);
          allowScan = false;
        }
      }
    }, onDone: () {
      if(!didStop){
        stopScan("Done");
      }
    });
  }
  void stopScan([String type = '']) {
    print(type);
    _onUpdate(BluetoothOptions.STOP_SEARCHING);
    flutterBlue.stopScan();
  }
  void destroy(){
    flutterBlue.stopScan();
    device?.disconnect();
  }
  void _connect(BluetoothDevice d) async {
    print("Connecting...");
    _onUpdate(BluetoothOptions.CONNECTING);
    device = d;
    device!.state.listen((onData) {
      if (onData == BluetoothDeviceState.disconnected && deviceConnected()) {
        print("Disconnecting From Device!");
        device?.disconnect();
        print("Device Disconnected!");
        _onUpdate(BluetoothOptions.DISCONNECTED);
        hasServices = false;
        device = null;
      }
      deviceState = onData;
    });

    device!.connect().then((error) {
      _onUpdate(BluetoothOptions.CONNECTED);
      _getServices();
    });
  }
  void _getServices() async {
    services = await device!.discoverServices();
    services.forEach((service) {
      characteristic = service.characteristics;
    });
    //_readCharacteristic();

    _onUpdate(BluetoothOptions.RECEIVED_SERVICES);
    hasServices = true;
  }
  void disconnect() {
    device?.disconnect().then((value) {
      deviceState = BluetoothDeviceState.disconnected;
      print("Device Disconnected!");
      _onUpdate(BluetoothOptions.DISCONNECTED);
      hasServices = false;
      device = null;
    });
  }
  void getBleData() {
    _readCharacteristic();
  }
  void _readCharacteristic() async{
    BluetoothCharacteristic? toSend; 
    characteristic!.forEach((char) {
      if (char.properties.notify) {
        toSend = char;
      }
    });
    List<int> value = await toSend!.read();
  }
  
  Future<List<int>> read() async{
    BluetoothCharacteristic? toSend; 
    characteristic!.forEach((char) {
      if (char.properties.notify) {
        toSend = char;
      }
    });
    return await toSend!.read();
  }
  Future<void> write(List<int> data) async{
    BluetoothCharacteristic? toSend; 
    characteristic!.forEach((char) {
      if (char.properties.write) {
        toSend = char;
      }
    });
    await toSend?.write(data);
  }
}
