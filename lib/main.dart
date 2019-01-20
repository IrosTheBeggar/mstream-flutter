import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'player_widget.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'server.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path/path.dart' as path;

typedef void OnError(Exception exception);

const kUrl1 = 'http://www.rxlabz.com/labz/audio.mp3';
const kUrl2 = 'http://www.rxlabz.com/labz/audio2.mp3';
String tabText = 'File Explorer';

// var queueList = [];

List<Server> serverList = new List();
int currentServer = -1;

Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<File> get _serverFile async {
  final path = await _localPath;
  return File('$path/servers.json');
}

Future<File> writeServerFile() async {
  final file = await _serverFile;

  // Write the file
  return file.writeAsString(jsonEncode(serverList));
}

void main() {
  runApp(new MaterialApp(home: new ExampleApp()));
}

class ExampleApp extends StatefulWidget {
  @override
  _ExampleAppState createState() => new _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> with SingleTickerProviderStateMixin {
  AudioCache audioCache = new AudioCache();
  AudioPlayer advancedPlayer = new AudioPlayer();
  String localFilePath;

  TabController _tabController;

  List displayList = new List();

  Future _loadFile() async {
    final bytes = await http.readBytes(kUrl1);
    final dir = await getApplicationDocumentsDirectory();
    final file = new File('${dir.path}/audio.mp3');

    await file.writeAsBytes(bytes);
    if (await file.exists()) {
      setState(() {
        localFilePath = file.path;
      });
    }
  }

  Widget _tab(List<Widget> children) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(0.0),
        child: Column(
          children: children
              .map((w) => Container(child: w, padding: EdgeInsets.all(6.0)))
              .toList(),
        ),
      ),
    );
  }

  Widget _btn(String txt, VoidCallback onPressed) {
    return ButtonTheme(
        minWidth: 48.0,
        child: RaisedButton(child: Text(txt), onPressed: onPressed));
  }

  // Loal File Screen
  Widget localFile() {
    return new Column(children: <Widget>[
      new Row(children: <Widget>[
        new IconButton(icon: Icon(Icons.arrow_back), tooltip: 'Go Back', onPressed: () {
          print('BACK');
        }),
        Expanded(child: TextField(decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search'
        )))
      ]),
      Expanded(
        child: SizedBox(
          child: new ListView.builder( // LOL Holy Shit: https://stackoverflow.com/questions/52801201/flutter-renderbox-was-not-laid-out
            physics: const AlwaysScrollableScrollPhysics (),
            itemCount: displayList.length,
            itemBuilder: (BuildContext context, int index) {
              print('XXX');
              print(displayList[index]);
              return new ListTile(
                title: Text(displayList[index]['name'].toString()),
                onTap: () {
                  print(displayList[index]['directory']);
                  if(displayList[index]['type'] == 'directory') {
                    getFileList(displayList[index]['directory']);
                  }

                  if(displayList[index]['type'] == 'addServer') {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AddServerScreen()), );
                  }
                },
              );
            }
          )
        )
      )
    ]);
  }

  Future<void> getFileList(String directory) async {
    setState(() {
      tabText = 'File Explorer';
    });

    if (currentServer < 0) {
      Fluttertoast.showToast(
        msg: "No Server Selected",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIos: 2,
        backgroundColor: Colors.orange,
        textColor: Colors.white
      );
      return;      
    }

    Uri currentUri = Uri.parse(serverList[currentServer].url);
    String url = currentUri.resolve('/dirparser').toString();
    var response = await http.post(url, body: {"dir": directory},  headers: { 'x-access-token': serverList[currentServer].jwt});

    if (response.statusCode > 299) {
      Fluttertoast.showToast(
        msg: "Call Failed",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIos: 1,
        backgroundColor: Colors.orange,
        textColor: Colors.white
      );
      return;   
    }

    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");
    var res = jsonDecode(response.body);
    print(res['contents']);
    displayList.clear();
    res['contents'].forEach((e) {
      print(e);
      setState(() {
        displayList.add({
          'type': e['type'],
          'name': e['name'],
          'directory': path.join(res['path'], e['name'])
        });
      });
    });
  }

  Future<void> getPlaylists() async {
    setState(() {
      tabText = 'Playlists';
    });

    if (currentServer < 0) {
      Fluttertoast.showToast(
        msg: "No Server Selected",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIos: 1,
        backgroundColor: Colors.orange,
        textColor: Colors.white
      );
      return;      
    }

    Uri currentUri = Uri.parse(serverList[currentServer].url);
    String url = currentUri.resolve('/playlist/getall').toString();
    print(serverList[currentServer].jwt);
    var response = await http.get(url, headers: { 'x-access-token': serverList[currentServer].jwt});

    if (response.statusCode > 299) {
      Fluttertoast.showToast(
        msg: "Call Failed",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIos: 2,
        backgroundColor: Colors.orange,
        textColor: Colors.white
      );
      return;   
    }

    var res = jsonDecode(response.body);
    displayList.clear();
    res.forEach((e) {
      print(e);
      setState(() {
        displayList.add({
          'type': 'playlist',
          'name': e['name']
        });
      });
    });
  }

  // Advanced Screen
  Widget advanced() {
    return _tab([
      Column(children: [
        Text('Source Url'),
        Row(children: [
          _btn('Audio 1', () => advancedPlayer.setUrl(kUrl1)),
          _btn('Audio 2', () => advancedPlayer.setUrl(kUrl2)),
        ], mainAxisAlignment: MainAxisAlignment.spaceEvenly),
      ]),
      Column(children: [
        Text('Release Mode'),
        Row(children: [
          _btn('STOP', () => advancedPlayer.setReleaseMode(ReleaseMode.STOP)),
          _btn('LOOP', () => advancedPlayer.setReleaseMode(ReleaseMode.LOOP)),
          _btn('RELEASE',
              () => advancedPlayer.setReleaseMode(ReleaseMode.RELEASE)),
        ], mainAxisAlignment: MainAxisAlignment.spaceEvenly),
      ]),
      new Column(children: [
        Text('Volume'),
        Row(children: [
          _btn('0.0', () => advancedPlayer.setVolume(0.0)),
          _btn('0.5', () => advancedPlayer.setVolume(0.5)),
          _btn('1.0', () => advancedPlayer.setVolume(1.0)),
          _btn('2.0', () => advancedPlayer.setVolume(2.0)),
        ], mainAxisAlignment: MainAxisAlignment.spaceEvenly),
      ]),
      new Column(children: [
        Text('Control'),
        Row(children: [
          _btn('resume', () => advancedPlayer.resume()),
          _btn('pause', () => advancedPlayer.pause()),
          _btn('stop', () => advancedPlayer.stop()),
          _btn('release', () => advancedPlayer.release()),
        ], mainAxisAlignment: MainAxisAlignment.spaceEvenly),
      ]),
      // End of Advanced Player

      // // Other Examples
      // Text('Play Local Asset \'audio.mp3\':'),
      // _btn('Play', () => audioCache.play('audio.mp3')),
      // Text('File: $kUrl1'),
      // _btn('Download File to your Device', () => _loadFile()),
      // // Text('Current local file path: $localFilePath'),
      // localFilePath == null
      //     ? Container()
      //     : PlayerWidget(url: localFilePath, isLocal: true),
    ]);
  }

  Future<List>  readServerList() async {
    try {
      final file = await _serverFile;

      // Read the file
      String contents = await file.readAsString();
      return jsonDecode(contents);
    } catch (e) {
      // If we encounter an error, return 0
      return [];
    }
  }


  @override
  void initState() {
    super.initState();
    _tabController = new TabController(vsync: this, length: 2);

    // Load Servers
    readServerList().then((List contents) {
      print(contents);
      // contents = []; // TODO: Remove this later
      contents.forEach((f) {
        print(f);
        var newServer = Server.fromJson(f);
        setState(() {
          serverList.add(newServer);
        });
      });

      print(serverList);

      if (serverList.length > 0) {
        currentServer = 0;
      } else {
        // Navigator.push(context, MaterialPageRoute(builder: (context) => AddServerScreen()), );
        setState(() {
          displayList.add({
            'type': 'addServer',
            'name': 'Welcome To mStream!'
          });
          displayList.add({
            'type': 'addServer',
            'name': 'Click here to add a server'
          });
        });
      }

      print(currentServer);

    });

    // getFileList("");

    FlutterDownloader.registerCallback((id, status, progress) {
      // TODO: Handle downlaod state
      print('Download task ($id) is in status ($status) and process ($progress)');
    });
  }


  @override
  void dispose() {
    _tabController.dispose();
    FlutterDownloader.registerCallback(null);
    super.dispose();
  }

  // Sync Functions
  Future downloadOneFile(String serverDir, String downloadUrl) async {
    serverDir = serverList[currentServer].localname; // TODO: delete this later
    // download each file relative to its path

    final bytes = await http.readBytes(downloadUrl);
    final dir = await getApplicationDocumentsDirectory();
    final file = new File('${dir.path}/${serverDir}/$downloadUrl');

    await file.writeAsBytes(bytes);
  }

  Future downloadOneFile2(String serverDir, String downloadUrl) async {
    serverDir = serverList[currentServer].localname; // TODO: delete this later
    // download each file relative to its path

    final dir = await getApplicationDocumentsDirectory();
    final taskId = await FlutterDownloader.enqueue(
      url: downloadUrl,
      savedDir: '${dir.path}/${serverDir}/$downloadUrl',
      showNotification: false, // show download progress in status bar (for Android)
      openFileFromNotification: false, // click on notification to open downloaded file (for Android)
    );

    FlutterDownloader.registerCallback((id, status, progress) {
      // code to update your UI
    });
  }

  void syncPlaylist() {
    // TODO: Do this one next
  }

  void syncDirectory() {
    // 
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Add a status bar to side menu.  Use it to display available space
    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          tabs: [
            Tab(text: tabText),
            Tab(text: 'Now Playing'),
          ],
          controller: _tabController,
        ),
        // title: Text('mStream'),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'mStream',
            ),
            Visibility(
              visible: currentServer < 0 ? false : true,
              child: Text(
                currentServer < 0 ? '' : (serverList[currentServer].nickname.length > 0 ? serverList[currentServer].nickname: serverList[currentServer].url),
                style: TextStyle(
                  fontSize: 12.0,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget> [
          new PopupMenuButton(
            onSelected: (Server selectedServer) { 
              setState(() {
                currentServer = serverList.indexOf(selectedServer);             
              });
            },
            icon: new Icon(Icons.cloud),
            itemBuilder: (BuildContext context) { 
              return serverList.map((server) {
                return new PopupMenuItem(
                  value: server,
                  child: new Text(server.nickname.length > 0 ? server.nickname : server.url, style: new TextStyle(color: Colors.black)),
                );
              }).toList();
            },
          ),
          new IconButton (
            icon: new Icon(Icons.add),
            onPressed: (){
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddServerScreen()),
              );
            }
          ),
        ]
      ),
      drawer: new Drawer(
        child: new ListView(
          children: <Widget> [
            new DrawerHeader(child: new Text('Header'),),
            new ListTile(
              title: new Text('File Explorer'),
              onTap: () {
                getFileList("");
                Navigator.of(context).pop();
                _tabController.animateTo(0);
              },
            ),
            new ListTile(
              title: new Text('Playlists'),
              onTap: () {
                getPlaylists();
                Navigator.of(context).pop();
                _tabController.animateTo(0);
              },
            ),
            new ListTile(
              title: new Text('Albums'),
              onTap: () {},
            ),
            new ListTile(
              title: new Text('Artists'),
              onTap: () {},
            ),
            new ListTile(
              title: new Text('Local Files'),
              onTap: () {},
            ),
            new ListTile(
              title: new Text('Add Server'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => AddServerScreen()), );
              },
            ),
            new Divider(),
            new ListTile(
              title: new Text('About'),
              onTap: () {},
            ),
          ],
        )
      ),
      body: TabBarView(
        children: [localFile(), advanced()],
        controller: _tabController
      ),
    );
  }
}

