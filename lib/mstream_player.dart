import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'player_widget.dart';
import 'dart:math';
import 'objects/queue_item.dart';
import 'package:mstream_flutter/objects/player_object.dart';


class MstreamPlayer {
  int positionCache = -1;
  List<QueueItem> playlist = new List();
  int cacheTimeout = 5;

  editSongMetadata() {
    // Stage 1
  }

  changeVolume() {
    // Stage 1
  }

  Timer scrobbleTimer;
  scrobble() {
    // Stage 3
    return false;
  }

  // DONE
  addSong(QueueItem newSong) {
    if(shuffle) {
      Random rnd = new Random();
      int pos = rnd.nextInt(shuffleCache.length);
      shuffleCache.insert(pos, newSong);
    }

    _addSongToPlaylist(newSong);
  }

  _getRandomSong() {
    // Stage 2
  }

  _autoDJ() {
    // Stage 2
  }

  // DONE
  _addSongToPlaylist(newSong) {
    playlist.add(newSong);

    // If this the first song in the list
    if (playlist.length == 1) {
      positionCache = 0;
      return _goToSong();
    }

    // TODO:  Cache song if appropriate
  }

  clearAndPlay() {
    // Stage 2
  }

  clearPlaylist() {
    playlist.length = 0;
    shuffleCache.length = 0;
    positionCache = -1;

    _clearEnd();

    if(autoDj) {
      _autoDJ();
    }

    return true;
  }

  // Done
  nextSong() {
    _goToNextSong();
  }

  previousSong() {
    _goToPreviousSong();
  }

  // Done
  goToSongAtPosition(index) {
    try {
      playlist[index];
    } catch (err) {
      return false;
    }

    _clearEnd();

    positionCache = index;
    _goToSong();
  }

  removeSongAtPosition() {
    // Stage 1
  }

  getCurrentSong() {
    // Stage 1
  }

  _goToPreviousSong() {
    // Stage 1
    if(shuffle == true) {
      // TODO: Shuffle    
    }

    // Make sure there is a previous song
    if (positionCache < 1) {
      return false;
    }

    _clearEnd();
    positionCache--;
    return _goToSong();
  }

  // DONE!
  _goToNextSong() {
    if(shuffle == true) {
      // TODO:
    }

    try {
      playlist[ positionCache + 1 ];
    } catch ( e ) {
      if(shouldLoop == true && playlist.length > 0) {
        positionCache = 0;
        return _goToSong();
      }
      playing = false;
      return false;
    }

    positionCache++;
    _clearEnd();
    return _goToSong();
  }

  PlayerObjectX playerA = new PlayerObjectX('default', new AudioPlayer(), null);
  PlayerObjectX playerB = new PlayerObjectX('default', new AudioPlayer(), null);
  String curP = 'A';

  PlayerObjectX getCurrentPlayer() {
    if (curP == 'A') {
      return playerA;
    } else if (curP == 'B') {
      return playerB;
    }

    return null;
  }

  PlayerObjectX getOtherPlayer() {
    if (curP == 'A') {
      return playerB;
    } else if (curP == 'B') {
      return playerA;
    }

    return null;
  }

  flipFlop() {
    if (curP == 'A') {
      curP = 'B';
    } else if (curP == 'B') {
      curP = 'A';
    }

    return curP;
  }

  var playbackRate = 1;
  var duration = 0;
  var currentTime = 0;
  var playing = false;
  var volume = 100;

  // DONE!
  _goToSong() {
    try {
      playlist[ positionCache ];
    } catch ( e ) {
      return false;
    }

    if(autoDj == true && positionCache == playlist.length - 1) {
      _autoDJ();
    }

    var localPlayerObject = getCurrentPlayer();
    var otherPlayerObject = getOtherPlayer();

    if (localPlayerObject.playerType == 'default') {
      localPlayerObject.playerObject.release();
    }

    if (otherPlayerObject.songObject == playlist[positionCache]) {
      flipFlop();
      // Play
      playPause();
    } else {
      _setMedia(playlist[positionCache], localPlayerObject, true);
    }

    resetCurrentMetadata();

    // TODO: This is a mess, figure out a better way
    var newOtherPlayerObject = getOtherPlayer();
    // newOtherPlayerObject.playerType = null;
    // newOtherPlayerObject.playerObject = null;
    newOtherPlayerObject.songObject = null;

    // Cache next song
    // The timer prevents excessive caching when the user starts button mashing
    if (cacheTimer != null) {
      cacheTimer.cancel();
    }
    cacheTimer = new Timer(new Duration(seconds: cacheTimeout), () => _setCachedSong(positionCache + 1));

    // Scrobble song after 30 seconds
    if (scrobbleTimer != null) {
      scrobbleTimer.cancel();    
    }
    scrobbleTimer = new Timer(new Duration(seconds: 30), () => scrobble());
    return true;
  }

