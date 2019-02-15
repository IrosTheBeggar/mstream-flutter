import 'queue_item.dart';
import 'display_item.dart';

class DownloadThing {
  String serverUrl;
  int progress;
  String downloadDirectory;

  // These can be set to update downlaod progress for a particular item
  // you should always check if these exist before using them
  QueueItem referenceQueueItem;
  DisplayItem referenceDisplayItem;

  DownloadThing(this.serverUrl, this.progress, this.downloadDirectory);

  DownloadThing.fromJson(Map<String, dynamic> json)
      : serverUrl = json['serverUrl'],
        progress = json['progress'],
        downloadDirectory = json['downloadDirectory'];

  Map<String, dynamic> toJson() =>
    {
      'serverUrl': serverUrl,
      'progress': progress,
      'downloadDirectory': downloadDirectory,
    };
}
