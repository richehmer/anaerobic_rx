import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'dependency_injection.dart';
import 'dart:async';
import 'package:flutter_blue/flutter_blue.dart' as blue;
import 'package:optional/optional.dart';

class DevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Second Screen"),
      ),
      body: new DevicesList(),
    );
  }
}

class DevicesList extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return new _DevicesListState();
  }
}

class _DevicesListState extends State<DevicesList> {
  bool _loading = true;

  final DeviceManager _deviceManager = new Injector().deviceManager;

  List<blue.ScanResult> _devices = [];

  StreamSubscription<List<blue.ScanResult>> subscription;

  @override
  void initState() {
    super.initState();
    subscription = _deviceManager.devices().stream.toList().asStream().listen(
        (List<blue.ScanResult> events) {
      setState(() {
        _loading = false;
        _devices.addAll(events);
      });
    }, onDone: () {});
  }

  @override
  void dispose() {
    subscription.cancel().then((value) => debugPrint('disposed bluetoothsearch!'));
    super.dispose();
  }

  _processTap(blue.ScanResult tappedResult) {
    debugPrint("tapped: " + tappedResult.advertisementData.localName);
    _deviceManager.setPrimaryDevice(tappedResult.device);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _devices.length == 0) {
      return new Center(
          child: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          new CircularProgressIndicator(),
        ],
      ));
    } else {
      return new ListView.builder(
          itemCount: _devices.length,
          shrinkWrap: true,
          padding: const EdgeInsets.all(20.0),
          itemBuilder: (BuildContext context, int index) {
            return new DeviceListItem(_devices[index],
                onTap: () => _processTap(_devices[index]));
          });
    }
  }
}

abstract class DeviceManager {
  Observable<blue.ScanResult> devices();

  Observable<int> connect(blue.BluetoothDevice device);

  Stream<int> connectStream(blue.BluetoothDevice device);

  Observable<Optional<blue.BluetoothDevice>> primaryDevice();

  void setPrimaryDevice(blue.BluetoothDevice device);
}

abstract class BluetoothItem {
  String describe();

  blue.BluetoothDevice device();
}

const String HR_SERVICE = '0000180D-0000-1000-8000-00805f9b34fb';
const String HR_MEASUREMENT = '00002a37-0000-1000-8000-00805f9b34fb';

class DeviceListItem extends ListTile {
  DeviceListItem(blue.ScanResult device, {GestureTapCallback onTap})
      : super(title: new Text(_describe(device)), onTap: onTap);

  static String _describe(blue.ScanResult result) {
    var data = result.advertisementData;
    return (data.localName != '' ? data.localName.toString() : '<unnamed>') +
        ' rssi: ${result.rssi}' +
        ' uuid' +
        result.device.id.toString();
  }
}

class BluetoothDeviceManager extends DeviceManager {
  BehaviorSubject<Optional<blue.BluetoothDevice>> primaryDeviceSubject =
      new BehaviorSubject<Optional<blue.BluetoothDevice>>(
          seedValue: Optional.empty());

  @override
  Observable<blue.ScanResult> devices() {
    var bt = blue.FlutterBlue.instance;
    return new Observable(bt.scan(
      withServices: [blue.Guid(HR_SERVICE)],
      timeout: const Duration(seconds: 6),
    )).distinctUnique(equals: (a, b) {
      var firstId = a.device.id.toString();
      var secondId = b.device.id.toString();
      return firstId == secondId;
    }, hashCode: (result) {
      return result.device.id.hashCode;
    });
  }

  @override
  void setPrimaryDevice(blue.BluetoothDevice device) {
    primaryDeviceSubject.add(Optional.ofNullable(device));
  }

  @override
  Observable<Optional<blue.BluetoothDevice>> primaryDevice() {
    return primaryDeviceSubject.stream;
  } //  @override

  @override
  Observable<int> connect(blue.BluetoothDevice btDevice) {
    var bt = blue.FlutterBlue.instance;
    debugPrint('connecting to device...');
    return Observable(bt.connect(btDevice)).switchMap((deviceState) {
      debugPrint('device state: ' + deviceState.toString());
      if (deviceState == blue.BluetoothDeviceState.connected) {
        return Observable(btDevice.discoverServices().asStream())
            .flatMap((services) => Observable.fromIterable(services))
            .where((service) => service.uuid == blue.Guid(HR_SERVICE))
            .switchIfEmpty(Observable.error('HR Service missing'))
            .flatMap((svc) => Observable.fromIterable(svc.characteristics))
            .where((cha) => cha.uuid == blue.Guid(HR_MEASUREMENT))
            .switchIfEmpty(Observable.error('HR Measurement missing'))
            .flatMap((char) {
              return Observable
                  .fromFuture(btDevice.setNotifyValue(char, true))
                  .where((success) => success)
                  .concatMap((_) => btDevice.onValueChanged(char))
                  .doOnDone(() => debugPrint("doOnDone, request stop notif"))
                  .doOnError(() => debugPrint("doOnError"))
                  .doOnCancel(() => debugPrint("doOnCancel"))
                  .map((valueList) {
                //debugPrint('new values: ' + valueList.toString());
                return valueList[1];
              });
            })
            .doOnDone(() => debugPrint('stream done!'))
            .doOnError((error) {
              debugPrint("problem streaming HR: " + error.toString());
            });
      } else {
        return Observable.empty();
      }
    });
  }

  @override
  Stream<int> connectStream(blue.BluetoothDevice btDevice) {
    var bt = blue.FlutterBlue.instance;
    return bt
        .connect(btDevice)
        .skipWhile((state) => state != blue.BluetoothDeviceState.connected)
        .asyncExpand((_) => btDevice.discoverServices().asStream())
        .map((serviceList) => serviceList
            .firstWhere((service) => service.uuid == blue.Guid(HR_SERVICE)))
        .map((hrService) => hrService.characteristics
            .firstWhere((char) => char.uuid == blue.Guid(HR_MEASUREMENT)))
        .asyncExpand((char) {
          debugPrint("async expand");
      return btDevice
          .setNotifyValue(char, true)
          .asStream()
          .where((success) => success)
          .asyncExpand((_) => btDevice.onValueChanged(char))
          .map((valueList) => valueList[1]);
    });
  }
}
