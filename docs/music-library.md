# Music Library

The Music Library browses music on the kiosk and plays it on a speaker. It lists music from Music Assistant, from a Home Assistant speaker's media or from a Sonos household, and it plays on the player the [Now Playing](sendspin.md#full-screen-now-playing) view follows. Pick a speaker in the library and Now Playing, the floating player and every play from the library move to it.

Open it from **Music Library** in the kiosk menu or from the library button next to the close button on the Now Playing view. Both show once a source is set up. Turn either off under **Settings > Media Player > Music Library**, and allow the library in a locked kiosk under **Kiosk Mode > Allowed Actions**.

## Sources

The source picker sits at the top of the sidebar on a tablet, at the top of the rail on a short screen such as the Echo Show 5 and next to the speaker picker on a phone. It lists the sources set up on the device.

| Source | What it lists | Needs |
| --- | --- | --- |
| Music Assistant | Discover, Search, the library's artists, albums, tracks, playlists, radio stations, podcasts and audiobooks, and Browse, which walks each music provider such as Spotify or a music folder. | The server address and token under **Media Player > Music Assistant**. |
| Home Assistant | The media the picked speaker's integration offers, such as a Sonos speaker's favorites, a Spotify account, Radio Browser and My media. Search shows when the speaker's integration supports it. | A Home Assistant speaker picked as the speaker. The list changes with the speaker. |
| Sonos | My Sonos favorites, Sonos playlists and the music library the speakers index from a shared folder. Lists with nothing in them stay hidden. | A Sonos speaker found or added under **Media Player > Sonos**. |

Discover shows the recommendations Music Assistant makes. When it has none, it shows what was played recently, your playlists, recently added tracks and radio stations instead.

Picture, camera and text-to-speech sources in Home Assistant's media are left out, since a speaker has nothing to play from them.

## Speakers

The speaker pill at the top shows where the music plays. Tap it to open **Speakers**:

- **Playing on** names the speaker and its group, with a volume slider for the speaker or the whole group, and one for each speaker in the group.
- **Group** opens the list of speakers that can join it. Tick a speaker to add it and clear it to take it out.
- **Other speakers** lists the source's other speakers. Tap one to play there instead. It becomes the player Now Playing follows, the same as picking it under **Media Player > Player**.

Each source lists only its own speakers, so a speaker is never listed twice. Music Assistant also lists this device's own player while Sendspin is on. The Home Assistant list leaves out the speakers Music Assistant adds to Home Assistant, which are already in the Music Assistant list.

When a play needs a speaker of the source first, such as Home Assistant before any of its speakers is picked, Speakers opens and asks for one.

## Playing music

- Tap an album, playlist, artist or folder to open it. Tap **Play** to replace the queue with it.
- Tap a track in an album or playlist to play the album or playlist from that track.
- Tap a radio station, a podcast episode or a track in a list to play it.
- Tap the menu button on a row, or long press a card, for **Play now**, **Play next**, **Add to queue**, **Start radio**, **Go to artist** and **Add to favorites**. Start radio and favorites are Music Assistant only. Start radio keeps playing similar music after the track, album, artist or playlist ends.

A message confirms each play. After Play next or Add to queue, **View** opens the [queue](#the-queue).

The player bar at the bottom works like Music Assistant's. The track and its favorite heart sit on the left. Shuffle, previous, play or pause, next and repeat sit over the seek bar in the middle. The [queue](#the-queue), the volume and the button that opens Now Playing sit on the right. Each control shows only where the player supports it, as on Now Playing. With nothing playing, the bar shows the track the queue would resume from: play starts the queue there, and previous and next move through it. Tap the track to open the Now Playing view over the library, and close Now Playing to come back to the library. On a short screen the seek bar becomes a line along the top of the bar, and the volume button opens Speakers. On a phone the bar keeps the track, play or pause, next and the queue.

## The queue

The queue button on the player bar opens the queue of the speaker the library plays on. On a tablet it docks to the right of the library, and on a short screen or a phone it takes the library's place until you close it. It also opens from **View** on the message after Play next or Add to queue.

- The playing track sits at the top under **Now playing**, and what comes next is listed under **Up next**.
- Drag a track by its handle to move it.
- Swipe a track to the left to remove it.
- Tap a track to play it now, or use its menu for **Play now**, **Play next** and **Remove from queue**.
- **Clear** empties the queue and stops the music, after asking first.

Music Assistant players, this device's own player and Sonos speakers have a queue to manage. A Home Assistant speaker has none, so the queue button does not show for it.

## Screen sizes

| Screen | Layout |
| --- | --- |
| Tablet | A sidebar with the source, Discover, Search, Browse and the library's lists. Albums show their cover and tracks side by side. |
| Short, such as the Echo Show 5 | A rail with the source and one entry each for Discover, Search, Library and Browse. Library shows its lists as chips. Discover drops the quick tiles at the top. |
| Phone | The source and speaker pickers under the title, tabs along the bottom and the player bar above them. Albums stack the cover over the tracks. |

While the keyboard is up for Search, the player bar and the tabs make room for the results.

## Settings

Under **Settings > Media Player > Music Library**:

| Setting | What it does |
| --- | --- |
| Source | The source the library opens on. **Automatic** starts with the source of the speaker Now Playing follows, else the first one set up. Picking a source in the library changes it too. |
| Show in the kiosk menu | Adds the Music Library entry to the kiosk menu. On by default. |
| Show on Now Playing | Adds the library button next to the close button on the Now Playing view. On by default. |
| Close when idle | Returns to the dashboard after no touch for this long. Two minutes by default. The screensaver waits while the library is open. |
