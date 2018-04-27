import 'devices.dart';

enum Flavor { MOCK, PRO }

class Injector {
  static final Injector _singleton = new Injector._internal();

  static Flavor _flavor;

  static void configure(Flavor flavor) {
    _deviceManager = null;
    _flavor = flavor;
  }

  factory Injector() {
    return _singleton;
  }

  Injector._internal();

  static DeviceManager _deviceManager;

  DeviceManager get deviceManager {
    switch (_flavor) {
      case Flavor.MOCK:
        return _deviceManager ??= new BluetoothDeviceManager();
      default:
        throw new UnimplementedError();
    }
  }
}
