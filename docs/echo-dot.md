# Echo Dot

This setup has been verified on a 2nd generation Echo Dot (`biscuit`) running LineageOS 14.1 (Android 7.1.2). The Dot has no screen, so Kiosk Satellite runs headless on it: a voice satellite, intercom, alarm clock, timer and speaker for Home Assistant, set up and managed entirely from the remote admin.

## Headless Mode

Kiosk Satellite turns headless on its own on any device whose display is a stub (the Dot reports a 1x1 display). Nothing needs to be switched on. On a headless device:

- No screen is ever drawn. There is no WebView, dashboard, screensaver, camera or camera view, and the app never opens an Activity.
- The Kiosk Satellite Service starts when the device boots, whatever **Start on boot** says. The [Home Launcher](home-launcher.md) is not needed.
- Voice Satellite, the intercom, alarms, timers, the [DLNA renderer](dlna.md), the [Sendspin player](sendspin.md), ESPHome, Fleet Management and plugins work as usual.
- The remote admin leaves out every page and control that needs a screen: Web Browsing, Screensaver, Camera, Camera Streams, Kiosk Mode, Lockdown Mode, Home Launcher and App Launcher, the dashboard settings of Home Assistant, the screenshot and the screen tiles of the Overview, and the display settings on the other pages.
- ESPHome leaves out the screen, screensaver, dashboard and camera entities.
- The DLNA renderer offers audio only, so Home Assistant's media browser lists only what the Dot can play.
- Intercom calls are always hands-free.
- **Remote management** stays on, since the remote admin is the only way in.
- Android is kept awake. Asleep, Android drops the Action button before the app can hear it.

## Install

```
adb install -r kiosk-satellite.apk
adb shell am start -n me.jxl.kiosk_satellite/.ProvisionActivity
```

The second command starts the app once after the install, which Android requires before it delivers the boot broadcast. The app has nothing to show, so the command returns at once with the app running in the background.

## Setup in One Sitting

Android cannot ask for permissions on a device without a screen, so they are granted over adb:

```
adb shell pm grant me.jxl.kiosk_satellite android.permission.RECORD_AUDIO
adb shell pm grant me.jxl.kiosk_satellite android.permission.ACCESS_COARSE_LOCATION
adb shell pm grant me.jxl.kiosk_satellite android.permission.ACCESS_FINE_LOCATION
adb shell dumpsys deviceidle whitelist +me.jxl.kiosk_satellite
adb shell settings put secure enabled_accessibility_services me.jxl.kiosk_satellite/.HeadlessKeyService
adb shell settings put secure accessibility_enabled 1
adb reboot
```

The location grant is only needed for the Bluetooth proxy. The accessibility service is how the Action button reaches Kiosk Satellite. Android 7 only notices it after a reboot (or the next app update), which is why the block ends with one.

Then open `http://<dot ip>:2324` in a browser. The setup wizard asks for an admin password, the Home Assistant connection and the Voice Satellite wake word. It skips the dashboard step and lists the adb commands for any grant that is still missing. Finally, add the Dot in Home Assistant under **Settings > Devices & services**, where it shows up as discovered.

## Volume

These volume settings, on the **Audio** page, keep the wake word working while music plays:

| Setting | Value |
|---|---|
| Master volume | 100% |
| Media volume | 55% or less |
| Intercom volume | 80% |
| Assistant volume | 100% |

The Dot's speaker sits right next to its microphones, and the LineageOS build has no hardware echo canceller: Amazon's audio processor never starts without its configuration files. Kiosk Satellite's own echo cancellation removes what the speaker plays, but above about 55% the speaker distorts and the remainder drowns out the wake word. Without music, the wake word works at any volume, so only the media volume needs the limit. Keeping the master volume at 100% leaves the assistant, alarms and intercom at full strength.

## The Buttons

| Button | What it does |
|---|---|
| Action | Answers a ringing intercom call, stops a ringing alarm, dismisses a ringing timer or the voice turn, or ends an intercom call. With none of those happening, it starts a voice command. |
| Microphone | Mutes and unmutes Voice Satellite. The mute follows the Dot's microphone mute both ways, so the button, the **VS Mute** switch in Home Assistant and the remote admin always agree, and the light ring shows it. |
| Volume up and down | Change the volume. |

