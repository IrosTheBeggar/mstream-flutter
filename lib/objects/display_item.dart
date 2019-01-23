import 'package:flutter/material.dart';

class DisplayItem {
  final String name;
  final String type;
  final String subtext;
  final String data;
  Icon icon;

  DisplayItem(this.name, this.type, this.data, this.icon, this.subtext);

  DisplayItem.fromJson(Map<String, dynamic> json)
      : name = json['url'],
        type = json['jwt'],
        subtext = json['username'],
        data = json['password'];

  Map<String, dynamic> toJson() =>
    {
      'name': name,
      'type': type,
      'subtext': subtext,
      'data': data
    };
}
