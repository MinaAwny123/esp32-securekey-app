import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(MaterialApp(home: HomePage(), theme: ThemeData.dark()));

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterBlueClassic _bluetooth = FlutterBlueClassic.instance;
  List<Map<String, String>> passwords = [];
  bool connected = false;
  String status = 'Not Connected';
  
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
  }

  void scan() async {
    setState(() => status = 'Scanning...');
    
    try {
      List<dynamic> devices = await _bluetooth.getBondedDevices();
      
      for (var device in devices) {
        if (device['name'] == 'SecureKey_C3') {
          setState(() => status = 'Found device! Tap to connect');
          // Show device, let user tap to connect
          _showConnectDialog(device);
          return;
        }
      }
      
      setState(() => status = 'Device not found. Make sure it\'s paired.');
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  void _showConnectDialog(dynamic device) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Device Found'),
        content: Text('Connect to ${device['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              _connectToDevice(device);
            },
            child: Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(dynamic device) async {
    try {
      setState(() => status = 'Connecting...');
      
      await _bluetooth.connect(device['address']);
      
      setState(() {
        connected = true;
        status = 'Connected';
      });
      
      // Simulate getting password list
      // In real implementation, you'd communicate with ESP32 here
      setState(() {
        passwords = [
          {'site': 'example.com', 'user': 'user@example.com'},
          {'site': 'github.com', 'user': 'myusername'},
        ];
      });
      
    } catch (e) {
      setState(() => status = 'Connection failed: $e');
    }
  }

  void sendCmd(String cmd) {
    if (connected) {
      _bluetooth.write(cmd);
    }
  }

  void addPassword() {
    var siteCtrl = TextEditingController();
    var userCtrl = TextEditingController();
    var passCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Add Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: siteCtrl, decoration: InputDecoration(labelText: 'Website', border: OutlineInputBorder())),
            SizedBox(height: 10),
            TextField(controller: userCtrl, decoration: InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
            SizedBox(height: 10),
            TextField(controller: passCtrl, decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder()), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (siteCtrl.text.isNotEmpty && userCtrl.text.isNotEmpty && passCtrl.text.isNotEmpty) {
                sendCmd('ADD|${siteCtrl.text}|${userCtrl.text}|${passCtrl.text}');
                Navigator.pop(c);
                setState(() {
                  passwords.add({'site': siteCtrl.text, 'user': userCtrl.text});
                });
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SecureKey Manager'),
        actions: [
          IconButton(
            icon: Icon(connected ? Icons.bluetooth_connected : Icons.bluetooth),
            color: connected ? Colors.green : Colors.white,
            onPressed: scan,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: connected ? Colors.green.shade700 : Colors.red.shade700,
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(connected ? Icons.check_circle : Icons.error, color: Colors.white),
                SizedBox(width: 10),
                Text(status, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: passwords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 80, color: Colors.grey),
                        SizedBox(height: 20),
                        Text(
                          connected ? 'No passwords\nTap + to add' : 'Tap Bluetooth\nto connect',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: passwords.length,
                    padding: EdgeInsets.all(8),
                    itemBuilder: (c, i) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(passwords[i]['site']![0].toUpperCase()),
                          backgroundColor: Colors.blue,
                        ),
                        title: Text(passwords[i]['site']!, style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(passwords[i]['user']!),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.login, color: Colors.green),
                              onPressed: () {
                                sendCmd('FILL|${passwords[i]['site']}');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Filling ${passwords[i]['site']}')),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                sendCmd('DELETE|${passwords[i]['site']}');
                                setState(() => passwords.removeAt(i));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: connected
          ? FloatingActionButton(onPressed: addPassword, child: Icon(Icons.add))
          : null,
    );
  }
}
