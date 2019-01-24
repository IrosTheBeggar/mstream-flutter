import 'package:audioplayers/audioplayers.dart';
import 'package:mstream_flutter/objects/queue_item.dart';

class PlayerObjectX {
  String playerType;
  AudioPlayer playerObject;
  QueueItem songObject;

  PlayerObjectX(this.playerType, this.playerObject, this.songObject);
}
