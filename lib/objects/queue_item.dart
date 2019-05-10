import 'package:uuid/uuid.dart';
import 'server.dart';
import 'metadata.dart';
import 'package:flutter/material.dart';

var uuid = new Uuid();

class QueueItem {
  final Server server;
  String filename;
  String url;
  String path;
  MusicMetadata metadata;
  int tempRating;  // For handling rating changes
  bool err = false;
  final String uuidString = uuid.v4();

  int downloadProgress = 0;
  String localFile;

  Widget getImage() {
    if(metadata != null && metadata.albumArt != null) {
      // return Image.network('https://picsum.photos/250?image=9');
      // TODO: Image re-sizing sucks right now
    }
    return new Icon(Icons.music_note, color: Colors.black,);
  }

  Widget getText() {
    String isCachedLocally = '';
    if(metadata != null && metadata.title != null) {
      return Text(isCachedLocally + metadata.title, style: TextStyle(fontFamily: 'Jura', fontSize: 18, color: Colors.black),);
    }

    return new Text(isCachedLocally + filename, style: TextStyle(fontFamily: 'Jura', fontSize: 18, color: Colors.black),);
  }

  Widget getSubText() {
    if(err == true) {
      return Text('Error: Could not play song', style: TextStyle(color: Colors.red));
    }

    if(metadata != null && metadata.artist != null) {
      return Text(metadata.artist, style: TextStyle(color: Colors.black));
    }
    return Text('');
  }

  int getRating() {
    return (metadata != null && metadata.rating != null) ? metadata.rating : 0;
  }

  double getDisplayRating() {
    if(tempRating != null) {
      return tempRating/2;
    }else {
      return (metadata != null && metadata.rating != null) ? metadata.rating/2 : 0;
    }
  }

  QueueItem(this.server, this.filename, this.url, this.path, this.metadata);

  QueueItem.fromJson(Map<String, dynamic> json)
    : filename = json['filename'],
      url = json['url'],
      path = json['path'],
      server = json['server'],
      metadata = json['metadata'];

  Map<String, dynamic> toJson() =>
    {
      'filename': filename,
      'url': url,
      'path': path,
      'server': server,      
      'metadata': metadata
    };
}
