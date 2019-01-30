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
    DisplayItem newItem1 = new DisplayItem('File Explorer', 'execAction', 'fileExplorer',  new Icon(Icons.folder), null);
    DisplayItem newItem2 = new DisplayItem('Playlists', 'execAction', 'playlists',  new Icon(Icons.queue_music), null);
    DisplayItem newItem3 = new DisplayItem('Albums', 'execAction', 'albums',  new Icon(Icons.album), null);
    DisplayItem newItem4 = new DisplayItem('Artists', 'execAction', 'artists',  new Icon(Icons.library_music), null);

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
              Uri url = Uri.parse(serverList[currentServer].url + '/media' + element.data + '?token=' + serverList[currentServer].jwt );
              QueueItem newItem = new QueueItem(element.name, url.toString(), null, null, null, null, null, null, null, null, null);
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
              print(displayList[index]);
              return new ListTile(
                leading: displayList[index].icon == null ? null : displayList[index].icon,
                title: Text(displayList[index].name),
                subtitle: displayList[index].subtext == null ? null : Text(displayList[index].subtext),
                onTap: () {
                  if(displayList[index].type == 'file') {
                    Uri url = Uri.parse(serverList[currentServer].url + '/media' + displayList[index].data + '?token=' + serverList[currentServer].jwt );
                    QueueItem newItem = new QueueItem(displayList[index].name, url.toString(), null, null, null, null, null, null, null, null, null);
                    setState(() {
                      mStreamAudio.addSong(newItem);
                    });
                  }

                  if(displayList[index].type == 'album') {
                    getAlbumSongs(displayList[index].data);
                  }

                  if(displayList[index].type == 'artist') {
                    getArtistAlbums(displayList[index].data);
                  }

                  if(displayList[index].type == 'directory') {
                    getFileList(displayList[index].data);
                  }

                  if(displayList[index].type == 'addServer') {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AddServerScreen()), );
                  }

                  if(displayList[index].type == 'playlist') {
                    getPlaylist(displayList[index].data);
                  }

                  if(displayList[index].type == 'execAction' && displayList[index].data =='fileExplorer') {
                    getFileList("", wipeBackCache: false);                  
                  }
                  if(displayList[index].type == 'execAction' && displayList[index].data =='playlists') {
                    getPlaylists(wipeBackCache: false);
                  }
                  if(displayList[index].type == 'execAction' && displayList[index].data =='artists') {
                    getArtists(wipeBackCache: false);
                  }
                  if(displayList[index].type == 'execAction' && displayList[index].data =='albums') {
                    getAllAlbums(wipeBackCache: false);
                  }
                },
              );
            }
          )
        )
      )
    ]);
  }

  Future<void> getFileList(String directory, {bool wipeBackCache = false}) async {
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

    var res = jsonDecode(response.body);
    if(wipeBackCache) {
      displayCache.clear();
      List<DisplayItem> newList = new List();
      newList.add(new DisplayItem('File Explorer', 'execAction', 'fileExplorer',  new Icon(Icons.folder), null));
      newList.add(new DisplayItem('Playlists', 'execAction', 'playlists',  new Icon(Icons.queue_music), null));
      newList.add(new DisplayItem('Albums', 'execAction', 'albums',  new Icon(Icons.album), null));
      newList.add(new DisplayItem('Artists', 'execAction', 'artists',  new Icon(Icons.library_music), null));
      displayCache.add(newList);
    }
    displayList.clear();
    List<DisplayItem> newList = new List();
    res['contents'].forEach((e) {
      Icon thisIcon = e['type'] == 'directory' ? Icon(Icons.folder) : Icon(Icons.music_note);
      var thisType = (e['type'] == 'directory') ? 'directory' : 'file';
      DisplayItem newItem = new DisplayItem(e['name'], thisType, path.join(res['path'], e['name']), thisIcon, null);
      displayList.add(newItem);
      newList.add(newItem);
    });
    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getArtists( {bool wipeBackCache = false}) async {
    setState(() {
      tabText = 'Artists';
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
    String url = currentUri.resolve('/db/artists').toString();
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
    if(wipeBackCache) {
      displayCache.clear();
      List<DisplayItem> newList = new List();
      newList.add(new DisplayItem('File Explorer', 'execAction', 'fileExplorer',  new Icon(Icons.folder), null));
      newList.add(new DisplayItem('Playlists', 'execAction', 'playlists',  new Icon(Icons.queue_music), null));
      newList.add(new DisplayItem('Albums', 'execAction', 'albums',  new Icon(Icons.album), null));
      newList.add(new DisplayItem('Artists', 'execAction', 'artists',  new Icon(Icons.library_music), null));
      displayCache.add(newList);
    }
    displayList.clear();
    List<DisplayItem> newList = new List();
    res['artists'].forEach((e) {
      DisplayItem newItem = new DisplayItem(e, 'artist', e, Icon(Icons.library_music), null);
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getArtistAlbums(String artist, {bool wipeBackCache = false}) async {
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
    String url = currentUri.resolve('/db/artists-albums').toString();
    var response = await http.post(url, body: {"artist": artist}, headers: { 'x-access-token': serverList[currentServer].jwt});
    
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
    List<DisplayItem> newList = new List();
    res['albums'].forEach((e) {
      DisplayItem newItem = new DisplayItem(e['name'], 'album', e['name'], Icon(Icons.album), null);
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getAlbumSongs(String album, {bool wipeBackCache = false}) async {
    setState(() {
      tabText = 'Albums';
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
    String url = currentUri.resolve('/db/album-songs').toString();
    var response = await http.post(url, body: {"album": album}, headers: { 'x-access-token': serverList[currentServer].jwt});
    
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
    if(wipeBackCache) {
      displayCache.clear();
      List<DisplayItem> newList = new List();
      newList.add(new DisplayItem('File Explorer', 'execAction', 'fileExplorer',  new Icon(Icons.folder), null));
      newList.add(new DisplayItem('Playlists', 'execAction', 'playlists',  new Icon(Icons.queue_music), null));
      newList.add(new DisplayItem('Albums', 'execAction', 'albums',  new Icon(Icons.album), null));
      newList.add(new DisplayItem('Artists', 'execAction', 'artists',  new Icon(Icons.library_music), null));
      displayCache.add(newList);
    }
    List<DisplayItem> newList = new List();
    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(e['filepath'], 'file', '/' + e['filepath'], Icon(Icons.music_note), null);
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getAllAlbums({bool wipeBackCache = false}) async {
    setState(() {
      tabText = 'Albums';
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
    String url = currentUri.resolve('/db/albums').toString();
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
    if(wipeBackCache) {
      displayCache.clear();
      List<DisplayItem> newList = new List();
      newList.add(new DisplayItem('File Explorer', 'execAction', 'fileExplorer',  new Icon(Icons.folder), null));
      newList.add(new DisplayItem('Playlists', 'execAction', 'playlists',  new Icon(Icons.queue_music), null));
      newList.add(new DisplayItem('Albums', 'execAction', 'albums',  new Icon(Icons.album), null));
      newList.add(new DisplayItem('Artists', 'execAction', 'artists',  new Icon(Icons.library_music), null));
      displayCache.add(newList);
    }
    List<DisplayItem> newList = new List();
    res['albums'].forEach((e) {
      DisplayItem newItem = new DisplayItem(e['name'], 'album', e['name'], Icon(Icons.album), null);
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getAllPlaylistsForAllServers() async {

  }

  Future<void> getPlaylists({bool wipeBackCache = false}) async {
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
    if(wipeBackCache) {
      displayCache.clear();
      List<DisplayItem> newList = new List();
      newList.add(new DisplayItem('File Explorer', 'execAction', 'fileExplorer',  new Icon(Icons.folder), null));
      newList.add(new DisplayItem('Playlists', 'execAction', 'playlists',  new Icon(Icons.queue_music), null));
      newList.add(new DisplayItem('Albums', 'execAction', 'albums',  new Icon(Icons.album), null));
      newList.add(new DisplayItem('Artists', 'execAction', 'artists',  new Icon(Icons.library_music), null));
      displayCache.add(newList);
    }
    List<DisplayItem> newList = new List();
    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(e['name'], 'playlist', e['name'], Icon(Icons.queue_music), null);
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getPlaylist(String playlist) async {
    print(playlist);
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
    String url = currentUri.resolve('/playlist/load').toString();
    var response = await http.post(url, body: {"playlistname": playlist},  headers: { 'x-access-token': serverList[currentServer].jwt});

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

    var res = jsonDecode(response.body);
    displayList.clear();
    List<DisplayItem> newList = new List();
    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(e['filepath'], 'file', '/' + e['filepath'], Icon(Icons.music_note), null);
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
            new DisplayItem('Welcome To mStream', 'addServer', '', Icon(Icons.add), 'Click here to add server')
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
                if(currentServer != serverList.indexOf(selectedServer)) {
                  _tabController.animateTo(0);
                  tabText = 'Go To';
                  
                  displayCache.clear();
                  displayList.clear();
                  List<DisplayItem> newList = new List();
                  DisplayItem newItem1 = new DisplayItem('File Explorer', 'execAction', 'fileExplorer',  new Icon(Icons.folder), null);
                  DisplayItem newItem2 = new DisplayItem('Playlists', 'execAction', 'playlists',  new Icon(Icons.queue_music), null);
                  DisplayItem newItem3 = new DisplayItem('Albums', 'execAction', 'albums',  new Icon(Icons.album), null);
                  DisplayItem newItem4 = new DisplayItem('Artists', 'execAction', 'artists',  new Icon(Icons.library_music), null);

                  displayList.add(newItem1);
                  newList.add(newItem1);
                  displayList.add(newItem2);
                  newList.add(newItem2);
                  displayList.add(newItem3);
                  newList.add(newItem3);
                  displayList.add(newItem4);
                  newList.add(newItem4);
                  displayCache.add(newList);

                  setState(() {
                    currentServer = serverList.indexOf(selectedServer);             
                  });
                }
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
                  print(width.toString());
                  print(distance.globalPosition.dx);

                  double percentage = distance.globalPosition.dx / width;
                  print(percentage);
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

class ShareScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Share Playlist"),
      ),
      body: new Container(
        padding: new EdgeInsets.all(40.0),
        child: new ListView(
          children: [
            new Text('Share Playlist Goes Here',  style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
          ]
        )
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
  ManageServersScreenSatate createState() {
    return ManageServersScreenSatate();
  }
}

// TODO: Delete files on delete server
class ManageServersScreenSatate extends State<ManageServersScreen> {
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
                                          displayList.add(new DisplayItem('Welcome To mStream', 'addServer', '', Icon(Icons.add), 'Click here to add server'));
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