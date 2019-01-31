import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'objects/server.dart';
import 'objects/display_item.dart';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path/path.dart' as path;

import 'mstream_player.dart';
import 'objects/queue_item.dart';

typedef void OnError(Exception exception);

final List<List<DisplayItem>> displayCache = new List();
final List<DisplayItem> displayList = new List();
final List<Server> serverList = new List();
String tabText = 'File Explorer';
int currentServer = -1;
Map playlists = {};

int editThisServer;
final ValueNotifier redrawServerFlag = ValueNotifier(false);
final ValueNotifier redrawPlaylistFlag = ValueNotifier(false);
// final ValueNotifier positionBar = ValueNotifier();

MstreamPlayer mStreamAudio = new MstreamPlayer();

Future<File> get _serverFile async {
  final directory = await getApplicationDocumentsDirectory();
  final path = directory.path;
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
  TabController _tabController;
  String localFilePath;

  _setState() {
    setState(() {});
  }

  _goToNavScreen() {
    _tabController.animateTo(0);
    tabText = 'Go To';
    
    displayCache.clear();
    displayList.clear();
    List<DisplayItem> newList = new List();
    DisplayItem newItem1 = new DisplayItem(serverList[currentServer], 'File Explorer', 'execAction', 'fileExplorer',  new Icon(Icons.folder), null);
    DisplayItem newItem2 = new DisplayItem(serverList[currentServer], 'Playlists', 'execAction', 'playlists',  new Icon(Icons.queue_music), null);
    DisplayItem newItem3 = new DisplayItem(serverList[currentServer], 'Albums', 'execAction', 'albums',  new Icon(Icons.album), null);
    DisplayItem newItem4 = new DisplayItem(serverList[currentServer], 'Artists', 'execAction', 'artists',  new Icon(Icons.library_music), null);
    displayList.add(newItem1);
    newList.add(newItem1);
    displayList.add(newItem2);
    newList.add(newItem2);
    displayList.add(newItem3);
    newList.add(newItem3);
    displayList.add(newItem4);
    newList.add(newItem4);
    displayCache.add(newList);
  }

  Widget advanced() {
    return new Column(children: <Widget>[
      new Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: [
              IconButton(icon: Icon(Icons.save), onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => SavePlaylistScreen()));
              }),
              IconButton(icon: Icon(Icons.share), onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ShareScreen()));
              }),
            ]
          ),
          Row(
            children: [
              IconButton(icon: Icon(Icons.cancel), color: Colors.redAccent, onPressed: () {
                setState(() {
                  mStreamAudio.clearPlaylist();
                });
              },),
            ]
          )
        ]
      ),
      Expanded(
        child: SizedBox(
          child: new ListView.builder(
            physics: const AlwaysScrollableScrollPhysics (),
            itemCount: mStreamAudio.playlist.length,
            itemBuilder: (BuildContext context, int index) {
              return  Dismissible(
                key: Key(mStreamAudio.playlist[index].uuidString),
                onDismissed: (direction) {
                  setState(() {
                    mStreamAudio.removeSongAtPosition(index);
                  });
                },
                child:  Container(
                  color: (index == mStreamAudio.positionCache) ? Colors.orange : null,
                  child: new ListTile(
                    leading: new Icon(Icons.music_note),
                    title: Text(mStreamAudio.playlist[index].filename),
                    onTap: () {
                      setState(() {
                        mStreamAudio.goToSongAtPosition(index);
                      });
                    }
                  )
                )
              );
            }
          )
        ),
      )
    ]);
  }

  // Load File Screen
  Widget localFile() {
    return new Column(children: <Widget>[
      new Row(children: <Widget>[
        new IconButton(icon: Icon(Icons.arrow_back), tooltip: 'Go Back', onPressed: () {
          if(displayCache.length > 1) {
            displayCache.removeLast();
            displayList.length = 0;
            List<DisplayItem> newList = displayCache[displayCache.length - 1];
            newList.forEach((e){
              displayList.add(e);
            });
            setState(() {});
          }
        }),
        new IconButton(icon: Icon(Icons.library_add), tooltip: 'Go Back', onPressed: () {
          displayList.forEach((element) {
            if (element.type == 'file') {
              Uri url = Uri.parse(element.server.url + '/media' + element.data + '?token=' + element.server.jwt );
              QueueItem newItem = new QueueItem(element.server, element.name, url.toString(), element.data, null, null, null, null, null, null, null, null, null);
              setState(() {
                mStreamAudio.addSong(newItem);
              });
            }
          });
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
              return new ListTile(
                leading: displayList[index].icon == null ? null : displayList[index].icon,
                title: Text(displayList[index].name),
                subtitle: displayList[index].subtext == null ? null : Text(displayList[index].subtext),
                onTap: () {
                  if(displayList[index].type == 'file') {
                    Uri url = Uri.parse(displayList[index].server.url + '/media' + displayList[index].data + '?token=' + serverList[currentServer].jwt );
                    QueueItem newItem = new QueueItem(displayList[index].server, displayList[index].name, url.toString(), displayList[index].data, null, null, null, null, null, null, null, null, null);
                    setState(() {
                      mStreamAudio.addSong(newItem);
                    });
                  }

                  if(displayList[index].type == 'album') {
                    getAlbumSongs(displayList[index].data, useThisServer: displayList[index].server);
                  }

                  if(displayList[index].type == 'artist') {
                    getArtistAlbums(displayList[index].data, useThisServer: displayList[index].server);
                  }

                  if(displayList[index].type == 'directory') {
                    getFileList(displayList[index].data, useThisServer: displayList[index].server);
                  }

                  if(displayList[index].type == 'addServer') {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AddServerScreen()), );
                  }

                  if(displayList[index].type == 'playlist') {
                    getPlaylist(displayList[index].data, useThisServer: displayList[index].server);
                  }

                  if(displayList[index].type == 'execAction' && displayList[index].data =='fileExplorer') {
                    getFileList("", wipeBackCache: false, useThisServer: displayList[index].server);                  
                  }
                  if(displayList[index].type == 'execAction' && displayList[index].data =='playlists') {
                    getPlaylists(wipeBackCache: false, useThisServer: displayList[index].server);
                  }
                  if(displayList[index].type == 'execAction' && displayList[index].data =='artists') {
                    getArtists(wipeBackCache: false, useThisServer: displayList[index].server);
                  }
                  if(displayList[index].type == 'execAction' && displayList[index].data =='albums') {
                    getAllAlbums(wipeBackCache: false, useThisServer: displayList[index].server);
                  }
                },
              );
            }
          )
        )
      )
    ]);
  }

  Future _makeServerCall(Server useThisServer, String location, Map payload, String getOrPost, bool wipeBackCache) async {
    if (useThisServer == null && currentServer < 0) {
      Fluttertoast.showToast(
        msg: "No Server Selected",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIos: 2,
        backgroundColor: Colors.orange,
        textColor: Colors.white
      );
      return null;      
    }

    Uri currentUri = Uri.parse(useThisServer.url);
    String url = currentUri.resolve(location).toString();
    var response;
    if(getOrPost == 'GET') {
      response = await http.get(url, headers: { 'x-access-token': useThisServer.jwt});
    }else {
      response = await http.post(url, body: payload,  headers: { 'x-access-token': useThisServer.jwt});
    }

    if (response.statusCode > 299) {
      Fluttertoast.showToast(
        msg: "Call Failed",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIos: 1,
        backgroundColor: Colors.orange,
        textColor: Colors.white
      );
      return null;   
    }

    var res = jsonDecode(response.body);
    if(wipeBackCache) {
      displayCache.clear();
      List<DisplayItem> newList = new List();
      newList.add(new DisplayItem(useThisServer, 'File Explorer', 'execAction', 'fileExplorer',  new Icon(Icons.folder), null));
      newList.add(new DisplayItem(useThisServer, 'Playlists', 'execAction', 'playlists',  new Icon(Icons.queue_music), null));
      newList.add(new DisplayItem(useThisServer, 'Albums', 'execAction', 'albums',  new Icon(Icons.album), null));
      newList.add(new DisplayItem(useThisServer, 'Artists', 'execAction', 'artists',  new Icon(Icons.library_music), null));
      displayCache.add(newList);
    }

    return res;
  }

  Future<void> getFileList(String directory, {bool wipeBackCache = false, Server useThisServer}) async {
    setState(() => tabText = 'File Explorer');

    if(useThisServer == null) {
      useThisServer = serverList[currentServer];
    }

    var res = await _makeServerCall(useThisServer, '/dirparser', {"dir": directory}, 'POST', wipeBackCache);

    displayList.clear();
    List<DisplayItem> newList = new List();
    res['contents'].forEach((e) {
      Icon thisIcon = e['type'] == 'directory' ? Icon(Icons.folder) : Icon(Icons.music_note);
      var thisType = (e['type'] == 'directory') ? 'directory' : 'file';
      DisplayItem newItem = new DisplayItem(useThisServer, e['name'], thisType, path.join(res['path'], e['name']), thisIcon, null);
      displayList.add(newItem);
      newList.add(newItem);
    });
    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getArtists( {bool wipeBackCache = false, Server useThisServer}) async {
    setState(() => tabText = 'Artists');


    if(useThisServer == null) {
      useThisServer = serverList[currentServer];
    }

    var res = await _makeServerCall(useThisServer, '/db/artists', null, 'GET', wipeBackCache);

    displayList.clear();
    List<DisplayItem> newList = new List();
    res['artists'].forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e, 'artist', e, Icon(Icons.library_music), null);
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getArtistAlbums(String artist, {bool wipeBackCache = false, Server useThisServer}) async {
    if(useThisServer == null) {
      useThisServer = serverList[currentServer];
    }
    var res = await _makeServerCall(useThisServer, '/db/artists-albums', {"artist": artist}, 'POST', wipeBackCache);

    displayList.clear();
    List<DisplayItem> newList = new List();
    res['albums'].forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e['name'], 'album', e['name'], Icon(Icons.album), null);
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getAlbumSongs(String album, {bool wipeBackCache = false, Server useThisServer}) async {
    setState(() => tabText = 'Albums');
    if(useThisServer == null) {
      useThisServer = serverList[currentServer];
    }

    var res = await _makeServerCall(useThisServer, '/db/album-songs', {"album": album}, 'POST', wipeBackCache);

    displayList.clear();
    List<DisplayItem> newList = new List();
    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e['filepath'], 'file', '/' + e['filepath'], Icon(Icons.music_note), null);
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getAllAlbums({bool wipeBackCache = false, Server useThisServer}) async {
    setState(() => tabText = 'Albums');
    if(useThisServer == null) {
      useThisServer = serverList[currentServer];
    }

    var res = await _makeServerCall(useThisServer, '/db/albums', null, 'GET', wipeBackCache);

    displayList.clear();
    List<DisplayItem> newList = new List();
    res['albums'].forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e['name'], 'album', e['name'], Icon(Icons.album), null);
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  // TODO: 
  Future<void> getAllPlaylistsForAllServers() async {

  }

  Future<void> getPlaylists({bool wipeBackCache = false, Server useThisServer}) async {
    setState(() => tabText = 'Playlists');
    if(useThisServer == null) {
      useThisServer = serverList[currentServer];
    }

    var res = await _makeServerCall(useThisServer, '/playlist/getall', null, 'GET', wipeBackCache);

    displayList.clear();
    List<DisplayItem> newList = new List();
    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e['name'], 'playlist', e['name'], Icon(Icons.queue_music), null);
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getPlaylist(String playlist, {Server useThisServer, bool wipeBackCache = false}) async {
    if(useThisServer == null) {
      useThisServer = serverList[currentServer];
    }
    var res = await _makeServerCall(useThisServer, '/playlist/load', {"playlistname": playlist}, 'POST', wipeBackCache);

    displayList.clear();
    List<DisplayItem> newList = new List();
    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e['filepath'], 'file', '/' + e['filepath'], Icon(Icons.music_note), null);
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<List> readServerList() async {
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
    redrawServerFlag.addListener(_goToNavScreen);
    redrawPlaylistFlag.addListener(_setState);
    mStreamAudio.setFlag(redrawPlaylistFlag);
    // mStreamAudio.setFlag2(positionBar);

    // Load Servers
    readServerList().then((List contents) {
      // contents = []; // This line will reset the server list to empty on boot
      contents.forEach((f) {
        var newServer = Server.fromJson(f);
        setState(() {
          serverList.add(newServer);
        });
      });

      if (serverList.length > 0) {
        currentServer = 0;
        _goToNavScreen();
        // getFileList("");
        getAllPlaylistsForAllServers();
      } else {
        setState(() {
          tabText = 'Welcome';
          displayList.add(
            new DisplayItem(null, 'Welcome To mStream', 'addServer', '', Icon(Icons.add), 'Click here to add server')
          );
        });
      }
    });

    FlutterDownloader.registerCallback((id, status, progress) {
      // TODO: Handle downlaod state
      print('Download task ($id) is in status ($status) and process ($progress)');
    });
  }


  @override
  void dispose() {
    _tabController.dispose();
    redrawServerFlag.dispose();
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

  Future<bool> _onWillPop() {
    if (displayCache.length > 1) {
      displayCache.removeLast();
      displayList.length = 0;
      List<DisplayItem> newList = displayCache[displayCache.length - 1];
      newList.forEach((e){
        displayList.add(e);
      });
      setState(() {});
      return new Future.value(false);
    } else {
      return new Future.value(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Add a status bar to side menu.  Use it to display available space
    return new WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            tabs: [
              Tab(text: tabText),
              Tab(text: 'Now Playing'),
            ],
            controller: _tabController,
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('mStream',),
              Visibility(
                visible: currentServer < 0 ? false : true,
                child: Text(
                  currentServer < 0 ? '' : (serverList[currentServer].nickname.length > 0 ? serverList[currentServer].nickname: serverList[currentServer].url),
                  style: TextStyle(fontSize: 12.0),
                ),
              ),
            ],
          ),
          actions: <Widget> [
            new PopupMenuButton(
              onSelected: (Server selectedServer) {
                // if(currentServer != serverList.indexOf(selectedServer)) {
                  _tabController.animateTo(0);
                  tabText = 'Go To';
                  currentServer = serverList.indexOf(selectedServer);             
                  
                  displayCache.clear();
                  displayList.clear();
                  List<DisplayItem> newList = new List();
                  DisplayItem newItem1 = new DisplayItem(serverList[currentServer], 'File Explorer', 'execAction', 'fileExplorer',  new Icon(Icons.folder), null);
                  DisplayItem newItem2 = new DisplayItem(serverList[currentServer], 'Playlists', 'execAction', 'playlists',  new Icon(Icons.queue_music), null);
                  DisplayItem newItem3 = new DisplayItem(serverList[currentServer], 'Albums', 'execAction', 'albums',  new Icon(Icons.album), null);
                  DisplayItem newItem4 = new DisplayItem(serverList[currentServer], 'Artists', 'execAction', 'artists',  new Icon(Icons.library_music), null);

                  displayList.add(newItem1);
                  newList.add(newItem1);
                  displayList.add(newItem2);
                  newList.add(newItem2);
                  displayList.add(newItem3);
                  newList.add(newItem3);
                  displayList.add(newItem4);
                  newList.add(newItem4);
                  displayCache.add(newList);

                  setState(() {});
                // }
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => AddServerScreen()));
              }
            ),
          ]
        ),
        drawer: new Drawer(
          child: new ListView(
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget> [
              new DrawerHeader(
                child: new Image(image: AssetImage('graphics/mstream-logo.png')),
              ),
              new ListTile(
                leading: new Icon(Icons.folder),
                title: new Text('File Explorer', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17),),
                onTap: () {
                  getFileList("", wipeBackCache: true);
                  Navigator.of(context).pop();
                  _tabController.animateTo(0);
                },
              ),
              new ListTile(
                title: new Text('Playlists', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: new Icon(Icons.queue_music),
                onTap: () {
                  getPlaylists(wipeBackCache: true);
                  Navigator.of(context).pop();
                  _tabController.animateTo(0);
                },
              ),
              new ListTile(
                title: new Text('Albums', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: new Icon(Icons.album),
                onTap: () {
                  getAllAlbums(wipeBackCache: true);
                  Navigator.of(context).pop();
                  _tabController.animateTo(0);
                },
              ),
              new ListTile(
                title: new Text('Artists', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: new Icon(Icons.library_music),
                onTap: () {
                  getArtists(wipeBackCache: true);
                  Navigator.of(context).pop();
                  _tabController.animateTo(0);
                },
              ),
              new ListTile(
                title: new Text('Local Files', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: new Icon(Icons.folder_open),
                onTap: () {},
              ),
              new ListTile(
                title: new Text('Manage Servers', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: new Icon(Icons.router),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ManageServersScreen()), );
                },
              ),
              new Divider(),
              new ListTile(
                title: new Text('About mStream', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: new Icon(Icons.equalizer),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AboutScreen()));
                },
              ),
            ],
          )
        ),
        body: TabBarView(
          children: [localFile(), advanced()],
          controller: _tabController
        ),
        bottomNavigationBar: BottomAppBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              GestureDetector(
                onTapUp: (TapUpDetails details) {
                  var distance = details;
                  double width = MediaQuery.of(context).size.width;
                  double percentage = distance.globalPosition.dx / width;
                  mStreamAudio.seekByPercentage(percentage);
                },
                child: Container(
                  height: 16,
                  child: LinearProgressIndicator(
                    value: mStreamAudio.currentTime != null && mStreamAudio.currentTime.inMilliseconds > 0 && mStreamAudio.getDuration().inMilliseconds > 0
                            ? mStreamAudio.currentTime.inMilliseconds /mStreamAudio.getDuration().inMilliseconds
                            : 0.0,
                    // value: positionBar.value,
                    valueColor: new AlwaysStoppedAnimation(Colors.grey[300]),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: [            
                      IconButton(icon: Icon(Icons.skip_previous), onPressed: () {
                        setState(() {
                          mStreamAudio.previousSong();
                        });
                      }),
                      IconButton(icon: (mStreamAudio.playing == false) ? Icon(Icons.play_circle_outline) : Icon(Icons.pause_circle_outline), onPressed: () {
                        setState(() {
                          mStreamAudio.playPause();
                        });
                      }),
                      IconButton(icon: Icon(Icons.skip_next), onPressed: () {
                        setState(() {
                          mStreamAudio.nextSong();
                        });
                      }),
                    ]
                  ),
                  Row(
                    children: [            
                      IconButton(icon: Icon(Icons.repeat, color: (mStreamAudio.shouldLoop == true) ? Colors.lightBlueAccent : Colors.black), onPressed: () {
                        setState(() {
                          mStreamAudio.toggleRepeat();
                        });
                      }),
                      IconButton(icon: Icon(Icons.shuffle), color: (mStreamAudio.shuffle == true) ? Colors.lightBlueAccent : Colors.black, onPressed: () {
                        setState(() {
                          mStreamAudio.toggleShuffle();
                        });
                      }),
                      IconButton(icon: Icon(Icons.speaker), onPressed: () {},),
                    ]
                  ),
                ],
              ),
            ]
          )
        )
      )
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
    String thisUrl = lol.resolve('/ping').toString();

    try {
      response = await http.get(thisUrl);
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
    bool shouldUpdate = false;
    try {
      serverList[editThisServer];
      shouldUpdate = true;
    } catch (err) {

    }

    if(shouldUpdate) {
      serverList[editThisServer].url = _url;
      serverList[editThisServer].nickname = _serverName;
      serverList[editThisServer].password = _password;
      serverList[editThisServer].username = _username;
    }else {
      Server woo = new Server(origin, this._serverName, this._username, this._password, jwt, this._serverName);
      serverList.add(woo);
      
      currentServer = serverList.length - 1;
      redrawServerFlag.value = !redrawServerFlag.value;
    }

    // Save Server List
    writeServerFile();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Build a Form widget using the _formKey we created above
    try {
      serverList[editThisServer];
      _url = serverList[editThisServer].url;
      _username = serverList[editThisServer].username;
      _password = serverList[editThisServer].password;
      _serverName = serverList[editThisServer].nickname;
    } catch (err) {
      
    }

    return new Container(
      padding: new EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              initialValue: _serverName,
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
              initialValue: _url,
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
              initialValue: _username,
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
              initialValue: _password,              
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
    editThisServer = null;
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Server"),
      ),
      body: MyCustomForm()
    );
  }
}

class EditServerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Server"),
      ),
      body: MyCustomForm()
    );
  }
}

class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("About"),
      ),
      body: new Container(
        padding: new EdgeInsets.all(40.0),
        child: new ListView(
          children: [
            new Image(image: AssetImage('graphics/mstream-logo.png')),
            new Container(height: 15,),
            new Text('mStream Mobile v0.1',  style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
            new Text('Alpha Edition',  style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
          ]
        )
      )
    );
  }
}

class ShareScreen extends StatefulWidget {
  @override
  ShareScreenState createState() {
    return ShareScreenState();
  }
}

String shareLink = '';
class ShareScreenState extends State<ShareScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String shareButtonText = "Get Share Link";

  _callOnPressed() async {
    setState(() {  
      shareButtonText = 'Processing...';
    });

    Server thisServer = mStreamAudio.playlist[0].server;
    Uri currentUri = Uri.parse(thisServer.url);

    Map requestBody = {'time': 14, 'playlist': []};
    for (var i = 0; i < mStreamAudio.playlist.length; i++) {
      // TODO: This should be fixed on the webapp side
      if (mStreamAudio.playlist[i].path[0] == '/') {
        requestBody['playlist'].add(mStreamAudio.playlist[i].path.substring(1));
      } else {
        requestBody['playlist'].add(mStreamAudio.playlist[i].path);
      }
    }
    String url = currentUri.resolve('/shared/make-shared').toString();
    var response = await http.post(url, body: json.encode(requestBody),  headers: {'Content-Type':'application/json' ,'x-access-token': thisServer.jwt});
    shareButtonText = 'Get Share Link';
    setState(() {
      shareButtonText = 'Get Share Link';
    });
    if (response.statusCode > 299) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text('Server Call Failed')));
      return;   
    }

    var res = jsonDecode(response.body);
    String printUrl = currentUri.resolve('/shared/playlist/${res['playlist_id']}').toString();
    print(printUrl);
    setState(() {
      shareLink = printUrl;
    });
  }

  Widget _thisScreen() {
    if(mStreamAudio.playlist.length == 0) {
      return new Text('You don\'t have a plylist to share!',  style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17));
    }

    Widget showThis;
    bool allTheSame = true;
    Server compareTo = mStreamAudio.playlist[0].server;

    for (var i = 0; i < mStreamAudio.playlist.length; i++) {
      if(i == 0) {
        continue;
      }
      if(compareTo != mStreamAudio.playlist[i].server) {
        allTheSame = false;
      }
    }

    if(allTheSame == true) {
      showThis = ListView(
        children: [
          new Text('Shared playlsits expire automaticaly after 14 days',  style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
          new RaisedButton(
            padding: const EdgeInsets.all(8.0),
            onPressed: () {
              _callOnPressed();
            },
            child: new Text(shareButtonText),
          ),
          new Container(height: 28),
          new Text(shareLink)
        ]
      );
    }else {
      showThis = Text('Your playlist contains mixed server content.\n\nYou cannot share a mixed content playlist for security reasons',  style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17));
    }

    return showThis;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Share Playlist"),
      ),
      body: new Container(
        padding: new EdgeInsets.all(40.0),

        child: _thisScreen()
      )
    );
  }
}

