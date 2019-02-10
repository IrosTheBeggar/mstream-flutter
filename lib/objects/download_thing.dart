class DownloadThing {
  String serverUrl;
  int progress;
  String downloadDirectory;

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
