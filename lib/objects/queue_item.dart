import 'package:uuid/uuid.dart';
var uuid = new Uuid();

class QueueItem {
  String filename;
  String url;
  String artist;
  String album;
  String title;
  int track;
  int disc;
  int year;
  String hash;
  int rating;
  String albumArt;
  bool error;
  final String uuidString = uuid.v4();

  QueueItem(this.filename, this.url, this.artist, this.album, this.title, this. track, this.disc, this.year, this.hash, this.rating, this.albumArt );

  QueueItem.fromJson(Map<String, dynamic> json)
    : filename = json['filename'],
      url = json['url'],
      artist = json['artist'],
      album = json['album'],
      title = json['title'],
      track = json['track'],
      disc = json['disc'],
      year = json['year'],
      hash = json['hash'],
      rating = json['rating'],
      albumArt = json['albumArt'];

  Map<String, dynamic> toJson() =>
    {
      'filename': filename,
      'url': url,
      'artist': artist,
      'album': album,
      'title': title,
      'track': track,
      'disc': disc,
      'year': year,
      'hash': hash,
      'rating': rating,
      'albumArt': albumArt,
    };
}
