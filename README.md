# mStream Flutter

Android and iPhone apps for [mStream Server](https://github.com/IrosTheBeggar/mStream)

# This Project Needs Some Help

Currently Flutter does not have a way to handle background audio for iOS.  If you are an iOS developer who wants to help implement this, let me know.

# Features Todo List

### High Priority
* Implement the audio_service library
* remember scroll position on back button press
* Ability to delete local songs
* Show memory left on device
* Allow user to store files on SD card as well

### Low Priority
* Save/delete/update playlists
* Auto DJ
* Search Feature
* Re-arrange queue / Re-arrange servers
* Redo UI to add a new server

### Extra Low Priority
* Clicking on the cloud button before adding a server throws an exception (only happens on emulators)
* Add server with QR code (QR code scanners for flutter need some improvement first)
* Display Album Art for albums (Image resizing for network images currently sucks)
* Update all metadata instances after a star rating
* Test that error handling works correctly (waiting on: https://github.com/luanpotter/audioplayers/issues/106)
* Download animation doesn't work if you leave and go back in browser
