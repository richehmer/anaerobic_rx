import 'package:flutter/material.dart';
import 'package:optional/optional.dart';
import 'data.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter_blue/flutter_blue.dart';
import 'dart:math';
import 'dependency_injection.dart';
import 'devices.dart';
import 'dart:async';
import 'package:flutter_blue/flutter_blue.dart' as blue;
import 'package:rxdart/rxdart.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    Injector.configure(Flavor.MOCK);
    return new MaterialApp(
      title: 'Anaerobic Rx Demo',
      theme: new ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or press Run > Flutter Hot Reload in IntelliJ). Notice that the
        // counter didn't reset back to zero; the application is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'Anaerobic Rx Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  List<ClicksOverTime> _data = [];

  List<ClicksOverTime> _null_data = [
    ClicksOverTime(new DateTime.now(), 0),
  ];

  List<ClicksOverTime> _window = _getCurWindow();

  String _curDeviceName;

  var endHighlight;
  var startHighlight;

  var ran = new Random();

  static List<ClicksOverTime> _getCurWindow() {
    return [
      ClicksOverTime(new DateTime.now().add(new Duration(seconds: -15)), 0),
      ClicksOverTime(new DateTime.now(), 0),
    ];
  }

  final DeviceManager _deviceManager = new Injector().deviceManager;

  StreamSubscription primaryDeviceSubscription;
  StreamSubscription deviceConnectSubscription;
  StreamSubscription heartbeatSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('INIT STATE');
    _setHighlightBounds();

    primaryDeviceSubscription = _deviceManager.primaryDevice().listen((device) {
      deviceConnectSubscription?.cancel();
      heartbeatSubscription?.cancel();
      if (device.isPresent) {
        debugPrint('Primary Device Set: connecting');
        var btDevice = device.value;
        var bt = blue.FlutterBlue.instance;
        _setDeviceName(device.value.name.toString() ?? '(unnamed device)');
        deviceConnectSubscription =
            bt.connect(device.value).listen((deviceState) {
          if (deviceState == BluetoothDeviceState.connected) {
            debugPrint('Primary Device: connected');
            heartbeatSubscription = btDevice
                .discoverServices()
                .asStream()
                .map((serviceList) => serviceList.firstWhere(
                    (service) => service.uuid == blue.Guid(HR_SERVICE)))
                .map((hrService) => hrService.characteristics.firstWhere(
                    (char) => char.uuid == blue.Guid(HR_MEASUREMENT)))
                .asyncExpand((char) {
              return btDevice
                  .setNotifyValue(char, true)
                  .asStream()
                  .where((success) => success)
                  .asyncExpand((_) => btDevice.onValueChanged(char))
                  .map((valueList) => valueList[1]);
            }).listen((data) => _addValue(data));
          } else {
            debugPrint(
                "Primary Device: disconnected [${deviceState.toString()}]");
          }
        });
      } else {
        _setDeviceName(null);
      }
    });
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    deviceConnectSubscription?.cancel();
    primaryDeviceSubscription
        .cancel()
        .then((result) => debugPrint("cancelled sub!"));
    heartbeatSubscription?.cancel();

    super.dispose();
  }

  void _setDeviceName(String name) {
    setState(() {
      _curDeviceName = name;
    });
  }

  void _addValue(int val) {
    debugPrint('adding value ' + val.toString());
    setState(() {
      _setHighlightBounds();
      _data.add(ClicksOverTime(new DateTime.now(), val));
      if (_data.length > 90) {
        //_data.removeLast();
      }

      _counter = val;
      _window = _getCurWindow();
    });
  }

  void _setHighlightBounds() {
    endHighlight = DateTime.now();
    startHighlight = endHighlight.add(Duration(seconds: -30));
  }

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
      _data.removeAt(0);
      _data.removeAt(0);
      _data.removeAt(0);
      _data.removeAt(0);
      _data.removeAt(0);
      _data.removeAt(0);
      _data.removeAt(0);
      //_data.insert(0, new ClicksOverTime(DateTime.now().add(Duration(days:-3)), 30));
//      _data.insert(0,ClicksOverTime(new DateTime.now(), ran.nextInt(100)));
//      if (_data.length > 30) {
//        _data.removeLast();
//      }
//
//      _window = _getCurWindow();
    });
  }

  void _selectDevice() {
    _deviceManager.setPrimaryDevice(null);
    Navigator.push(context,
        new MaterialPageRoute(builder: (context) => new DevicesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    var sampleData = [
      charts.Series<ClicksOverTime, DateTime>(
        id: 'Sales',
        colorFn: (dynamic _, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (ClicksOverTime clicks, _) => clicks.time,
        measureFn: (ClicksOverTime clicks, _) => clicks.value,
        overlaySeries: true,
        data: _data.length > 0 ? _data : _null_data,
      ),
//      charts.Series<ClicksOverTime, DateTime>(
//        id: 'Window',
//        domainFn: (ClicksOverTime clicks, _) => clicks.time,
//        measureFn: (ClicksOverTime clicks, _) => 0,
//        data: _window,
//      )
    ];

debugPrint('start range '+startHighlight.toString());

    var lineChart = new charts.TimeSeriesChart(sampleData,
        animate: true,

        // Provide a tickProviderSpec which does NOT require that zero is
        // included.
        primaryMeasureAxis: new charts.NumericAxisSpec(
            tickProviderSpec: new charts.BasicNumericTickProviderSpec(
                zeroBound: false, desiredMinTickCount: 4)),
        //domainAxis: new charts.DateTimeAxisSpec(),
//        secondaryMeasureAxis: new charts.DateTimeAxisSpec(
//          tickProviderSpec:
//              new charts.AutoDateTimeTickProviderSpec(includeTime: true),
        behaviors: [
          new charts.RangeAnnotation([
            new charts.RangeAnnotationSegment(
                startHighlight,
                endHighlight,
                charts.RangeAnnotationAxisType.domain,
                color: charts.MaterialPalette.cyan.shadeDefault),
          ]),
        ]);
    var chartwidget = Padding(
        padding: EdgeInsets.all(32.0),
        child: SizedBox(
          height: 200.0,
          child: lineChart,
        ));

    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return new Scaffold(
      appBar: new AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: new Text(widget.title),
      ),
      body: new Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: new Column(
          // Column is also layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug paint" (press "p" in the console where you ran
          // "flutter run", or select "Toggle Debug Paint" from the Flutter tool
          // window in IntelliJ) to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            new ListTile(
              leading: new Icon(Icons.bluetooth),
              title:
                  new Text(_curDeviceName ?? 'Heartrate device not configured'),
              subtitle: new Text(_curDeviceName == null
                  ? 'Tap to connect via bluetooth'
                  : 'Tap to connect to a different HR monitor'),
              onTap: _selectDevice,
            ),
            new Divider(),
            new Text(
              'This is your heart rate:',
            ),
            new Text(
              '$_counter',
              style: Theme.of(context).textTheme.display1,
            ),
            chartwidget,
          ],
        ),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: new Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
