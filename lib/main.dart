// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:wifi_scan/wifi_scan.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'PoC Wifi Connect'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ssidController = TextEditingController(text: 'CodeApp');
  final passwordController = TextEditingController(text: '9code7app9');

  String? wifiName;
  String? connectResult;
  int _retryConnection = 0;

  @override
  initState() {
    _fetchNetworkInfo();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Current Wifi: $wifiName'),
              TextField(
                controller: ssidController,
                decoration: const InputDecoration(labelText: 'SSID'),
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (connectResult != null) ...[
                const SizedBox(height: 16),
                Text('Connect Result: $connectResult'),
              ]
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => connect(),
        tooltip: 'Increment',
        child: const Icon(Icons.send),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<void> _fetchNetworkInfo() async {
    try {
      final wifiName = await WiFiForIoTPlugin.getSSID();

      setState(() {
        this.wifiName = wifiName;
      });
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future<void> connect() async {
    try {
      setState(() {
        connectResult = 'Connecting';
      });

      final isSuccess = await _connectForAndroid(
        ssid: ssidController.text,
        password: passwordController.text,
      );

      if (isSuccess) _fetchNetworkInfo();

      setState(() {
        connectResult = isSuccess ? 'Success' : 'Error';
      });
    } catch (e) {
      setState(() {
        connectResult = e.toString();
      });
    }
  }

  Future<bool> _connectForAndroid({
    required String ssid,
    required String password,
  }) async {
    try {
      final permissions = await WiFiScan.instance.canStartScan();

      if (permissions == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        await WiFiForIoTPlugin.removeWifiNetwork(ssid);

        final bssid = await WiFiScan.instance.getScannedResults().then(
              (accessPoints) => accessPoints
                  .firstWhereOrNull((accessPoint) => accessPoint.ssid == ssid)
                  ?.bssid,
            );
        final isSuccess = await WiFiForIoTPlugin.findAndConnect(
          ssid,
          bssid: bssid,
          password: password,
        );

        if (isSuccess || _retryConnection >= 2) {
          _retryConnection = 0;
          return Future.value(isSuccess);
        } else {
          _retryConnection += 1;
          return await _connectForAndroid(ssid: ssid, password: password);
        }
      } else {
        throw Exception(permissions.toString());
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> _connectForIOS() async {
    try {
      await WiFiForIoTPlugin.disconnect();

      return WiFiForIoTPlugin.connect(
        ssidController.text,
        password: passwordController.text,
        joinOnce: false,
        security: NetworkSecurity.WPA,
      );
    } catch (e) {
      rethrow;
    }
  }
}