// Create a Form Widget
class MyCustomForm extends StatefulWidget {
  @override
  MyCustomFormState createState() {
    return MyCustomFormState();
  }
}

// Create a corresponding State class. This class will hold the data related to
// the form.
class MyCustomFormState extends State<MyCustomForm> {
  // Create a global key that will uniquely identify the Form widget and allow
  // us to validate the form
  // Note: This is a GlobalKey<FormState>, not a GlobalKey<MyCustomFormState>!
  final _formKey = GlobalKey<FormState>();
  var _url;
  var _username;
  var _password;
  var _serverName;

  checkServer() async {
    Uri lol = Uri.parse(this._url);
    String origin = lol.origin;
    var response;

    try {
      response = await http.get(lol.resolve('/ping').toString());
      print(response);
    } catch(err) {
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('Could not connect to server')));
      return;
    }

    // Check for login
    if (response.statusCode == 200) {
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('Connection Successful!')));
      saveServer(origin);
      return;
    }

    // Try logging in
    try {
      response = await http.post(lol.resolve('/login').toString(), body: {"username": this._username, "password": this._password});
      print(response);
    } catch(err) {
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('Failed to Login')));
      return;
    }

    if (response.statusCode != 200) {
      Scaffold.of(context).showSnackBar(SnackBar(content: Text('Failed to Login')));
      return;    
    }

    var res = jsonDecode(response.body);
    
    // Save
    saveServer(origin, res['token']);
  }

  saveServer(String origin, [String jwt='']) {
    Server woo = new Server(origin, this._serverName, this._username, this._password, jwt, this._serverName);
    serverList.add(woo);
    
    currentServer = serverList.length - 1;

    // Save Server List
    writeServerFile();
    Navigator.pop(context);

    print(serverList);
  }

  @override
  Widget build(BuildContext context) {
    // Build a Form widget using the _formKey we created above
    return new Container(
      padding: new EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              validator: (value) {

              },
              keyboardType: TextInputType.emailAddress,
              decoration: new InputDecoration(
                hintText: 'Server Name',
                labelText: 'Server Name'
              ),
              onSaved: (String value) {
                this._serverName = value;
              }
            ),
            TextFormField(
              validator: (value) {
                if (value.isEmpty) {
                  return 'Server URL is needed';
                }
                try {
                  var lol = Uri.parse(value);
                  if (lol.origin is Error || lol.origin.length < 1) {
                    return 'Cannot Parse URL';
                  }
                } catch(err) {
                  return 'Cannot Parse URL';
                }              
              },
              keyboardType: TextInputType.emailAddress,
              decoration: new InputDecoration(
                hintText: 'https://mstream.io',
                labelText: 'Server URL'
              ),
              onSaved: (String value) {
                this._url = value;
              }
            ),
            TextFormField(
              validator: (value) {

              },
              keyboardType: TextInputType.emailAddress,
              decoration: new InputDecoration(
                hintText: 'Username',
                labelText: 'Username'
              ),
              onSaved: (String value) {
                this._username = value;
              }
            ),
            TextFormField(
              validator: (value) {

              },
              obscureText: true, // Use secure text for passwords.
              decoration: new InputDecoration(
                hintText: 'Password',
                labelText: 'Password'
              ),
              onSaved: (String value) {
                this._password = value;
              }
            ),
            new Container(
              width: MediaQuery.of(context).size.width,
              child: new RaisedButton(
                child: new Text(
                  'Save',
                  style: new TextStyle(
                    color: Colors.white
                  ),
                ),
                onPressed: () {
                  // Validate will return true if the form is valid, or false if
                  // the form is invalid.
                  if (!_formKey.currentState.validate()) {
                    return;
                  }

                  _formKey.currentState.save(); // Save our form now.

                  // Ping server
                  print(this._url);
                  checkServer();
                },
                color: Colors.blue,
              ),
              margin: new EdgeInsets.only(
                top: 20.0
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddServerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Server"),
      ),
      body: MyCustomForm()
    );
  }
}
