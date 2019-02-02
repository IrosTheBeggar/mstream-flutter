# mStream Flutter

Android and iPhone apps for [mStream Server](https://github.com/IrosTheBeggar/mStream)

# This Project Needs Some Help

Currently Flutter does not have a way to handle background audio for iOS.  If you are an iOS developer who wants to help implement this, let me know.

# Features Todo List

### High Priority
* Sync Files Locally
* Implement the audio_service library
* Player Error Handling (waiting on: https://github.com/luanpotter/audioplayers/issues/106)

### Low Priority
* Save/delete/update playlists
* Auto DJ
* Browse Local Files
* Search Feature
* Re-arrange queue / Re-arrange servers

### Extra Low Priority
* Clicking on the cloud button before adding a server throws an exception (only happens on emulators)
* Add server with QR code (QR code scanners for flutter need some improvement first)
* Display Album Art for albums (Image resizing for network images currently sucks)
* Update all metadata instances after a star rating