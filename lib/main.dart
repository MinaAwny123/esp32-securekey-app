import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(MaterialApp(home: HomePage(), theme: ThemeData.dark()));

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BluetoothCharacteristic? _char;
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
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 10));
      
      FlutterBluePlus.scanResults.listen((results) async {
        for (var r in results) {
          if (r.device.name == 'SecureKey_C3') {
            await FlutterBluePlus.stopScan();
            await _connectToDevice(r.device);
            return;
          }
        }
      });
      
      await Future.delayed(Duration(seconds: 10));
      if (!connected) {
        setState(() => status = 'Device not found');
      }
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      setState(() => status = 'Connecting...');
      await device.connect();
      
      List<BluetoothService> services = await device.discoverServices();
      
      for (var s in services) {
        if (s.uuid.toString().toLowerCase().contains('4fafc201')) {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toLowerCase().contains('beb5483e')) {
              _char = c;
              await c.setNotifyValue(true);
              
              c.value.listen((v) {
                if (v.isNotEmpty) {
                  var msg = utf8.decode(v);
                  if (msg.startsWith('LIST|')) parsePasswords(msg.substring(5));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), duration: Duration(seconds: 2))
                  );
                }
              });
              
              setState(() {
                connected = true;
                status = 'Connected';
              });
              sendCmd('LIST');
              return;
            }
          }
        }
      }
    } catch (e) {
      setState(() => status = 'Connection failed: $e');
    }
  }

  void parsePasswords(String data) {
    var items = data.split(';');
    List<Map<String, String>> temp = [];
    for (var item in items) {
      if (item.trim().isNotEmpty) {
        var parts = item.split(',');
        if (parts.length >= 2) {
          temp.add({'site': parts[0].trim(), 'user': parts[1].trim()});
        }
      }
    }
    setState(() => passwords = temp);
  }

  void sendCmd(String cmd) {
    if (_char != null) _char!.write(utf8.encode(cmd));
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
                              onPressed: () => sendCmd('FILL|${passwords[i]['site']}'),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => sendCmd('DELETE|${passwords[i]['site']}'),
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
