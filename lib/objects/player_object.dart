import 'package:audioplayers/audioplayers.dart';
import 'package:mstream_flutter/objects/queue_item.dart';

class PlayerObjectX {
  String playerType;
  AudioPlayer playerObject;
  QueueItem songObject;

  Duration duration = new Duration(seconds: 0);
  Duration postion = new Duration(seconds: 0);

  PlayerObjectX(this.playerType, this.playerObject, this.songObject);
}
