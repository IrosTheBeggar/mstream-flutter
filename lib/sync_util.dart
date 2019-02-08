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
      print(status.toString());
      if(status.toString() == 'DownloadTaskStatus(3)') {
        // TODO: Update UI
      }
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

    String lol =  path.dirname( '${dir.path}/media/${downloadDirectory}' );
    String filename = path.basename( '${dir.path}/media/${downloadDirectory}' );
    new Directory(lol).createSync(recursive: true);
    Uri url = Uri.parse(downloadUrl);

    final taskId = await FlutterDownloader.enqueue(
      url: url.toString(),
      fileName: filename,
      savedDir: lol,
      showNotification: false, // show download progress in status bar (for Android)
      openFileFromNotification: false, // click on notification to open downloaded file (for Android)
    );

    idTracker[taskId] = downloadDirectory;
    downloadTracker[downloadDirectory] = {
      'progress': null,
      'taskId': taskId,
      'serverUrl': serverObj.url
    };
  }

  void syncDirectory() {
    // 
  }

  SyncUtil();
}