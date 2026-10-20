# Calendar

Kiosk Satellite shows your Home Assistant calendars as a family calendar on the kiosk. Each calendar gets a color and an optional person, and an event that is on more than one calendar is drawn once with its background split on a diagonal between their colors. The calendar is read only on the kiosk. Add and change events in Home Assistant or in the calendar apps it syncs with.

Open it from **Calendar** in the kiosk menu, from **Open calendar** under **Settings, Calendar**, from the **Up next** screensaver widget, from an **Open the calendar** [gesture](gestures.md), from a dashboard button pointed at `ks://calendar` (see [Dashboard Links](dashboard-links.md)) or from Home Assistant with the ESPHome **Calendar view** select (see [ESPHome](esphome.md)).

## Adding calendars

1. Open **Settings, Calendar** on the kiosk or the **Calendar** page of the remote admin.
2. Choose **Add a calendar** and pick a calendar entity. Any Home Assistant calendar works, such as Google Calendar, CalDAV, Local Calendar or a holiday calendar.
3. The calendar takes the next free color and opens its editor:

| Field | What it does |
| --- | --- |
| Name | The name on its chip and in the Day view. It starts as the entity's name. |
| Color | One of eight colors, or Custom for any other. |
| Person | A Home Assistant person. Their picture replaces the initial on the calendar's chips and avatars. |

Tap a calendar in the list to change it. **Remove** takes it off the list. The switch next to each calendar turns it off without removing it.

## Views

The calendar opens on the view set under **Default view**. **Today** returns to the current day, the arrows move by a day, a week or a month, and a swipe left or right does the same.

| View | What it shows |
| --- | --- |
| Day | One lane per calendar with its avatar and name, an all-day row, then the hours with a line at the current time. Events that overlap in a lane sit side by side. |
| Week | Seven columns of events, all-day events first. Today is raised with its date in a filled circle. Tap a day's header to open it in the Day view. |
| Month | As many events per day as fit, then "+N more". Tap a day to open it. |
| Schedule | Today on the left with the date, the weather, the next event and the rest of today. The coming two weeks are on the right. |

Tap any event to see its details: who it is for, the date and time, how it repeats, the location and the description.

The chips centered in the top bar show one calendar each. Tap a chip to hide that calendar on this kiosk. Hidden calendars stay hidden until you tap the chip again, and the Up next widget leaves them out too. An event shared with a calendar that is still showing stays, without the hidden calendar's color.

On a short screen such as the Echo Show 5 and on a phone the chips show only each calendar's avatar. More calendars than fit scroll sideways. On a phone the Week view becomes a strip of the seven days over the chosen day's events, and the Month view a grid of dots over the chosen day's events.

## Shared events

An event that appears on more than one of your calendars, such as an invitation sent to two people, is drawn once. Its background is split on a diagonal, one band per calendar, in the order the calendars are listed in Settings. The details show every calendar it is on. Two copies count as the same event when Home Assistant gives them the same event ID, which Google Calendar, CalDAV and Local Calendar do for invitations. Otherwise they match when the title, start and end are the same.

## Weather

Pick a weather entity under **Weather** to add the daily forecast to each day in the Week view, the Schedule view and the phone's day heading. The kiosk subscribes to the forecast only while the calendar is open.

## Settings

| Setting | Default | Notes |
| --- | --- | --- |
| Default view | Week | The view the calendar opens on. |
| Week starts on | Language default | Sunday, Monday or Saturday, or the first day the device language uses. |
| Weather | None | The weather entity for the daily forecast. |
| Show in the kiosk menu | On | Adds Calendar to the kiosk menu. The restricted menu also needs **Calendar** under **Kiosk Mode, Allowed Actions**. |
| Close when idle | 2 minutes | Returns to the dashboard after no touch for this long. Never keeps it open. The screensaver also closes it when it starts. |

## How it reads Home Assistant

The kiosk reads the calendars only while something on screen needs them: the calendar while it is open, and the Up next widget while the screensaver shows it. It uses the Home Assistant token from **Settings, Home Assistant**, and a token for a user who is not an administrator works.

On Home Assistant 2026.5 and later each calendar is a live subscription, so a change in Home Assistant shows on the kiosk within seconds. Older versions are asked for the events every five minutes and when the view moves. Recurring events come from Home Assistant already expanded.

If Home Assistant is not reachable, the calendar keeps the events it has and says when they were last updated.

## Fleet

The Calendar category carries the calendars with their names, colors and people, and the Display and Kiosk settings. The calendars hidden with their chips stay on each kiosk. See [Fleet Management](fleet.md).