The Action button can also run any gesture action. Add a **Button** gesture on the [Gestures](gestures.md) page for a press, a double press or a hold of the Action button. A press no gesture claims keeps the job above. The LineageOS build handles the microphone and volume buttons itself, so they cannot be mapped.

[Claps](gestures.md#claps) work as well, since they only need the microphone.

## The Light Ring

The ring shows voice activity, timers, alarms, intercom calls, notifications and the microphone mute in the colors an Echo Dot uses. Each can be changed or switched off on the **LED Control** page. See [LED Control](led-control.md).

### Strobing

On the current LineageOS build, moving effects strobe: the listening arc, the thinking colors, the pulses and breathing all blink rapidly as they move. Solid colors do not.

The cause is the build's light daemon, `biscuit-ledd`. Kiosk Satellite reaches the ring through the ROM's `BiscuitService`, which hands each frame to the daemon as a `FRAME` command. For every `FRAME`, the daemon first writes an all-black frame to the ring's driver (`/sys/bus/i2c/devices/0-003f/frame`) and only then the frame it was sent, which turns the ring off for about 14 ms. A moving effect sends 20 frames a second, so the ring goes dark 20 times a second. The daemon's own animations do not do this, and neither does writing frames to the driver directly, but an app can do neither: the driver only takes writes from root and the build has no `su`.

Until the daemon is fixed, turn off **Animate effects** at the top of the LED Control page if the strobbing bothers you. Each effect then holds still and the ring changes only when what it shows changes, so it never strobes. A build whose daemon writes a `FRAME` without the black frame first, clearing the ring only when it stops one of its own animations, animates smoothly with the switch on.

## What to Know

- **Updates.** The update screen needs someone to tap Install, which a device without a screen cannot do. Make Kiosk Satellite the device owner (`adb shell dpm set-device-owner me.jxl.kiosk_satellite/.KioskAdminReceiver`, on a Dot with no accounts) or use [Shizuku](shizuku.md) so updates install silently. Otherwise update with `adb install -r`.
- **Resources.** With the wake word listening, Kiosk Satellite uses about 15% of one core and 85 MB of the Dot's 480 MB of RAM while idle.

## Memory

The Overview's RAM tile counts only memory nobody holds, usually about 0.2 GB on the Dot. Android keeps the rest filled with cached apps and files it gives back on demand, and the Dot runs normally with that much free. These recover real memory:

| Change | Gain | How |
|---|---|---|
| Bluetooth off | About 15 to 20 MB | Only when the [Bluetooth proxy](esphome.md) is not used. `adb shell biscuit_service bt off` turns it off, and it stays off across reboots. `adb shell biscuit_service bt on` turns it back on, in pairing mode. |
| Compressed swap (zram) | Up to 192 MB of swap for apps in the background | `adb root`, then `adb shell "echo lzo > /sys/block/zram0/comp_algorithm; echo 201326592 > /sys/block/zram0/disksize; mkswap /dev/block/zram0; swapon /dev/block/zram0"`. Lasts until the next reboot. |

The LineageOS 14.1 build for the Dot already tries to set up zram at boot and fails. Its `fstab.mt8163` asks for an 805 MB swap, more than the Dot's RAM, and the kernel starts zram with `zstd`, which it does not include (`zram: Cannot initialise zstd compressing backend` in `dmesg`). It only has `lzo`. A build that writes `lzo` to `/sys/block/zram0/comp_algorithm` before swap comes up, and sets `zramsize` to about 256 MB, gets swap on every boot. Setting `ro.config.low_ram=true` in the build also trims the system's own memory use.

These do not help:

- **Disabling unused system apps** (contacts, calendar, weather, SMS push and the like with `pm disable-user`). They run as cached processes that Android already counts as free and closes under pressure.
- **Disabling SystemUI.** `system_server` starts it whether or not it is disabled.
