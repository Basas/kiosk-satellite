The Voice Satellite defaults are bundled from
`custom_components/voice_satellite/sounds/` in the Voice Satellite integration.

- `timer-alert.mp3` is `alert.mp3`.
- `voice-wake.mp3`, `voice-done.mp3`, `voice-error.mp3` and `voice-announce.mp3`
  keep their corresponding sounds with a `voice-` prefix.
- `voice-wake.mp3` and `voice-done.mp3` play 8 dB quieter than the
  integration's files, so they sit at the level of typical speech. The timer
  alert stays at full level so it carries across a room.

Custom sounds are selected under Settings > Voice Satellite > Chimes and stored
in the app's `sounds` folder. They survive app updates. Home Assistant sound
replacements do not change the sounds played locally by Kiosk Satellite.

`alarm.ogg` is the built-in alarm tone. It is made in this repository by
`tool/generate_alarm_sound.py` (two rising marimba-like arpeggios sized to
loop), so it carries no outside license.
