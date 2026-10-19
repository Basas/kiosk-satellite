"""Browse plugins and install links in the remote admin, in a local browser fixture.

Run with Python 3 and Playwright's Chromium installed. No device is contacted.
Mirrors the device (plugin_directory_ui_test.dart).
"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread

from playwright.sync_api import sync_playwright, expect

ROOT = Path(__file__).resolve().parents[1] / 'remote-ui'


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass


server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'


def listed(plugin_id, name, installs, **extra):
    return {'id': plugin_id, 'name': name, 'description': f'{name} for the kiosk.', 'author': 'Alice',
            'version': '1.0.0', 'repository': f'https://github.com/alice/{plugin_id}', 'stars': 3,
            'downloads': 1280, 'installs': installs, 'icon': None, 'installed': False, **extra}


directory = {'generated': '2026-10-19T06:00:00Z', 'plugins': [
    listed('quiet', 'Quiet Clock', None, installed=True, installedVersion='1.0.0', sameSource=True, updateAvailable=False),
    listed('weather', 'Weather Mood', 40),
]}
plugins_enabled = True
requests = []
installed = [{'id': 'quiet', 'name': 'Quiet Clock', 'version': '1.0.0', 'enabled': True, 'running': True,
              'settings': [], 'commands': [], 'values': {}, 'source': {'repository': 'https://github.com/alice/quiet'}}]


def preview(url):
    plugin_id = url.rstrip('/').rsplit('/', 1)[-1]
    return {'previewId': 'token-' + plugin_id, 'repository': url, 'compatible': True, 'listed': plugin_id == 'weather',
            'manifest': {'id': plugin_id, 'name': plugin_id.title(), 'version': '1.0.0', 'author': 'Alice',
                         'license': 'MIT', 'description': 'A plugin.'},
            'readme': '# README', 'readmeBaseUrl': url.replace('github.com', 'raw.githubusercontent.com') + '/' + 'a' * 40 + '/'}


def api(route):
    global plugins_enabled
    name = route.request.url.rsplit('/', 1)[-1]
    params = route.request.post_data_json or {}
    requests.append((name, params))
    if name == 'getPluginState':
        result = {'enabled': plugins_enabled, 'plugins': installed}
    elif name == 'setPluginsEnabled':
        plugins_enabled = params['enabled']
        result = {'enabled': plugins_enabled, 'plugins': installed}
    elif name == 'getPluginDirectory':
        result = directory
    elif name == 'previewPluginRepository':
        result = preview(params['url'])
    elif name == 'installPluginRepository':
        result = installed
    else:
        result = None
    route.fulfill(json={'ok': True, 'data': result})


def open_app(page, query=''):
    html = (ROOT / 'index.html').read_text().replace('<script type="module" src="static/main.js?v=__KSV__"></script>', '')
    page.route(lambda url: url.split('#')[0] == base + '/' + query, lambda route: route.fulfill(body=html, content_type='text/html'))
    page.route('**/api/commands/*', api)
    page.goto(base + '/' + query + '#plugins')
    page.evaluate("""async () => {
      (await import('/static/core.js')).showView('app');
      await (await import('/static/plugins.js')).loadPlugins();
      (await import('/static/tabs.js')).showTab('plugins', {refresh: false});
    }""")


try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport={'width': 1440, 'height': 1000})
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        open_app(page)
        root = page.locator('#tab-plugins')
        browse = root.locator('[data-search-id="x:plugins:browse"]')
        expect(browse).to_contain_text('Browse plugins')
        expect(browse).to_contain_text('Find plugins made by the community')
        # Its own card, above Add plugin's.
        assert browse.evaluate("(row) => row.parentElement.children.length") == 1
        assert browse.bounding_box()['y'] < root.locator('[data-search-id="x:plugins:add"]').bounding_box()['y']

        browse.click()
        assert page.url.endswith('#plugins/_browse')
        expect(page.locator('#pageTitle')).to_contain_text('Browse plugins')
        rows = root.locator('.plugin-directory-row')
        expect(rows).to_have_count(2)
        # Most active installs first, then the rest.
        expect(rows.first).to_contain_text('Weather Mood')
        expect(rows.first).to_contain_text('1.3K')
        expect(rows.nth(1)).to_contain_text('Installed')
        # Without an icon the row shows the generic plugin icon.
        expect(rows.first.locator('.plugin-icon svg')).to_have_count(1)
        search = root.get_by_role('textbox', name='Search plugins')
        search.fill('quiet')
        expect(rows).to_have_count(1)
        search.fill('nothing like this')
        expect(root.get_by_text('No plugins match your search.')).to_be_visible()
        search.fill('')
        expect(root.locator('[data-search-id="x:plugins:submit"]')).to_have_attribute(
            'href', 'https://github.com/jxlarrea/kiosk-satellite-plugins#submit-your-plugin')

        # Picking a plugin opens the same review as Add plugin.
        rows.first.click()
        modal = page.locator('.modal-back')
        expect(modal).to_contain_text('Listed in Community Plugins.')
        modal.get_by_role('button', name='Trust and install').click()
        expect(modal).to_have_count(0)
        assert ('installPluginRepository', {'previewId': 'token-weather', 'trusted': True}) in requests
        # An installed plugin opens its own page.
        expect(rows.nth(1)).to_contain_text('Installed')
        rows.filter(has_text='Quiet Clock').click()
        assert page.url.endswith('#plugins/quiet')
        assert not errors, errors
        page.close()

        # An install link: it leaves the address at once and asks before installing.
        plugins_enabled = False
        requests.clear()
        page = browser.new_page(viewport={'width': 390, 'height': 844})
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        open_app(page, '?install_plugin=bob%2Funlisted')
        assert '?' not in page.url and page.url.endswith('#plugins'), page.url
        # Not awaited: the flow waits on the dialogs below.
        page.evaluate("() => { import('/static/plugins.js').then((m) => m.installFromLink()); }")
        modal = page.locator('.modal-back')
        expect(modal).to_contain_text('Turn on Enable Plugins to install this plugin.')
        modal.get_by_role('button', name='Turn on').click()
        expect(page.locator('.modal-back')).to_contain_text('Not listed in Community Plugins.')
        assert ('setPluginsEnabled', {'enabled': True}) in requests
        assert ('previewPluginRepository', {'url': 'https://github.com/bob/unlisted'}) in requests
        page.locator('.modal-back').get_by_role('button', name='Cancel').click()
        expect(page.locator('.modal-back')).to_have_count(0)
        assert not any(name == 'installPluginRepository' for name, _ in requests)
        # A second call has nothing left to install.
        page.evaluate("async () => (await import('/static/plugins.js')).installFromLink()")
        expect(page.locator('.modal-back')).to_have_count(0)
        assert not errors, errors
        browser.close()
finally:
    server.shutdown()
print('PASS: Browse plugins card, list, search, review, installed rows and install links.')
