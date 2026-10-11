# Custom Pages

Kiosk Satellite can show your own HTML pages in place of a Home Assistant dashboard. A custom page is a file in Home Assistant's `www` folder, which Home Assistant serves at `/local/`. Once added, it shows up in every dashboard picker under **Custom Pages**, so it can be the kiosk's default dashboard, part of the dashboard view rotation, the screensaver's dashboard, a gesture's target or an option of the ESPHome dashboard selects.

Pages must live in Home Assistant itself, under `/local/`. Pages served from another host are not supported.

## Add a page

1. Copy the page into the `www` folder of your Home Assistant configuration, for example `/config/www/kitchen.html`. Home Assistant serves it at `/local/kitchen.html`. If the `www` folder did not exist before, restart Home Assistant once so it starts serving it.
2. On the kiosk or in the remote admin, open **Settings > Home Assistant > Custom Pages** and tap **Add page**.
3. Enter a **Name** for the pickers to show and the **Path**, such as `/local/kitchen.html`. Only the path is needed: Kiosk Satellite builds the full address from the Home Assistant base URL.
4. Tap **Save & Validate**. Kiosk Satellite asks Home Assistant for the page and saves it only when Home Assistant answers with the file.

Tap a page in the list to rename it or change its path. Its delete button removes it. Removing a page from the list does not touch the file in Home Assistant.

The page then appears under **Custom Pages** in the dashboard picker. Pick it as the **Default dashboard** to have the kiosk start on it.

## Talk to Home Assistant

A custom page is served from the same address as your dashboards, so it shares the dashboard's sign-in. When **Log in automatically** is on or after you log in to the dashboard by hand, Home Assistant's session is stored in the page's `localStorage` under `hassTokens`. Your page can read it and connect to Home Assistant's WebSocket API without a token of its own.

```html
<script>
const session = JSON.parse(localStorage.getItem('hassTokens'));
const ws = new WebSocket(location.origin.replace(/^http/, 'ws') + '/api/websocket');
let id = 1;
ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  if (message.type === 'auth_required') {
    ws.send(JSON.stringify({ type: 'auth', access_token: session.access_token }));
  } else if (message.type === 'auth_ok') {
    ws.send(JSON.stringify({ id: id++, type: 'subscribe_events', event_type: 'state_changed' }));
  } else if (message.type === 'event') {
    const change = message.event.data;
    console.log(change.entity_id, change.new_state?.state);
  }
};
</script>
```

With the [home-assistant-js-websocket](https://github.com/home-assistant/home-assistant-js-websocket) library, pass `getAuth` a `loadTokens` function that returns the parsed `hassTokens` and a `saveTokens` function that writes refreshed tokens back to the same key, with `hassUrl` set to `location.origin`.

Never put a long-lived access token in a file under `www`. Home Assistant serves `/local/` to anyone on your network without signing in.

The page can also use the [JavaScript API](js-api.md) through `window.kioskSatellite`, the same as a dashboard.

## Several layouts in one page

A page can hold several layouts and pick one from the part of the address after `#`. Add each layout as its own custom page with the same file and a different ending, such as `/local/wall.html#kitchen` and `/local/wall.html#den`. When the kiosk moves between two of them, it only changes the `#` part, so the page does not reload. Listen for the change in your page:

```js
window.addEventListener('hashchange', () => showLayout(location.hash.slice(1)));
```

## How custom pages differ from dashboards

- **Moving between a page and a dashboard reloads.** Dashboard views switch inside Home Assistant's app without a reload. A custom page is its own document, so moving from a dashboard to a page, from a page to a dashboard or between two different pages loads the new one in full. On a slow device, a rotation that mixes dashboard views and custom pages spends a moment loading at each switch.
- **Dashboard features do not apply.** HA kiosk mode, the dashboard carousel, the theme schedule and the update filter only act on Home Assistant's dashboards. On a custom page, **Filter dashboard updates** says **Not used on custom pages** in [Optimizations](optimizations.md) and on the remote admin Overview.
- **Edits show on the next load.** Home Assistant tells browsers to keep files from `/local/` for a month. Its service worker keeps copies of its own too. Kiosk Satellite skips both for custom pages, so a page and the files beside it load fresh every time the kiosk opens or reloads it. Pull down to refresh after you change a page. Dashboards keep their caches as usual.
