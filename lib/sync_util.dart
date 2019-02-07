import 'dart:async';
import 'dart:io';
import 'objects/server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path/path.dart' as path;

class SyncUtil {
  Map downloadTracker = {};
  Map idTracker = {};

  initBasic() {
    FlutterDownloader.registerCallback((id, status, progress) {
      print('Download task ($id) is in status ($status) and process ($progress)');
      // Update the trackers

      // ? Redraw like how we redraw playlists
    });
  }

  disposeBasic() {
    FlutterDownloader.registerCallback(null);
  }

  Future<void> downloadOneFile(Server serverObj, String serverPath) async {
    // download each file relative to its path
    String downloadUrl = serverObj.url + '/media' + serverPath + '?token=' + serverObj.jwt;
    String downloadDirectory = serverObj.localname + serverPath;
    final dir = await getApplicationDocumentsDirectory();

    final taskId = await FlutterDownloader.enqueue(
      url: downloadUrl.replaceAll(new RegExp(r"\s+\b|\b\s"), ""),
      savedDir: '${dir.path}/${downloadDirectory}',
      showNotification: false, // show download progress in status bar (for Android)
      openFileFromNotification: false, // click on notification to open downloaded file (for Android)
    );

    idTracker[taskId] = downloadDirectory;
    downloadTracker[downloadDirectory] = {
      'progress': null,
      'taskId': taskId
    };
  }

  Future<void> downloadOneFile2(Server serverObj, String serverPath) async {
    print(serverPath);
    // download each file relative to its path
    String downloadUrl = serverObj.url + '/media' + serverPath + '?token=' + serverObj.jwt;
    String downloadDirectory = serverObj.localname + serverPath;
    final dir = await getApplicationDocumentsDirectory();

    final bytes = await http.readBytes(downloadUrl);
    new File('${dir.path}/media/${downloadDirectory}').createSync(recursive: true);
    var file = new File('${dir.path}/media/${downloadDirectory}');    
    return await file.writeAsBytes(bytes);
  }

  void syncPlaylist() {
    // 
  }

  void syncDirectory() {
    // 
  }

  SyncUtil();
}