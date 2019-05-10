# mStream Flutter

Android and iPhone apps for [mStream Server](https://github.com/IrosTheBeggar/mStream)

# This Project Needs Some Help

Currently Flutter does not have a way to handle background audio for iOS.  If you are an iOS developer who wants to help implement this, let me know.

# Features Todo List

### High Priority
* Implement the audio_service library
* Remember scroll position on back button press
* Ability to delete local songs
* Allow user to store files on SD card as well
* Show memory left on device (Is it even possible: https://stackoverflow.com/questions/54715678/how-to-get-a-devices-free-used-storage-space)

### Low Priority
* Save/delete/update playlists
* Search Feature
* Re-arrange queue / Re-arrange servers

### Extra Low Priority
* Display Album Art for albums (Image resizing for network images currently sucks)
* Update all metadata instances after a star rating
* Download animation doesn't work if you leave and go back in browser
* Double check all caching code against mStream WebApp
* Auto DJ

### Blocked
* Test that error handling works correctly (waiting on: https://github.com/luanpotter/audioplayers/issues/106)
* Clicking on the cloud button before adding a server throws an exception (https://github.com/flutter/flutter/issues)