class SavePlaylistScreen extends StatelessWidget {
  Server nullServer = new Server(null, null, null, null, null, null);
  Server selectedServer = null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Save Playlist"),
      ),
      body: new Container(
        padding: new EdgeInsets.all(40.0),
        child: new ListView(
          children: [
            new Text('Save Playlist Goes Here',  style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
            new DropdownButton(
              hint: new Text("New Playlist"),
              value: null,
              onChanged: (Server newServer) {
                selectedServer = newServer;
              },
              items: serverList.map((Server server) {
                return new DropdownMenuItem<Server>(
                  value: server,
                  child: new Text(
                    server.nickname,
                    style: new TextStyle(color: Colors.black),
                  ),
                );
              }).toList()
            ),
          ]
        )
      )
    );
  }
}

class ManageServersScreen extends StatefulWidget {
  @override
  ManageServersScreenState createState() {
    return ManageServersScreenState();
  }
}

// TODO: Delete files on delete server
class ManageServersScreenState extends State<ManageServersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Servers"),
      ),
      body: new Row(
        children: [Expanded(
          child: SizedBox(
            child: new ListView.builder(
              physics: const AlwaysScrollableScrollPhysics (),
              itemCount: serverList.length,
              itemBuilder: (BuildContext context, int index) {
                return new ListTile(
                  title: Text(serverList[index].nickname),
                  subtitle:  Text(serverList[index].url),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:[
                      IconButton(icon: Icon(Icons.edit), tooltip: 'Edit Server', onPressed: () {
                        editThisServer = index;
                        Navigator.push(context, MaterialPageRoute(builder: (context) => EditServerScreen()), );
                      }),
                      IconButton(
                        icon: Icon(Icons.delete_forever),
                        tooltip: 'Delete Server',
                        onPressed: () { 
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              // return object of type Dialog
                              return AlertDialog(
                                title: new Text("Confirm Remove Server"),
                                content: Row(children: <Widget>[
                                  new Checkbox(value: false, onChanged: (bool value) {
                                  
                                  }),
                                  new Flexible(child: Text("Remove synced files from device?"))
                                ]),
                                actions: <Widget>[
                                  new FlatButton(
                                    child: new Text("Go Back"),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  new FlatButton(
                                    child: new Text("Delete", style: TextStyle(color: Colors.red),),
                                    onPressed: () {
                                      try {
                                        serverList[index];
                                        serverList.removeAt(index);
                                        setState(() {
                                        });
                                        writeServerFile();

                                        // Handle case were all servers are removed
                                        if (serverList.length == 0) {
                                          tabText = 'Welcome';
                                          displayList.clear();
                                          displayCache.clear();
                                          displayList.add(new DisplayItem(null, 'Welcome To mStream', 'addServer', '', Icon(Icons.add), 'Click here to add server'));
                                          setState(() {
                                            currentServer = -1;
                                          });
                                        } else if(currentServer == index) { // Handle case where user removes the current server
                                          redrawServerFlag.value = !redrawServerFlag.value;
                                          setState(() {
                                            currentServer = 0;
                                          });
                                        }else if (currentServer > index) { // Handle case where curent server is after remoced index
                                          setState(() {
                                            currentServer = currentServer -1;
                                          });
                                        }
                                      } catch(err) {

                                      }
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                );
              }
            )
          ),
        )]
      )
    );
  }
}