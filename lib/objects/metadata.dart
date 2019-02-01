class MusicMetadata {
  String artist;
  String album;
  String title;
  int track;
  int disc;
  int year;
  String hash;
  int rating;
  String albumArt;

  MusicMetadata(this.artist, this.album, this.title, this.track, this.disc, this.year, this.hash, this.rating, this.albumArt );

  MusicMetadata.fromJson(Map<String, dynamic> json)
    : artist = json['artist'],
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
