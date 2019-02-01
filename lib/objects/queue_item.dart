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
  bool error = false;
  final String uuidString = uuid.v4();

  Widget getImage() {
    if(metadata != null && metadata.albumArt != null) {
      // return Image.network('https://picsum.photos/250?image=9');
      // TODO: Image re-sizing sucks right now
    }
    return new Icon(Icons.music_note);
  }

  Widget getText() {
    if(metadata != null && metadata.title != null) {
      return Text(metadata.title);
    }

    return new Text(this.filename);
  }

  Widget getSubText() {
    if(metadata != null && metadata.artist != null) {
      return Text(metadata.artist);
    }
    return null;
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
