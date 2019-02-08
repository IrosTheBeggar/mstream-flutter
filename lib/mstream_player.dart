import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';
import 'objects/queue_item.dart';
import 'package:mstream_flutter/objects/player_object.dart';


class MstreamPlayer {
  int positionCache = -1;
  List<QueueItem> playlist = new List();
  int cacheTimeout = 16;

  ValueNotifier rpf;
  setFlag(ValueNotifier flag){
    rpf = flag;
  }

  // ValueNotifier rpf2;
  // setFlag2(flag) {
  //   rpf2 = flag;
  // }

  editSongMetadata() {
    // Stage 1
  }

  Timer scrobbleTimer;
  scrobble() {
    // Stage 3
    return false;
  }

  addSong(QueueItem newSong) {
    if(shuffle) {
      Random rnd = new Random();
      if(shuffleCache.length == 0) {
        shuffleCache.add(newSong);
      }else {
        int pos = rnd.nextInt(shuffleCache.length);
        shuffleCache.insert(pos, newSong);
      }
    }

    _addSongToPlaylist(newSong);
  }

  _getRandomSong() {
    // Stage 2
  }

  _autoDJ() {
    // Stage 2
  }

  // MISSING SOME STUFF
  _addSongToPlaylist(newSong) {
    playlist.add(newSong);

    // If this the first song in the list
    if (playlist.length == 1) {
      positionCache = 0;
      return _goToSong();
    }

    // Cache song if appropriate
    PlayerObjectX oPlayer = getOtherPlayer();
    if ((oPlayer.songObject == null && cacheTimer == null)) {
      try {
        playlist[positionCache + 1]; // Check if this exists
        if (cacheTimer != null) {
          cacheTimer.cancel();
        }
        cacheTimer = new Timer(new Duration(seconds: cacheTimeout), () {
          _setCachedSong(positionCache + 1);
        });
      }catch (err) {

      }
    }
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

  nextSong() {
    _goToNextSong();
  }

  previousSong() {
    _goToPreviousSong();
  }

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

  removeSongAtPosition(int position) {
    // Check that position is filled
    if (position > playlist.length || position < 0) {
      return false;
    }

    QueueItem removedSong = playlist.removeAt(position);

    if(shuffle == true) {
      //  Remove song from shuffle Cache
      for (var i = 0, len = shuffleCache.length; i < len; i++) {
        // Check if this is the current song
        if (removedSong == shuffleCache[i]) {
          shuffleCache.removeAt(i);
        }
      }
      for (var i = 0, len = shufflePrevious.length; i < len; i++) {
        // Check if this is the current song
        if (removedSong == shufflePrevious[i]) {
          shufflePrevious.removeAt(i);
        }
      }
    }

    // Handle case where user removes current song and it's the last song in the playlist
    if (position == positionCache && position == playlist.length) {
      _clearEnd();
      if(shuffle == true) {
        _goToNextSong();
      } else if (shouldLoop == true) {
        positionCache = 0;
        _goToSong();
      } else {
        positionCache = -1;
      }
    } else if (position == positionCache) { // User removes currently playing song
      _clearEnd();
      // If random is set, go to random song
      if (shuffle == true) {
        _goToNextSong();
      } else {
       _goToSong();
      }
    } else if (position < positionCache) {
      positionCache--;
    } else if (position == (positionCache + 1)) {
      if (cacheTimer != null) {
        cacheTimer.cancel();
      }
      // cacheTimer = new Timer(new Duration(seconds: cacheTimeout), () => _setCachedSong(positionCache + 1));
      cacheTimer = new Timer(new Duration(seconds: cacheTimeout), () {
        if(shuffle == true) {
          try {
            shuffleCache[0];
            for (int i = 0; i < playlist.length; i++) {
              if(playlist[i] == shuffleCache[0]) {
                _setCachedSong(i);
                break;
              }
            }
          }catch (err) {

          }
        } else if (shouldLoop == true) {
          if (positionCache == (playlist.length - 1)) {
            _setCachedSong(0);
          }  else {
            _setCachedSong(positionCache + 1);
          }
        } else {
          _setCachedSong(positionCache + 1);
        }
      });
    }
  }

  QueueItem getCurrentSong() {
    PlayerObjectX lPlayer = getCurrentPlayer();
    return lPlayer.songObject;
  }

  _goToPreviousSong() {
    if(shuffle == true) {
      if (shufflePrevious.length <= 1) {
        return false;
      }

      QueueItem nextSong = shufflePrevious.removeLast();
      shuffleCache.add(nextSong);

      QueueItem currentSong = shufflePrevious[shufflePrevious.length - 1];

      // Reset Postion Cache
      for (var i = 0, len = playlist.length; i < len; i++) {
        // Check if this is the current song
        if (currentSong == playlist[i]) {
          positionCache = i;
        } 
      }

      _clearEnd();
      _goToSong();
      return true;
    }

    // Make sure there is a previous song
    if (positionCache < 1) {
      return false;
    }

    _clearEnd();
    positionCache--;
    return _goToSong();
  }

  _goToNextSong() {
    if(shuffle == true) {
      QueueItem nextSong = shuffleCache.removeLast();

      // Prevent same song from playing twice after a re-shuffle
      if (nextSong == getCurrentSong()) {
        shuffleCache.insert(0, nextSong);
        nextSong = shuffleCache.removeLast();
      }

      if (shuffleCache.length == 0) {
        _newShuffle();
      }

      // Reset position cache
      for (int i = 0, len = playlist.length; i < len; i++) {
        // Check if this is the current song
        if (nextSong == playlist[i]) {
          positionCache = i;
        }
      }
      // Go To Song
      _clearEnd();
      _goToSong();

      // Remove duplicates from shuffle previous
      // for (int j = 0, len2 = shufflePrevious.length; j < len2; j++) {
      //   // Check if this is the current song
      //   if (nextSong == shufflePrevious[j]) {
      //     shufflePrevious.removeAt(j); // FIXME: Needs to be tested
      //   }
      // }

      shufflePrevious.add(nextSong);
      return true;
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

  String flipFlop() {
    if (curP == 'A') {
      curP = 'B';
    } else if (curP == 'B') {
      curP = 'A';
    }

    return curP;
  }

  var playbackRate = 1;
  Duration currentTime;
  bool playing = false;
  // var volume = 100;

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

    // Reset Duration
    // duration = new Duration(seconds: 0);
    currentTime = new Duration(seconds: 0);
    // if(rpf2 != null) {
    //   rpf2.value(0.0);
    // }

    if (localPlayerObject.playerType == 'default') {
      localPlayerObject.playerObject.release();
    }

    if (otherPlayerObject.songObject == playlist[positionCache]) {
      playing = false;
      flipFlop();
      // Play
      playPause();
    } else {
      _setMedia(playlist[positionCache], localPlayerObject, true);
    }

    resetCurrentMetadata();

    var newOtherPlayerObject = getOtherPlayer();
    // newOtherPlayerObject.playerType = null;
    // newOtherPlayerObject.playerObject = null;
    newOtherPlayerObject.songObject = null;
    // newOtherPlayerObject.playerObject.durationHandler = (Duration d) {
    //   return;
    // };
    // newOtherPlayerObject.playerObject.positionHandler = (Duration  p) {
    //   return;
    // };
    
    if(rpf != null) {
      rpf.value = !rpf.value;
    }

    // Cache next song
    // The timer prevents excessive caching when the user starts button mashing
    if (cacheTimer != null) {
      cacheTimer.cancel();
    }
    cacheTimer = new Timer(new Duration(seconds: cacheTimeout), () {
      if(shuffle == true) {
        try {
          shuffleCache[0];
          for (int i = 0; i < playlist.length; i++) {
            if(playlist[i] == shuffleCache[shuffleCache.length - 1]) {
              _setCachedSong(i);
              break;
            }
          }
        }catch (err) {

        }
      } else if (shouldLoop == true) {
        if (positionCache == (playlist.length - 1)) {
          _setCachedSong(0);
        }  else {
          _setCachedSong(positionCache + 1);
        }
      } else {
        _setCachedSong(positionCache + 1);
      }
    });

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
    PlayerObjectX lPlayer = getCurrentPlayer();
    QueueItem curSong = lPlayer.songObject;

    for (int i = 0; i < playlist.length; i++) {
      // Check if this is the current song
      if (curSong == playlist[i]) {
        positionCache = i;
        return;
      }
    }

    // No song found, reset
    positionCache = -1;
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
    String playthis = song.url;
    bool isItLocal = false;

    if(song.localFile != null) {
      playthis = song.localFile;
      isItLocal = true;
    }

    player.playerObject.setUrl(playthis, isLocal: isItLocal);
    player.playerObject.completionHandler = () {
      _callMeOnStreamEnd();
    };

    player.playerObject.durationHandler = (Duration d) {
      player.duration = d;
    };

    player.playerObject.positionHandler = (Duration  p) {
      currentTime = p;
      player.postion = p;
      if(rpf != null) {
        // rpf2.value = currentTime;
        rpf.value = !rpf.value; // TODO: This is hacky as fuck
      }
    };

    player.playerObject.errorHandler = (err) {
      print('ERROR!');
      player.songObject.err = true;
    };

    player.playerObject.audioPlayerStateChangeHandler = (AudioPlayerState state) {
      // print(state);
    };

    player.songObject = song;
    player.songObject.err = false;
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

  Duration getDuration() {
    PlayerObjectX p = getCurrentPlayer();
    return p.duration;
  }

  seekByPercentage(double percentageAsDecimal) {
    if(getDuration().inMilliseconds == 0) {
      return;
    }

    var lPlayer = getCurrentPlayer();
    if (lPlayer.playerType == 'default') {
      double seektime = (percentageAsDecimal * getDuration().inMilliseconds);
      lPlayer.playerObject.seek(new Duration(milliseconds: seektime.toInt()));
    }
  }

  var sliderUpdateInterval;
  var timers = {};
  _startTime() {
    // Stage 1
  }

  // MISSING SOME STUFF
  Timer cacheTimer;
  _setCachedSong(int position) {
    print('ATTEMPTING TO CACHE!');
    try {
      playlist[ position ];
    } catch ( e ) {
      print('FAILED TO CACHE!');
      return false;
    }

    var oPlayer = getOtherPlayer();
    _setMedia(playlist[position], oPlayer, false);
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
  setShuffle(bool newVal){
    if (autoDj == true) {
      shuffle = false;
      return false;
    }
    shuffle = newVal;
    if (shuffle == true) {
      _newShuffle();
    } else {
      _turnShuffleOff();
    }
    return shuffle;
  }

  toggleShuffle() {
    if (autoDj == true) {
      shuffle = false;
      return false;
    }

    shuffle = !shuffle;
    print(shuffle);
    if (shuffle == true) {
      _newShuffle();
    } else {
      _turnShuffleOff();
    }

    if (cacheTimer != null) {
      cacheTimer.cancel();
    }

    cacheTimer = new Timer(new Duration(seconds: cacheTimeout), () {
      if(shuffle == true) {
        try {
          shuffleCache[0];
          for (int i = 0; i < playlist.length; i++) {
            if(playlist[i] == shuffleCache[shuffleCache.length - 1]) {
              _setCachedSong(i);
              break;
            }
          }
        }catch (err) {

        }
      } else if (shouldLoop == true) {
        if (positionCache == (playlist.length - 1)) {
          _setCachedSong(0);
        }  else {
          _setCachedSong(positionCache + 1);
        }
      } else {
        _setCachedSong(positionCache + 1);
      }
    });

    return shuffle;
  }

  _newShuffle() {
    // Clone playlist
    List<QueueItem> newList = new List();
    playlist.forEach((val) => newList.add(val));
    shuffleCache = _shuffle(newList);
    if(shufflePrevious.length > playlist.length) {
      shufflePrevious.length = playlist.length;
    }
  }

  _turnShuffleOff() {
    shufflePrevious.length = 0;
    shuffleCache.length = 0;
  }

  List<QueueItem> _shuffle(List<QueueItem> shuffleThis) {
    int currentIndex = shuffleThis.length;
    var temporaryValue;
    int randomIndex;

    // While there remain elements to shuffle...
    while(currentIndex != 0) {
      // Pick a remaining element...
      randomIndex = genRandomNum(0, currentIndex);
      currentIndex = currentIndex - 1;

      // And swap it with the current element.
      temporaryValue = shuffleThis[currentIndex];
      shuffleThis[currentIndex] = shuffleThis[randomIndex];
      shuffleThis[randomIndex] = temporaryValue;
    }

    return shuffleThis;
  }

  var autoDjIgnoreArray = new List();
  bool autoDj = false;
  toggleAutoDJ() {
    // Stage 2
  }

  _setErrHandle() {
    playerA.playerObject.errorHandler = (err) {
      playerA.songObject.err = true;
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

    playerB.playerObject.errorHandler = (err) {
      playerB.songObject.err = true;
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

int genRandomNum(int min, int max) {
  Random newRandom = new Random();
  return min + newRandom.nextInt(max - min);
}
