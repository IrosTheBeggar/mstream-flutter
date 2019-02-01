import 'package:flutter/material.dart';
import 'server.dart';
import 'metadata.dart';

class DisplayItem {
  final Server server;
  final String type;
  final String data;

  String name;
  String subtext;
  Icon icon;
  MusicMetadata metadata;

  Widget getText() {
    if(metadata != null && metadata.title != null) {
      return Text(metadata.title);
    }
    return new Text(this.name);
  }

  Widget getSubText() {
    if(metadata != null && metadata.artist != null) {
      return Text(metadata.artist);
    }
    if (subtext != null) {
      return new Text(this.subtext);
    }
    return null;
  }

  DisplayItem(this.server, this.name, this.type, this.data, this.icon, this.subtext);

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
