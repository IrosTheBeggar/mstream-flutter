import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'objects/server.dart';
import 'objects/download_thing.dart';
import 'objects/display_item.dart';
import 'package:path/path.dart' as path;

import 'mstream_player.dart';
import 'objects/queue_item.dart';
import 'objects/metadata.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:smooth_star_rating/smooth_star_rating.dart'; 
import 'package:qrcode_reader/qrcode_reader.dart';

import 'package:flutter_downloader/flutter_downloader.dart';

typedef void OnError(Exception exception);

// Sync Stuff
Map<String, DownloadThing> downloadTracker = {};

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
  runApp(new MaterialApp(  
    title: 'mStream Music',
    home: new ExampleApp(),
    theme: ThemeData(
      brightness: Brightness.dark,
      primaryColor: Color(0xFF212121),
      primaryColorDark: Color(0xFF000000),
      primaryColorLight: Color(0xFF484848),
      accentColor: Color(0xFFffab00),
      buttonColor: Color(0xFFFFAB00),
      scaffoldBackgroundColor: Color(0xFFe1e2e1),
      cardColor: Color(0xFFffffff)
    )
  ));
}

class ExampleApp extends StatefulWidget {
  @override
  _ExampleAppState createState() => new _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> with SingleTickerProviderStateMixin {
  TabController _tabController;
  String localFilePath;

  _getSongMetadata(QueueItem song) async {
    if(song.server == null) {
      return;
    }

    Uri currentUri = Uri.parse(song.server.url);
    String url = currentUri.resolve('/db/metadata').toString();
    var response = await http.post(url ,body: {'filepath':song.path},  headers: { 'x-access-token': song.server.jwt});
    try {
      var e = jsonDecode(response.body);
      MusicMetadata newMeta = new MusicMetadata(e['metadata']['artist'], e['metadata']['album'], e['metadata']['title'], e['metadata']['track'], null, e['metadata']['year'], e['metadata']['hash'], e['metadata']['rating'], e['metadata']['album-art']);
      setState(() {
        song.metadata = newMeta;        
      });
    }catch (err) {

    }
  }

  // TODO: This really shouldn't be asynced
  _addSongWizard(QueueItem song) async {
    if(song.server != null) {
      // Check for song locally
      String downloadDirectory = song.server.localname + song.path;
      final dir = await getApplicationDocumentsDirectory();
      String finalString = '${dir.path}/media/${downloadDirectory}';

      if (new File(finalString).existsSync() == true) {
        song.localFile = finalString;
      }
    }

    mStreamAudio.addSong(song);
    if(song.metadata == null) {
      _getSongMetadata(song);
    }
  }

  _setState() {
    setState(() {});
  }

  _goToNavScreen() {
    _tabController.animateTo(0);
    tabText = 'Go To';
    
    displayCache.clear();
    displayList.clear();
    List<DisplayItem> newList = new List();
    DisplayItem newItem1 = new DisplayItem(serverList[currentServer], 'File Explorer', 'execAction', 'fileExplorer', Icon(Icons.folder, color: Color(0xFFffab00)), null);
    DisplayItem newItem2 = new DisplayItem(serverList[currentServer], 'Playlists', 'execAction', 'playlists', Icon(Icons.queue_music, color: Colors.black), null);
    DisplayItem newItem3 = new DisplayItem(serverList[currentServer], 'Albums', 'execAction', 'albums', Icon(Icons.album, color: Colors.black), null);
    DisplayItem newItem4 = new DisplayItem(serverList[currentServer], 'Artists', 'execAction', 'artists', Icon(Icons.library_music, color: Colors.black), null);
    DisplayItem newItem5 = new DisplayItem(serverList[currentServer], 'Rated', 'execAction', 'rated', Icon(Icons.star, color: Colors.black), null);
    DisplayItem newItem6 = new DisplayItem(serverList[currentServer], 'Recent', 'execAction', 'recent', Icon(Icons.query_builder, color: Colors.black), null);

    displayList.add(newItem1);
    newList.add(newItem1);
    displayList.add(newItem2);
    newList.add(newItem2);
    displayList.add(newItem3);
    newList.add(newItem3);
    displayList.add(newItem4);
    newList.add(newItem4);
    displayList.add(newItem5);
    newList.add(newItem5);
    displayList.add(newItem6);
    newList.add(newItem6);

    displayCache.add(newList);
  }

  Widget advanced() {
    return Column(children: <Widget>[
      Material(color: Colors.white, 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: [
                // IconButton(icon: Icon(Icons.save, color: Colors.black,), onPressed: () {
                //   Navigator.push(context, MaterialPageRoute(builder: (context) => SavePlaylistScreen()));
                // }),
                IconButton(icon: Icon(Icons.share, color: Colors.black,), onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ShareScreen()));
                }),
                IconButton(icon: Icon(Icons.sync, color: Colors.black,), onPressed: () {
                  for (var i = 0; i < mStreamAudio.playlist.length; i++) {
                    if(mStreamAudio.playlist[i].localFile == null && mStreamAudio.playlist[i].server != null) {
                      downloadOneFile(mStreamAudio.playlist[i].server, mStreamAudio.playlist[i].path, queueItem: mStreamAudio.playlist[i]);
                    }
                  }
                }),
              ]
            ),
            Row(
              children: [
                IconButton(splashColor: Colors.red, icon: Icon(Icons.cancel), color: Colors.redAccent, onPressed: () {
                  setState(() {
                    mStreamAudio.clearPlaylist();
                  });
                },),
              ]
            )
          ]
        )
      ),
      Expanded(
        child: SizedBox(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics (),
            itemCount: mStreamAudio.playlist.length,
            itemBuilder: (BuildContext context, int index) {
              return Slidable(
                key: Key(mStreamAudio.playlist[index].uuidString),
                slideToDismissDelegate: SlideToDismissDrawerDelegate(
                  onDismissed: (actionType) {
                  setState(() {
                    mStreamAudio.removeSongAtPosition(index);
                  });
                  }
                ),
                delegate: SlidableStrechDelegate(),
                actionExtentRatio: 0.18,
                secondaryActions: <Widget>[
                  SlideAction(
                    child: Container(),
                    color: Colors.grey,
                    closeOnTap: false,
                    //onTap: () => removeLocation(location),
                  ),
                ],
                actions: <Widget>[
                  IconSlideAction(
                    color: Colors.grey,
                    closeOnTap: true,
                    icon: Icons.sync,
                    caption: 'SYNC',
                    onTap: () {
                      if(mStreamAudio.playlist[index].server != null) {
                        downloadOneFile(mStreamAudio.playlist[index].server, mStreamAudio.playlist[index].path, queueItem: mStreamAudio.playlist[index]);
                      }
                    },
                  ),
                  IconSlideAction(
                    caption: (mStreamAudio.playlist[index].metadata != null && mStreamAudio.playlist[index].metadata.rating != null) ? (mStreamAudio.playlist[index].metadata.rating/2).toStringAsFixed(1): 'RATE',
                    color: Colors.blueGrey,
                    icon: Icons.star,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text("Rate Song"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                mStreamAudio.playlist[index].getText(),
                                RateDialogContent(queueItem: mStreamAudio.playlist[index]),
                              ]
                            ),
                            actions: [
                              FlatButton(
                                child: Text("Go Back"),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              FlatButton(
                                child: Text("Rate Song"),
                                onPressed: () {
                                  // Save
                                  this._rateSong(mStreamAudio.playlist[index]).then((onValue) {
                                  });
                                  Navigator.of(context).pop();
                                },
                              ),
                            ]
                          );
                      });
                    },
                  ),
                ],
                child: Container(
                  color: (index == mStreamAudio.positionCache) ? Color(0xFFffab00) : null,
                  child: IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Container(
                            width: 4,
                            child: 
                            RotatedBox(
                              quarterTurns: 3,
                              child: 
                              LinearProgressIndicator(
                                value: mStreamAudio.playlist[index].localFile != null ? 1 : mStreamAudio.playlist[index].downloadProgress/100,
                                valueColor: AlwaysStoppedAnimation(Colors.blue),
                                backgroundColor: Colors.white.withOpacity(0),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              child: ListTile(
                                leading: mStreamAudio.playlist[index].getImage(),
                                title: mStreamAudio.playlist[index].getText(),
                                subtitle: mStreamAudio.playlist[index].getSubText(),
                                onTap: () {
                                  setState(() {
                                    mStreamAudio.goToSongAtPosition(index);
                                  });
                                }
                              )
                            )
                          )
                        ]
                      )
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
    return Column(children: <Widget>[
      Material(color:Color(0xFFffffff),  child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(icon: Icon(Icons.keyboard_arrow_left, color: Colors.black), tooltip: 'Go Back', onPressed: () {
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
          Row(children: <Widget>[
            IconButton(icon: Icon(Icons.search, color: Colors.black), onPressed: () {
              // TODO: 
            }),
            IconButton(icon: Icon(Icons.sync, color: Colors.black), onPressed: () {
              displayList.forEach((element) {
                if (element.type == 'file') {
                  downloadOneFile(element.server, element.data, displayItem: element);
                }
              });
              setState(() {});
            }),
            IconButton(icon: Icon(Icons.library_add, color: Colors.black,), tooltip: 'Add All', onPressed: () {
              displayList.forEach((element) {
                if (element.type == 'file') {
                  Uri url = Uri.parse(element.server.url + '/media' + element.data + '?token=' + element.server.jwt );
                  QueueItem newItem = new QueueItem(element.server, element.name, url.toString(), element.data, element.metadata);
                  _addSongWizard(newItem);
                }else if (element.type == 'localFile') {
                  QueueItem newItem = new QueueItem(null, element.name, null, null, null);
                  newItem.localFile = element.data;
                    _addSongWizard(newItem);
                }
                setState(() { });
              });
              setState(() {});
            }),
          ])
        ])
      ),
      Expanded(
        child: SizedBox(
          child: ListView.builder( // LOL Holy Shit: https://stackoverflow.com/questions/52801201/flutter-renderbox-was-not-laid-out
            physics: const AlwaysScrollableScrollPhysics (),
            itemCount: displayList.length,
            itemBuilder: (BuildContext context, int index) {
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFbdbdbd))
                  )
                ),
                child: Material(color: Color(0xFFe1e2e1), child: InkWell(splashColor: Colors.blue, child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Container(
                        width: 4,
                        child: 
                        RotatedBox(
                          quarterTurns: 3,
                          child: 
                          LinearProgressIndicator(
                            value: displayList[index].downloadProgress/100,
                            valueColor: new AlwaysStoppedAnimation(Colors.blue),
                            backgroundColor: Colors.white.withOpacity(0),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          leading: displayList[index].icon == null ? null : displayList[index].icon,
                          title: displayList[index].getText(),
                          subtitle: displayList[index].getSubText(),
                          onTap: () {
                            if(displayList[index].type == 'file') {
                              Uri url = Uri.parse(displayList[index].server.url + '/media' + displayList[index].data + '?token=' + serverList[currentServer].jwt );
                              QueueItem newItem = new QueueItem(displayList[index].server, displayList[index].name, url.toString(), displayList[index].data, displayList[index].metadata);
                              
                              setState(() {
                                _addSongWizard(newItem);
                              });
                            }

                            if(displayList[index].type == 'localFile') {
                              QueueItem newItem = new QueueItem(null, displayList[index].name, null, null, null);
                              newItem.localFile = displayList[index].data;
                              setState(() {
                                _addSongWizard(newItem);
                              });
                              return;
                            }

                            // TODO: Replace all this with a switch statment

                            if( displayList[index].type == 'localDirectory') {
                              getLocalFiles(displayList[index].data);
                              return;
                            }

                            if(displayList[index].type == 'album') {
                              getAlbumSongs(displayList[index].data, useThisServer: displayList[index].server);
                              return;
                            }

                            if(displayList[index].type == 'artist') {
                              getArtistAlbums(displayList[index].data, useThisServer: displayList[index].server);
                              return;
                            }

                            if(displayList[index].type == 'directory') {
                              getFileList(displayList[index].data, useThisServer: displayList[index].server);
                              return;
                            }

                            if(displayList[index].type == 'addServer') {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AddServerScreen()), );
                              return;
                            }

                            if(displayList[index].type == 'playlist') {
                              getPlaylist(displayList[index].data, useThisServer: displayList[index].server);
                              return;
                            }

                            if(displayList[index].type == 'execAction' && displayList[index].data == 'fileExplorer') {
                              getFileList("", wipeBackCache: false, useThisServer: displayList[index].server);
                              return;
                            }
                            if(displayList[index].type == 'execAction' && displayList[index].data == 'playlists') {
                              getPlaylists(wipeBackCache: false, useThisServer: displayList[index].server);
                              return;
                            }
                            if(displayList[index].type == 'execAction' && displayList[index].data == 'artists') {
                              getArtists(wipeBackCache: false, useThisServer: displayList[index].server);
                              return;
                            }
                            if(displayList[index].type == 'execAction' && displayList[index].data == 'albums') {
                              getAllAlbums(wipeBackCache: false, useThisServer: displayList[index].server);
                              return;
                            }
                            if(displayList[index].type == 'execAction' && displayList[index].data == 'rated') {
                              getStarredSongs(wipeBackCache: false, useThisServer: displayList[index].server);
                              return;
                            }
                            if(displayList[index].type == 'execAction' && displayList[index].data == 'recent') {
                              getRecentSongs(wipeBackCache: false, useThisServer: displayList[index].server);
                              return;
                            }
                          },
                        )
                      )
                    ]
                  )
                )
              )));
            }
          )
        )
      )
    ]);
  }

  Future _rateSong(QueueItem thisItem) async {
    // Make http call
    Uri currentUri = Uri.parse(thisItem.server.url);
    String url = currentUri.resolve('/db/rate-song').toString();
    // Update actual rating on success

    var response;
    try {
      Map requestBody = {'filepath':thisItem.path, 'rating':thisItem.tempRating};
      response = await http.post(url , body: json.encode(requestBody),  headers: {'Content-Type':'application/json' ,'x-access-token': thisItem.server.jwt});

      if (response.statusCode > 299) {
        throw new Error();
      }
      jsonDecode(response.body);
      thisItem.metadata.rating = thisItem.tempRating;
      // TODO: All metadata instances need to be checked and updated if the paths + servers are the same
      setState(() {});
    } catch(err) {
      Fluttertoast.showToast(
        msg: "Rating Call Failed",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIos: 1,
        backgroundColor: Colors.orange,
        textColor: Colors.white
      );
    }

    thisItem.tempRating = null;
  }

  Future<void> getLocalFiles(String directory, {wipeBackCache: false}) async {
    setState(() => tabText = 'Local Files');

    if(wipeBackCache) {
      displayCache.clear();
    } 
    displayList.clear();
    List<DisplayItem> newList = new List();

    Directory file;
    if(directory == null){
      Directory woo = await getApplicationDocumentsDirectory();
      file = new Directory(path.join(woo.path.toString(), 'media'));
    }else {
      file = new Directory(directory);
    }

    int stringLength = file.path.toString().length + 1; // The plug ones covers the extra `/` that will be on the results 
    file.list(recursive: false, followLinks: false)
      .listen((FileSystemEntity entity) {
        print(entity.path);
        Icon useIcon;
        String type;
        if (entity is File) {
          useIcon = new Icon(Icons.music_note, color: Colors.black);
          type = 'localFile';
        } else {
          useIcon = new Icon(Icons.folder, color: Color(0xFFffab00));
          type = 'localDirectory';
        }

        String thisName = entity.path.substring(stringLength, entity.path.length);
        DisplayItem newItem = new DisplayItem(null, thisName, type, entity.path, useIcon, null);
        displayList.add(newItem);
        newList.add(newItem);

      }).onDone(() {
        displayCache.add(newList);
        setState(() {});
      });
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
        msg: "Server Call Failed",
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
      newList.add(new DisplayItem(useThisServer, 'File Explorer', 'execAction', 'fileExplorer', Icon(Icons.folder, color: Color(0xFFffab00)), null));
      newList.add(new DisplayItem(useThisServer, 'Playlists', 'execAction', 'playlists', Icon(Icons.queue_music, color: Colors.black), null));
      newList.add(new DisplayItem(useThisServer, 'Albums', 'execAction', 'albums', Icon(Icons.album, color: Colors.black), null));
      newList.add(new DisplayItem(useThisServer, 'Artists', 'execAction', 'artists', Icon(Icons.library_music, color: Colors.black), null));
      newList.add(new DisplayItem(useThisServer, 'Rated', 'execAction', 'rated', Icon(Icons.star, color: Colors.black), null));
      newList.add(new DisplayItem(useThisServer, 'Recent', 'execAction', 'recent', Icon(Icons.query_builder, color: Colors.black), null));
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
    if(res == null) {
      return;
    }

    displayList.clear();
    List<DisplayItem> newList = new List();
    res['contents'].forEach((e) {
      Icon thisIcon = e['type'] == 'directory' ? Icon(Icons.folder, color: Color(0xFFffab00)) : Icon(Icons.music_note, color: Colors.blue);
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
    if(res == null) {
      return;
    }

    displayList.clear();
    List<DisplayItem> newList = new List();
    res['artists'].forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e, 'artist', e, Icon(Icons.library_music, color: Colors.black), null);
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
    if(res == null) {
      return;
    }

    displayList.clear();
    List<DisplayItem> newList = new List();
    res['albums'].forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e['name'], 'album', e['name'], Icon(Icons.album, color: Colors.black), null);
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

    var res = await _makeServerCall(useThisServer, '/db/album-songs', {"album": album != null ? album : ""}, 'POST', wipeBackCache);
    if(res == null) {
      return;
    }

    displayList.clear();
    List<DisplayItem> newList = new List();
    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e['filepath'], 'file', '/' + e['filepath'], Icon(Icons.music_note, color: Colors.blue), null);
      
      try {
        e['metadata'];
        MusicMetadata newMeta = new MusicMetadata(e['metadata']['artist'], e['metadata']['album'], e['metadata']['title'], e['metadata']['track'], null, e['metadata']['year'], e['metadata']['hash'], e['metadata']['rating'], e['metadata']['album-art']);
        newItem.metadata = newMeta;
      }catch (err) {

      }
      
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getStarredSongs({bool wipeBackCache = false, Server useThisServer}) async {
    setState(() => tabText = 'Albums');
    if(useThisServer == null) {
      useThisServer = serverList[currentServer];
    }

    var res = await _makeServerCall(useThisServer, '/db/get-rated', null, 'GET', wipeBackCache);
    if(res == null) {
      return;
    }

    displayList.clear();
    List<DisplayItem> newList = new List();

    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e['filepath'], 'file', '/' + e['filepath'], Icon(Icons.music_note, color: Colors.blue), null);
      
      try {
        e['metadata'];
        MusicMetadata newMeta = new MusicMetadata(e['metadata']['artist'], e['metadata']['album'], e['metadata']['title'], e['metadata']['track'], null, e['metadata']['year'], e['metadata']['hash'], e['metadata']['rating'], e['metadata']['album-art']);
        newItem.metadata = newMeta;
      }catch (err) {}
      
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getRecentSongs({bool wipeBackCache = false, Server useThisServer}) async {
    setState(() => tabText = 'Albums');
    if(useThisServer == null) {
      useThisServer = serverList[currentServer];
    }

    var res = await _makeServerCall(useThisServer, '/db/recent/added', {"limit": "100"}, 'POST', wipeBackCache);
    if(res == null) {
      return;
    }

    displayList.clear();
    List<DisplayItem> newList = new List();

    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e['filepath'], 'file', '/' + e['filepath'], Icon(Icons.music_note, color: Colors.blue), null);
      
      try {
        e['metadata'];
        MusicMetadata newMeta = new MusicMetadata(e['metadata']['artist'], e['metadata']['album'], e['metadata']['title'], e['metadata']['track'], null, e['metadata']['year'], e['metadata']['hash'], e['metadata']['rating'], e['metadata']['album-art']);
        newItem.metadata = newMeta;
      }catch (err) {}
      
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
    if(res == null) {
      return;
    }

    displayList.clear();
    List<DisplayItem> newList = new List();
    res['albums'].forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e['name'], 'album', e['name'], Icon(Icons.album, color: Colors.black), null);
      displayList.add(newItem);
      newList.add(newItem);
    });

    displayCache.add(newList);
    setState(() {});
  }

  Future<void> getPlaylists({bool wipeBackCache = false, Server useThisServer}) async {
    setState(() => tabText = 'Playlists');
    if(useThisServer == null) {
      useThisServer = serverList[currentServer];
    }

    var res = await _makeServerCall(useThisServer, '/playlist/getall', null, 'GET', wipeBackCache);
    if(res == null) {
      return;
    }

    displayList.clear();
    List<DisplayItem> newList = new List();
    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e['name'], 'playlist', e['name'], Icon(Icons.queue_music, color: Colors.black), null);
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
    if(res == null) {
      return;
    }

    displayList.clear();
    List<DisplayItem> newList = new List();
    res.forEach((e) {
      DisplayItem newItem = new DisplayItem(useThisServer, e['filepath'], 'file', '/' + e['filepath'], Icon(Icons.music_note, color: Colors.blue), null);
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

  Future<void> _syncItem(String id, DownloadTaskStatus status, int progress) async {
    // Check if download is finished
    DownloadThing downloadThing = downloadTracker[id];
    if(status.toString() == 'DownloadTaskStatus(3)') {
      for (var i = 0; i < mStreamAudio.playlist.length; i++) {
        if(mStreamAudio.playlist[i].server.url == downloadThing.serverUrl && mStreamAudio.playlist[i].path == downloadThing.downloadDirectory) {
          String downloadDirectory = mStreamAudio.playlist[i].server.localname + mStreamAudio.playlist[i].path;
          final dir = await getApplicationDocumentsDirectory();
          String finalString = '${dir.path}/media/${downloadDirectory}';
          setState(() {
            mStreamAudio.playlist[i].localFile = finalString;
          });
        }
      }
    }else {
      if(downloadThing.referenceQueueItem != null) {
        setState(() {
          downloadThing.referenceQueueItem.downloadProgress = progress;          
        });
      }
      if(downloadThing.referenceDisplayItem != null) {
        setState(() {
          downloadThing.referenceDisplayItem.downloadProgress = progress;          
        });
      }
    }

    // Update the tracker
  }

  _handleDownloader() {
    FlutterDownloader.registerCallback((id, status, progress) {
      print('Download task ($id) is in status ($status) and process ($progress)');
      _syncItem(id, status, progress);
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = new TabController(vsync: this, length: 2);
    redrawServerFlag.addListener(_goToNavScreen);
    redrawPlaylistFlag.addListener(_setState);
    mStreamAudio.setFlag(redrawPlaylistFlag);
    _handleDownloader();

    // Load Servers
    readServerList().then((List contents) {
      // contents = []; // This line will reset the server list to empty on boot
      contents.forEach((f) {
        Server newServer = Server.fromJson(f);
        setState(() {
          serverList.add(newServer);
        });
      });

      if (serverList.length > 0) {
        currentServer = 0;
        _goToNavScreen();
      } else {
        setState(() {
          tabText = 'Welcome';
          displayList.add(
            new DisplayItem(null, 'Welcome To mStream', 'addServer', '', Icon(Icons.add, color: Colors.black), 'Click here to add server')
          );
        });
      }
    });
  }

  Future<void> downloadOneFile(Server serverObj, String serverPath, { QueueItem queueItem, DisplayItem displayItem }) async {
    // download each file relative to its path
    String downloadUrl = serverObj.url + '/media' + serverPath + '?token=' + serverObj.jwt;
    String downloadDirectory = serverObj.localname + serverPath;
    final dir = await getApplicationDocumentsDirectory();

    String lol =  path.dirname( '${dir.path}/media/${downloadDirectory}' );
    String filename = path.basename( '${dir.path}/media/${downloadDirectory}' );
    new Directory(lol).createSync(recursive: true);
    Uri url = Uri.parse(downloadUrl);

    String taskId = await FlutterDownloader.enqueue(
      url: url.toString(),
      fileName: filename,
      savedDir: lol,
      showNotification: false, // show download progress in status bar (for Android)
      openFileFromNotification: false, // click on notification to open downloaded file (for Android)
    );

    downloadTracker[taskId] = new DownloadThing(serverObj.url, null, serverPath);
    if(queueItem != null) {
      downloadTracker[taskId].referenceQueueItem = queueItem;
    }
    if(displayItem != null) {
      downloadTracker[taskId].referenceDisplayItem = displayItem;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    redrawServerFlag.dispose();
    redrawPlaylistFlag.dispose();
    FlutterDownloader.registerCallback(null);
    super.dispose();
  }

  Future<bool> _onWillPop() {
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    } else if (displayCache.length > 1) {
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

  void _setupStartScreen() {
    setState(() {
      tabText = 'Welcome';
      displayList.clear();
      displayCache.clear();
      displayList.add(new DisplayItem(null, 'Welcome To mStream', 'addServer', '', Icon(Icons.add, color: Colors.black), 'Click here to add server'));
    });
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Add a status bar to side menu.  Use it to display available space
    return new WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF212121),
          bottom: TabBar(
            labelColor: Color(0xFFffab00),
            indicatorColor: Color(0xFFffab00),
            unselectedLabelColor: Color(0xFFcccccc),
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
              Text( currentServer < 0 ? 'mStream Music' : serverList[currentServer].nickname),
              Visibility(
                visible: currentServer < 0 ? false : true,
                child: Text(
                  currentServer < 0 ? '' : serverList[currentServer].url,
                  style: TextStyle(fontSize: 12.0),
                ),
              ),
            ],
          ),
          actions: <Widget> [
            new PopupMenuButton(
              onSelected: (Server selectedServer) {
                  _tabController.animateTo(0);
                  tabText = 'Go To';
                  currentServer = serverList.indexOf(selectedServer);             
                  
                  displayCache.clear();
                  displayList.clear();
                  List<DisplayItem> newList = new List();
                  DisplayItem newItem1 = new DisplayItem(serverList[currentServer], 'File Explorer', 'execAction', 'fileExplorer', Icon(Icons.folder, color: Color(0xFFffab00)), null);
                  DisplayItem newItem2 = new DisplayItem(serverList[currentServer], 'Playlists', 'execAction', 'playlists', Icon(Icons.queue_music, color: Colors.black), null);
                  DisplayItem newItem3 = new DisplayItem(serverList[currentServer], 'Albums', 'execAction', 'albums', Icon(Icons.album, color: Colors.black), null);
                  DisplayItem newItem4 = new DisplayItem(serverList[currentServer], 'Artists', 'execAction', 'artists', Icon(Icons.library_music, color: Colors.black), null);
                  DisplayItem newItem5 = new DisplayItem(serverList[currentServer], 'Rated', 'execAction', 'rated', Icon(Icons.star, color: Colors.black), null);
                  DisplayItem newItem6 = new DisplayItem(serverList[currentServer], 'Recent', 'execAction', 'recent', Icon(Icons.query_builder, color: Colors.black), null);

                  displayList.add(newItem1);
                  newList.add(newItem1);
                  displayList.add(newItem2);
                  newList.add(newItem2);
                  displayList.add(newItem3);
                  newList.add(newItem3);
                  displayList.add(newItem4);
                  newList.add(newItem4);
                  displayList.add(newItem5);
                  newList.add(newItem5);
                  displayList.add(newItem6);
                  newList.add(newItem6);

                  displayCache.add(newList);
                  setState(() {});
              },
              icon: Icon(Icons.cloud),
              itemBuilder: (BuildContext context) { 
                return serverList.map((server) {
                  return PopupMenuItem(
                    value: server,
                    child: Text(server.nickname.length > 0 ? server.nickname : server.url, style: new TextStyle(color: Colors.black)),
                  );
                }).toList();
              },
            ),
            IconButton (
              icon: Icon(Icons.add),
              onPressed: (){
                Navigator.push(context, MaterialPageRoute(builder: (context) => AddServerScreen()));
              }
            ),
          ]
        ),
        drawer: Drawer(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget> [
              ListTile(
                title: Text('mStream Music', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 28, color: Color(0xFFffab00)),),
                onTap: () { },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.folder),
                title: Text('File Explorer', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17),),
                onTap: () {
                  if(serverList.length > 0) {
                    getFileList("", wipeBackCache: true);
                  }else {
                    _setupStartScreen();
                  }
                  Navigator.of(context).pop();
                  _tabController.animateTo(0);
                },
              ),
              ListTile(
                title: Text('Playlists', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: Icon(Icons.queue_music),
                onTap: () {
                  if(serverList.length > 0) {
                    getPlaylists(wipeBackCache: true);
                  }else {
                    _setupStartScreen();
                  }
                  Navigator.of(context).pop();
                  _tabController.animateTo(0);
                },
              ),
              ListTile(
                title: Text('Artists', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: Icon(Icons.library_music),
                onTap: () {
                  if(serverList.length > 0) {
                    getArtists(wipeBackCache: true);
                  }else {
                    _setupStartScreen();
                  }
                  Navigator.of(context).pop();
                  _tabController.animateTo(0);
                },
              ),
              ListTile(
                title: Text('Albums', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: Icon(Icons.album),
                onTap: () {
                  if(serverList.length > 0) {
                    getAllAlbums(wipeBackCache: true);
                  }else {
                    _setupStartScreen();
                  }
                  Navigator.of(context).pop();
                  _tabController.animateTo(0);
                },
              ),
              ListTile(
                title: Text('Starred', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: Icon(Icons.star),
                onTap: () {
                  if(serverList.length > 0) {
                    getStarredSongs(wipeBackCache: true);
                  }else {
                    _setupStartScreen();
                  }
                  Navigator.of(context).pop();
                  _tabController.animateTo(0);
                },
              ),
              ListTile(
                title: Text('Recent', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: Icon(Icons.query_builder),
                onTap: () {
                  if(serverList.length > 0) {
                    getRecentSongs(wipeBackCache: true);
                  }else {
                    _setupStartScreen();
                  }
                  Navigator.of(context).pop();
                  _tabController.animateTo(0);
                },
              ),
              Divider(),
              ListTile(
                title: Text('Local Files', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: Icon(Icons.folder_open),
                onTap: () {
                  getLocalFiles(null, wipeBackCache: true);
                  Navigator.of(context).pop();
                  _tabController.animateTo(0);
                },
              ),
              ListTile(
                title: Text('Manage Servers', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: Icon(Icons.router),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ManageServersScreen()), );
                },
              ),
              ListTile(
                title: Text('About mStream', style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
                leading: Icon(Icons.equalizer),
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
          color: Color(0xFF212121),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                height: 8,
              ),
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
                    backgroundColor: Color(0xFF484848),
                    valueColor: new AlwaysStoppedAnimation(Color(0xFFc67c00)),
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
                      IconButton(color: Color(0xFFffab00), icon: (mStreamAudio.playing == false) ? Icon(Icons.play_arrow) : Icon(Icons.pause), onPressed: () {
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
                      IconButton(icon: Icon(Icons.repeat, color: (mStreamAudio.shouldLoop == true) ? Colors.blue : Colors.white), onPressed: () {
                        setState(() {
                          mStreamAudio.toggleRepeat();
                        });
                      }),
                      IconButton(icon: Icon(Icons.shuffle), color: (mStreamAudio.shuffle == true) ? Colors.blue : Colors.white, onPressed: () {
                        setState(() {
                          mStreamAudio.toggleShuffle();
                        });
                      }),
                      // IconButton(icon: Icon(Icons.speaker), onPressed: () {},),
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
  bool _isUpdate = false;
  Directory useThisDir;

  TextEditingController _urlCtrl = new TextEditingController();
  TextEditingController _usernameCtrl = new TextEditingController();
  TextEditingController _passwordCtrl = new TextEditingController();
  TextEditingController _serverNameCtrl = new TextEditingController();

  checkServer() async {
    Uri lol = Uri.parse(this._urlCtrl.text);
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
      response = await http.post(lol.resolve('/login').toString(), body: {"username": this._usernameCtrl.text, "password": this._passwordCtrl.text});
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

  Future<void> saveServer(String origin, [String jwt='']) async {
    bool shouldUpdate = false;
    try {
      serverList[editThisServer];
      shouldUpdate = true;
    } catch (err) {

    }

    if(shouldUpdate) {
      serverList[editThisServer].url = _urlCtrl.text;
      serverList[editThisServer].nickname = _serverNameCtrl.text;
      serverList[editThisServer].password = _passwordCtrl.text;
      serverList[editThisServer].username = _usernameCtrl.text;
    }else {
      Server woo = new Server(origin, this._serverNameCtrl.text, this._usernameCtrl.text, this._passwordCtrl.text, jwt, this._serverNameCtrl.text);
      serverList.add(woo);

      // Create server directory
      var file = await getApplicationDocumentsDirectory();
      String dir = path.join(file.path, 'media/' + this._serverNameCtrl.text);
      await new Directory(dir).create(recursive: true);
      currentServer = serverList.length - 1;
      redrawServerFlag.value = !redrawServerFlag.value;
    }

    // Save Server List
    writeServerFile();
    Navigator.pop(context);
  }

    @override
  void initState() {
    super.initState();
    getApplicationDocumentsDirectory().then((filepath) {
      useThisDir = filepath;
    });
  }

  Map<String, String> parseQrCode(String qrValue) {
    if(qrValue[0] != '|') {
      throw new Error();
    }

    List<String> explodeArr = qrValue.split("|");
    if(explodeArr.length < 5) {
      throw new Error();
    }

    return {
      'url': explodeArr[1],
      'username': explodeArr[2],
      'password': explodeArr[3],
      'serverName': explodeArr[4]
    };
  }

  @override
  Widget build(BuildContext context) {
    // Build a Form widget using the _formKey we created above
    try {
      serverList[editThisServer];
      _urlCtrl.text = serverList[editThisServer].url;
      _usernameCtrl.text = serverList[editThisServer].username;
      _passwordCtrl.text = serverList[editThisServer].password;
      _serverNameCtrl.text = serverList[editThisServer].nickname;
      _isUpdate = true;
    } catch (err) {
      
    }

    return Container(
      color: Color(0xFF3f3f3f),
      padding: EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              controller: _urlCtrl,
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
              decoration: InputDecoration(
                hintText: 'https://mstream.io',
                labelText: 'Server URL',
              ),
              onSaved: (String value) {
                this._urlCtrl.text = value;
              }
            ),
            TextFormField(
              enabled: !_isUpdate,
              controller: _serverNameCtrl,
              validator: (value) {
                if (value.isEmpty) {
                  return 'Server Name is Required For File Syncing';
                }

                if(_isUpdate != true) {
                  // Check against the directory
                  String dir = path.join(useThisDir.path, 'media/' + value);
                  if (new Directory(dir).existsSync() == true) {
                    return 'Pathname Already Exists';
                  }
                  return RegExp(r"^[a-zA-Z0-9_\- ]*$").hasMatch(value) ? null : 'No Special Characters';
                }
              },
              keyboardType: TextInputType.emailAddress,
              decoration: new InputDecoration(
                labelText: 'Server Name',
                hintText: 'A Unique Name'
              ),
              onSaved: (String value) {
                this._serverNameCtrl.text = value;
              }
            ),
            Container(
              width: MediaQuery.of(context).size.width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Expanded(child:
                    TextFormField(
                      controller: _usernameCtrl,
                      validator: (value) {

                      },
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Username',
                        labelText: 'Username'
                      ),
                      onSaved: (String value) {
                        this._usernameCtrl.text = value;
                      }
                    )
                  ),
                  Container(width: 8), // Make a gap between the buttons
                  Expanded(child:
                    TextFormField(
                      controller: _passwordCtrl,              
                      validator: (value) {

                      },
                      obscureText: true, // Use secure text for passwords.
                      decoration: InputDecoration(
                        hintText: 'Password',
                        labelText: 'Password'
                      ),
                      onSaved: (String value) {
                        this._passwordCtrl.text = value;
                      }
                    )
                  ),

                ]
              )
            ),
            Container(height: 20,),
            Container(
              width: MediaQuery.of(context).size.width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Expanded(child: 
                    RaisedButton(
                      color: Colors.blue,
                      child: Row( 
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.photo_camera, color: Colors.white),
                          Container(width: 8),
                          Text('QR Code', style: TextStyle(color: Colors.white)),
                        ]
                      ),
                      onPressed: () {
                        new QRCodeReader().scan().then((qrValue) {
                          if(qrValue == null || qrValue == '') {
                            return;
                          }

                          try {
                            Map<String, String> parsedValues = parseQrCode(qrValue);
                            _urlCtrl.text = parsedValues['url'];
                            _usernameCtrl.text = parsedValues['username'];
                            _passwordCtrl.text = parsedValues['password'];
                            if(!_isUpdate) {
                              _serverNameCtrl.text = parsedValues['serverName'];
                            }
                          } catch(err) {
                            Scaffold.of(context).showSnackBar(SnackBar(content: Text('Invalid Code')));
                          }
                        });
                      },
                    ),
                  ),
                  Container(width: 8), // Make a gap between the buttons
                  Expanded(child:
                    RaisedButton(
                      color: Colors.green,
                      child: Text('Save', style: TextStyle(color: Colors.white)),
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
                    ),
                  ),
                ]
              ),
              margin: EdgeInsets.only(top: 20.0),
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
      body: Container(
        padding: EdgeInsets.all(40.0),
        child: ListView(
          children: [
            Image(image: AssetImage('graphics/mstream-logo.png')),
            Container(height: 15,),
            Text('mStream Mobile v0.5',  style: TextStyle(fontFamily: 'Jura', color: Color(0xFF000000), fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Beta Edition',  style: TextStyle(fontFamily: 'Jura', color: Color(0xFF000000), fontWeight: FontWeight.bold, fontSize: 20)),
            Container(height: 45,),
            Text('Developed By:',  style: TextStyle(fontFamily: 'Jura', color: Color(0xFF000000), fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Paul Sori',  style: TextStyle(fontFamily: 'Jura', color: Color(0xFF000000), fontWeight: FontWeight.bold, fontSize: 20)),
            Text('paul@mstream.io',  style: TextStyle(fontFamily: 'Jura', color: Color(0xFF000000), fontWeight: FontWeight.bold, fontSize: 20)),
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
      return Text('You don\'t have a playlist to share!',  style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black));
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
          Text('Shared playlists expire after 14 days',  style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
          Container(height: 40,),
          RaisedButton(
            padding: const EdgeInsets.all(8.0),
            onPressed: () {
              _callOnPressed();
            },
            child: Text(shareButtonText),
          ),
          Container(height: 28),
          Text(shareLink, style: TextStyle(fontSize: 16, color: Colors.black))
        ]
      );
    }else {
      showThis = Text('Your playlist contains mixed server content.\n\nYou cannot share a mixed content playlist for security reasons',  style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black));
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
      body: Container(
        padding: EdgeInsets.all(40.0),
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
      body: Container(
        padding: EdgeInsets.all(40.0),
        child: ListView(
          children: [
            Text('Save Playlist Goes Here',  style: TextStyle(fontFamily: 'Jura', fontWeight: FontWeight.bold, fontSize: 17)),
            DropdownButton(
              hint: Text("New Playlist"),
              value: null,
              onChanged: (Server newServer) {
                selectedServer = newServer;
              },
              items: serverList.map((Server server) {
                return DropdownMenuItem<Server>(
                  value: server,
                  child: Text(
                    server.nickname,
                    style: TextStyle(color: Colors.black),
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

class ManageServersScreenState extends State<ManageServersScreen> {
  Future<void> _deleteServeDirectory(Server removedServer) async {
    final directory = await getApplicationDocumentsDirectory();
    var dir = new Directory(path.join(directory.path.toString(), 'media/' + removedServer.localname));
    dir.delete(recursive: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Servers"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AddServerScreen()), );
        },
        child: Icon(Icons.add),
        backgroundColor: Color(0xFFFFAB00),
      ),
      body: Row(
        children: [Expanded(
          child: SizedBox(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics (),
              itemCount: serverList.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(serverList[index].nickname, style: TextStyle(color: Colors.black, fontSize: 18)),
                  subtitle:  Text(serverList[index].url, style: TextStyle(color: Colors.black),),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:[
                      IconButton(icon: Icon(Icons.edit), color: Color(0xFF212121), tooltip: 'Edit Server', onPressed: () {
                        editThisServer = index;
                        Navigator.push(context, MaterialPageRoute(builder: (context) => EditServerScreen()), );
                      }),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.redAccent,),
                        tooltip: 'Delete Server',
                        onPressed: () { 
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              // return object of type Dialog
                              return AlertDialog(
                                title: Text("Confirm Remove Server"),
                                content: Row(children: <Widget>[
                                  DeleteServerAlertForm(),
                                  Flexible(child: Text("Remove synced files from device?"))
                                ]),
                                actions: <Widget>[
                                  FlatButton(
                                    child: Text("Go Back"),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  FlatButton(
                                    child: Text("Delete", style: TextStyle(color: Colors.red),),
                                    onPressed: () {
                                      try {
                                        serverList[index];
                                        Server removedServer = serverList.removeAt(index);
                                        setState(() {
                                        });
                                        writeServerFile();

                                        // Handle case were all servers are removed
                                        if (serverList.length == 0) {
                                          tabText = 'Welcome';
                                          displayList.clear();
                                          displayCache.clear();
                                          displayList.add(new DisplayItem(null, 'Welcome To mStream', 'addServer', '', Icon(Icons.add, color: Colors.black), 'Click here to add server'));
                                          setState(() {
                                            currentServer = -1;
                                          });
                                        } else if(currentServer == index) { // Handle case where user removes the current server
                                          redrawServerFlag.value = !redrawServerFlag.value;
                                          setState(() {
                                            currentServer = 0;
                                          });
                                        }else if (currentServer > index) { // Handle case where curent server is after removed index
                                          setState(() {
                                            currentServer = currentServer -1;
                                          });
                                        }

                                        // Delete files
                                        if(isRemoveFilesOnServerDeleteSelected == true) {
                                          _deleteServeDirectory(removedServer);
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

class RateDialogContent extends StatefulWidget {
  RateDialogContent({
    Key key,
    this.queueItem,
  }): super(key: key);

  final QueueItem queueItem;

  @override
  _RateDialogContentState createState() => new _RateDialogContentState();
}

class _RateDialogContentState extends State<RateDialogContent> {

  @override
  void initState(){
    super.initState();
    widget.queueItem.tempRating = widget.queueItem.getRating();
  }

  _getContent(){
    return new SmoothStarRating(
      allowHalfRating: true,
      onRatingChanged: (v) {
        setState(() {
          widget.queueItem.tempRating = (v*2).toInt();
        });
      },
      starCount: 5,
      rating: widget.queueItem.getDisplayRating(),
      size: 40.0,
      color: Colors.green,
      borderColor: Colors.green,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _getContent();
  }
}

class DeleteServerAlertForm extends StatefulWidget {
  DeleteServerAlertForm({Key key}): super(key: key);

  @override
  _DeleteServerAlertFormState createState() => new _DeleteServerAlertFormState();
}

bool isRemoveFilesOnServerDeleteSelected = false;
class _DeleteServerAlertFormState extends State<DeleteServerAlertForm> {
  @override
  void initState() {
    isRemoveFilesOnServerDeleteSelected = false;
  }

  @override
  Widget build(BuildContext context) {
    return new Checkbox(value: isRemoveFilesOnServerDeleteSelected, onChanged: (bool value) {
      setState(() {
        isRemoveFilesOnServerDeleteSelected = !isRemoveFilesOnServerDeleteSelected;
      });
    });
  }
}