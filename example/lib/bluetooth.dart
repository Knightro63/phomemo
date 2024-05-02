import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BluetoothOptions {
  searching,
  connecting,
  connected,
  receivedServices,
  disconnected,
  dataReceived,
  stopSearching
}

typedef BluetoothCallback = void Function(BluetoothOptions options);

class Bluetooth {
  Bluetooth({
    BluetoothCallback? onUpdate,
    List<Guid>? services,
    this.names
  }) {
    guid = services ?? [];
    if(onUpdate != null){
      _callbacks.add(onUpdate);
    }
    FlutterBluePlus.adapterState.listen((onData) {
      state = onData;
    });
  }

  List<String>? names;
  List<Guid> guid = [];

  List<BluetoothCallback> _callbacks = [];
  BluetoothConnectionState deviceState = BluetoothConnectionState.disconnected;
  BluetoothAdapterState state = BluetoothAdapterState.unknown;

  FlutterBluePlus flutterBlue = FlutterBluePlus();

  BluetoothDevice? device;
  List<BluetoothCharacteristic>? characteristic;
  List<ScanResult>? scanResults;
  List<BluetoothService> services = [];

  bool hasDevices = false;
  bool hasServices = false;
  bool get isScanning => subscription != null;
  Timer? timer;

  StreamSubscription<List<ScanResult>>? subscription;

  bool deviceConnected() {
    return (deviceState == BluetoothConnectionState.connected);
  }
  void addCallback(BluetoothCallback callback){
    _callbacks.add(callback);
  }
  void _onUpdate(BluetoothOptions option){
    for(int i = 0; i < _callbacks.length; i++){
      _callbacks[i].call(option);
    }
  }
  void startScan() {
    print("Starting Scan on App Bar");
    if (state == BluetoothAdapterState.on) {
      _btScan();
    }
  }
  void _btScan() async{
    if(subscription == null){
      print("Scanning");
      bool allowScan = true;
      bool didStop = false;
      _onUpdate(BluetoothOptions.searching);
      subscription = FlutterBluePlus.scanResults.listen(
        (scanResult) {
          if(allowScan && scanResult.isNotEmpty){
            if(guid.isNotEmpty){
              scanResults = scanResult;
              stopScan("Connecting Guid");
              _connect(scanResult[0].device);
              didStop = true;
              allowScan = false;
            }
            else if(names != null){
              for(int i = 0; i < names!.length;i++){
                if(scanResult[0].device.platformName.toLowerCase() == names![i].toLowerCase()){
                  scanResults = scanResult;
                  stopScan("Connecting Name");
                  _connect(scanResult[0].device);
                  allowScan = false;
                  didStop = true;
                  break;
                }
              }
            }
            else{
              print(scanResult[0].device.platformName);
              allowScan = false;
            }
          }
        }, onDone: () {
          if(!didStop){
            stopScan("Done");
          }
          subscription?.cancel();
          subscription = null;
          _onUpdate(BluetoothOptions.stopSearching);
        },
        onError: (e){
          print(e);
        }
      );
      const Duration d = Duration(minutes: 2);
      FlutterBluePlus.cancelWhenScanComplete(subscription!);
      FlutterBluePlus.startScan(
        timeout: d,
        androidUsesFineLocation: true,
        withNames: names ?? [],
        withServices: guid
      );

      timer = Timer(d, stopScan);
    }
  }
  void stopScan([String type = '']) {
    timer?.cancel();
    timer = null;
    print('STOPSCAN:$type');
    subscription?.cancel();
    subscription = null;
    _onUpdate(BluetoothOptions.stopSearching);
    FlutterBluePlus.stopScan();
  }
  void _connect(BluetoothDevice d) async {
    _onUpdate(BluetoothOptions.connecting);
    device = d;
    device!.connectionState.listen((onData) {
      if (onData == BluetoothConnectionState.disconnected && deviceConnected()) {
        print("Disconnecting From Device!");
        device?.disconnect();
        print("Device Disconnected!");
        _onUpdate(BluetoothOptions.disconnected);
        hasServices = false;
        device = null;
      }
      deviceState = onData;
    });

    device!.connect().then((error) {
      _onUpdate(BluetoothOptions.connected);
      _getServices();
    });
  }
  void _getServices() async {
    services = await device!.discoverServices();
    services.forEach((service) {
      characteristic = service.characteristics;
    });
    //_readCharacteristic();

    _onUpdate(BluetoothOptions.receivedServices);
    hasServices = true;
  }
  void disconnect() {
    device?.disconnect().then((value) {
      deviceState = BluetoothConnectionState.disconnected;
      print("Device Disconnected!");
      _onUpdate(BluetoothOptions.disconnected);
      hasServices = false;
      device = null;
    });
  }
  void dispose(){
    stopScan();
    disconnect();
  }
  void getBleData() {
    _readCharacteristic();
  }
  void _readCharacteristic() async{
    List<int> value = await read();
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
      //print(char.properties);
      if (char.properties.write) {
        toSend = char;
      }
    });
    await toSend?.write(data);
  }
}