  resetCurrentMetadata() {

  }

  resetPositionCache() {
    // Stage 1
  }

  _howlPlayerPlay() {
    PlayerObjectX localPlayer = getCurrentPlayer();
    playing = true;
    localPlayer.playerObject.resume();
  }

  _howlPlayerPlayPause() {
    PlayerObjectX localPlayer = getCurrentPlayer();

    // TODO: Check that media is loaded
    if (playing == true) {
      playing = false;
      localPlayer.playerObject.pause();
    } else {
      localPlayer.playerObject.resume();
      playing = true;
    }
  }

  // DONE!
  _clearEnd() {
    PlayerObjectX localPlayer = getCurrentPlayer();
    localPlayer.playerObject.completionHandler = () {
      return null;
    };
  }

  playPause() {
    PlayerObjectX localPlayer = getCurrentPlayer();

    if (localPlayer.playerType == 'default') {
      return _howlPlayerPlayPause();
    }
  }

  changePlaybackRate() {
    // Stage 2
  }

  // Done!
  _setMedia(QueueItem song, PlayerObjectX player, bool shouldPlay) {
    player.playerType = 'default';
    player.playerObject.setUrl(song.url);
    player.playerObject.completionHandler = () {
      _callMeOnStreamEnd();
    };

    player.songObject = song;
    if (shouldPlay == true) {
      _howlPlayerPlay();
    }
  }

  _callMeOnStreamEnd() {
    playing = false;
    _goToNextSong();
  }

  goBackSeek() {
    // Stage 2
  }

  goForwardSeek() {
    // Stage 2
  }

  seek() {
    // Stage 2
  }

  seekByPercentage() {
    // Stage 1
  }

  var sliderUpdateInterval;
  var timers = {};
  _startTime() {
    // Stage 1
  }

  // DONE!
  Timer cacheTimer;
  _setCachedSong(int position) {
    print('ATTEMPTING TO CACHE!');
    try {
      playlist[ position ];
    } catch ( e ) {
      print('FAILED TO CACHE!');
      return false;
    }

    // var oPlayer = getOtherPlayer();
    // _setMedia(playlist[position], oPlayer, false);
    print('IT CACHED!!');
    return true;
  }

  bool shouldLoop = false;
  setRepeat(bool newVal) {
    if (autoDj == true) {
      shouldLoop = false;
      return false;
    }
    shouldLoop = newVal;
    return shouldLoop;
  }

  toggleRepeat() {
    if (autoDj == true) {
      shouldLoop = false;
      return false;
    }
    shouldLoop = !shouldLoop;
    return shouldLoop;
  }

  bool shuffle = false;
  List shuffleCache = new List();
  List shufflePrevious = new List();
  setShuffle(){
    // Stage 1
  }

  toggleShuffle() {
    // Stage 1
  }

  _newShuffle() {
    // Stage 1
  }

  _turnShuffleOff() {
    // Stage 1
  }

  _shuffle() {
    // Stage 1  
  }

  var autoDjIgnoreArray = new List();
  bool autoDj = false;
  toggleAutoDJ() {
    // Stage 2
  }

  _setErrHandle() {
    playerA.playerObject.completionHandler = () {
      playerA.songObject.error = true;
      // TODO: Toast

      PlayerObjectX currentPlayer = getCurrentPlayer();
      if (playerA == currentPlayer) {
        _goToNextSong();
      }else {
        // Invalidate cache
        var newOtherPlayerObject = getOtherPlayer();
        // newOtherPlayerObject.playerType = false;
        // newOtherPlayerObject.playerObject = false;
        newOtherPlayerObject.songObject = null;
      }
    };

    playerB.playerObject.completionHandler = () {
      playerB.songObject.error = true;
      // TODO: Toast

      PlayerObjectX currentPlayer = getCurrentPlayer();
      if (playerB == currentPlayer) {
        _goToNextSong();
      }else {
        // Invalidate cache
        var newOtherPlayerObject = getOtherPlayer();
        // newOtherPlayerObject.playerType = false;
        // newOtherPlayerObject.playerObject = false;
        newOtherPlayerObject.songObject = null;
      }
    };
  }

  MstreamPlayer();
}



