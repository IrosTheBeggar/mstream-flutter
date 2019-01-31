import 'package:flutter/material.dart';
import 'server.dart';

class DisplayItem {
  final String name;
  final String type;
  final String subtext;
  final String data;
  final Server server;
  Icon icon;

  DisplayItem(this.server, this.name, this.type, this.data, this.icon, this.subtext);

  DisplayItem.fromJson(Map<String, dynamic> json)
      : name = json['url'],
        type = json['jwt'],
        server = json['server'],
        subtext = json['username'],
        data = json['password'];

  Map<String, dynamic> toJson() =>
    {
      'name': name,
      'server': server,
      'type': type,
      'subtext': subtext,
      'data': data
    };
}
