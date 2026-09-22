import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() => runApp(MaterialApp(home: HomePage(), theme: ThemeData.dark()));

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, String>> passwords = [];
  bool connected = true; // Mock connected state
  String status = 'Ready (Bluetooth in v2.0)';
  
  @override
  void initState() {
    super.initState();
    _loadPasswords();
  }

  Future<void> _loadPasswords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('passwords');
    
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      setState(() {
        passwords = decoded.map((e) => Map<String, String>.from(e)).toList();
      });
    }
  }

  Future<void> _savePasswords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('passwords', jsonEncode(passwords));
  }

  void addPassword() {
    var siteCtrl = TextEditingController();
    var userCtrl = TextEditingController();
    var passCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Add Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: siteCtrl,
                decoration: InputDecoration(
                  labelText: 'Website',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.web),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: userCtrl,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (siteCtrl.text.isNotEmpty && userCtrl.text.isNotEmpty && passCtrl.text.isNotEmpty) {
                setState(() {
                  passwords.add({
                    'site': siteCtrl.text,
                    'user': userCtrl.text,
                    'pass': passCtrl.text,
                  });
                });
                _savePasswords();
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password added!')),
                );
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void deletePassword(int index) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete Password'),
        content: Text('Delete password for ${passwords[index]['site']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => passwords.removeAt(index));
              _savePasswords();
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Password deleted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void viewPassword(int index) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(passwords[index]['site']!),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Username:', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(passwords[index]['user']!),
            SizedBox(height: 10),
            Text('Password:', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(passwords[index]['pass']!),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Close')),
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
            icon: Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text('Version 1.0'),
                  content: Text('Simple password manager.\n\nBluetooth sync with ESP32 coming in v2.0!'),
                  actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text('OK'))],
                ),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.blue.shade700,
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
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
                        Icon(Icons.lock_outline, size: 100, color: Colors.grey),
                        SizedBox(height: 20),
                        Text(
                          'No passwords stored\nTap + to add one',
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
                      elevation: 3,
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                              icon: Icon(Icons.visibility, color: Colors.blue),
                              onPressed: () => viewPassword(i),
                              tooltip: 'View password',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deletePassword(i),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                        onTap: () => viewPassword(i),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addPassword,
        child: Icon(Icons.add),
        tooltip: 'Add password',
      ),
    );
  }
}
