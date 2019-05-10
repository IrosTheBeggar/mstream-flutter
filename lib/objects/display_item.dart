import 'package:flutter/material.dart';
import 'server.dart';
import 'metadata.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DisplayItem {
  final Server server;
  final String type;
  final String data;

  String name;
  String subtext;
  Icon icon;
  MusicMetadata metadata;

  int downloadProgress = 0;

  Widget getText() {
    if(metadata != null && metadata.title != null) {
      return Text(metadata.title, style: TextStyle(fontFamily: 'Jura', fontSize: 18, color: Colors.black),);
    }

    if(this.name == null && this.type =='album') {
      return new Text('SINGLES', style: TextStyle(fontFamily: 'Jura', fontSize: 18, color: Colors.black));
    }

    if(type == 'file' || type == 'localFile'){
      return new Text(this.name, style: TextStyle( fontSize: 18, color: Colors.black));      
    }
    return new Text(this.name, style: TextStyle(fontFamily: 'Jura', fontSize: 18, color: Colors.black));
  }

  Widget getSubText() {
    if(metadata != null && metadata.artist != null) {
      return Text(metadata.artist, style: TextStyle( fontSize: 16, color: Colors.black),);
    }
    if (subtext != null) {
      return new Text(this.subtext, style: TextStyle( fontSize: 16, color: Colors.black),);
    }
    return null;
  }

  DisplayItem(this.server, this.name, this.type, this.data, this.icon, this.subtext){
    if(this.type == 'file') {
      String downloadDirectory = this.server.localname + this.data;
      getApplicationDocumentsDirectory().then((dir) {
        String finalString = '${dir.path}/media/${downloadDirectory}';
        if (new File(finalString).existsSync() == true) {
          this.downloadProgress = 100;
        }
      });
    }
  }

  DisplayItem.fromJson(Map<String, dynamic> json)
    : name = json['name'],
      type = json['type'],
      server = json['server'],
      subtext = json['subtext'],
      data = json['data'];

  Map<String, dynamic> toJson() =>
    {
      'name': name,
      'server': server,
      'type': type,
      'subtext': subtext,
      'data': data
    };
}
