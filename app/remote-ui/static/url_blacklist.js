import { t } from './localization.js';
import { cmd, state } from './core.js';
import { cameraAction, cameraListRow } from './cameras.js';
import { banner, modalShell } from './widgets.js';

/* ---- URL Blacklist ----
   Web Browsing > URL Blacklist, the device's UrlBlacklistCard: the
   addresses the dashboard and external pages cannot open, each rule with
   its name, pattern and where it applies. A row opens the editor, Add rule
   opens it empty. The list repaints itself on the device's echo, so a
   change on the device or in another admin shows here without rebuilding
   the tab. */

// The device's Icons.block, on every rule row.
const RULE_ICON = '<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor"'
  + ' stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/>'
  + '<path d="m5.6 5.6 12.8 12.8"/></svg>';

const SCOPES = ['all', 'dashboard', 'external'];
const TYPES = ['wildcard', 'regex'];

function storedRules() {
  const raw = (state.settings || []).find((s) => s.key === 'browser.url_blacklist')?.value;
  try {
    const list = JSON.parse(raw || '[]');
    return Array.isArray(list)
      ? list.filter((r) => r && typeof r.name === 'string' && r.name.trim()
        && typeof r.pattern === 'string' && r.pattern.trim())
      : [];
  } catch (_) { return []; }
}

function scopeLabel(scope) {
  return scope === 'dashboard' ? t('urlBlacklistScopeDashboard')
    : scope === 'external' ? t('urlBlacklistScopeExternal')
      : t('urlBlacklistScopeAll');
}

function typeLabel(type) {
  return type === 'regex' ? t('urlBlacklistTypeRegex') : t('urlBlacklistTypeWildcard');
}

/* Why Save refused, the device's urlBlacklistError (see the
   saveUrlBlacklistRule command for the codes). */
function ruleError(code) {
  switch (`${code || ''}`) {
    case 'name': return t('urlBlacklistErrorName');
    case 'pattern': return t('urlBlacklistErrorPattern');
    case 'regex': return t('urlBlacklistErrorRegex');
    default: return t('commonSaveFailed');
  }
}

function field(label, control, hint) {
  const wrap = document.createElement('label');
  wrap.className = 'form-field';
  const title = document.createElement('span');
  title.className = 'desc';
  title.textContent = label;
  control.classList.add('field');
  control.style.maxWidth = 'none';
  wrap.append(title, control);
  let note = null;
  if (hint) {
    note = document.createElement('span');
    note.className = 'desc';
    note.style.fontSize = '12.5px';
    note.textContent = hint;
    wrap.append(note);
  }
  return { wrap, note };
}

function select(values, label, value) {
  const control = document.createElement('select');
  for (const v of values) {
    const option = document.createElement('option');
    option.value = v;
    option.textContent = label(v);
    control.appendChild(option);
  }
  control.value = value;
  return control;
}

/* Add a rule, or change the one at `index`. Save checks the rule on the
   device: a usable one saves and closes, anything else says why and keeps
   the dialog open. */
export function openUrlBlacklistEditor(index, rule, onSaved) {
  let saving = false;
  const shell = modalShell({
    title: rule ? t('urlBlacklistEditTitle') : t('urlBlacklistAddTitle'),
    width: 480,
    onDismiss: () => { if (!saving) shell.close(); },
  });
  const form = document.createElement('form');
  form.className = 'modal-form';
  const name = document.createElement('input');
  name.type = 'text';
  name.value = rule?.name || '';
  const type = select(TYPES, typeLabel, TYPES.includes(rule?.type) ? rule.type : 'wildcard');
  const pattern = document.createElement('input');
  pattern.type = 'text';
  pattern.spellcheck = false;
  pattern.autocapitalize = 'off';
  pattern.classList.add('mono');
  pattern.value = rule?.pattern || '';
  const scope = select(SCOPES, scopeLabel, SCOPES.includes(rule?.scope) ? rule.scope : 'all');
  const patternField = field(t('urlBlacklistPattern'), pattern, ' ');
  const patternHint = () => {
    patternField.note.textContent = type.value === 'regex'
      ? t('urlBlacklistPatternRegexHint') : t('urlBlacklistPatternWildcardHint');
  };
  patternHint();
  type.addEventListener('change', patternHint);
  const issue = document.createElement('div');
  issue.setAttribute('role', 'alert');
  form.append(field(t('urlBlacklistName'), name).wrap,
    field(t('urlBlacklistType'), type).wrap,
    patternField.wrap,
    field(t('urlBlacklistScope'), scope, t('urlBlacklistScopeHint')).wrap,
    issue);
  shell.body.append(form);
  const cancel = document.createElement('button');
  cancel.type = 'button';
  cancel.className = 'btn-text';
  cancel.textContent = t('commonCancel');
  cancel.addEventListener('click', () => shell.close());
  const save = document.createElement('button');
  save.type = 'button';
  save.className = 'btn-primary';
  save.textContent = t('commonSave');
  save.addEventListener('click', () => form.requestSubmit());
  shell.foot.append(cancel, save);
  const controls = [cancel, save, name, type, pattern, scope];
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (saving) return;
    saving = true;
    controls.forEach((c) => { c.disabled = true; });
    issue.replaceChildren();
    const params = { name: name.value, pattern: pattern.value, type: type.value, scope: scope.value };
    if (rule) params.index = index;
    const r = await cmd('saveUrlBlacklistRule', params)
      .catch((e) => ({ ok: false, error: e?.message }));
    saving = false;
    controls.forEach((c) => { c.disabled = false; });
    if (r?.ok) {
      shell.close();
      onSaved?.();
      return;
    }
    issue.replaceChildren(banner(ruleError(r?.error), { error: true }));
  });
  name.focus();
}

/* The page itself: the list card with its Add rule row. */
export function renderUrlBlacklistPage(panel) {
  if (!panel) return;
  panel.replaceChildren();
  const card = document.createElement('div');
  card.className = 'card';
  card.dataset.searchId = 'x:url_blacklist';
  const list = document.createElement('div');
  card.appendChild(list);
  let shown = '';
  const paint = () => {
    const rules = storedRules();
    shown = JSON.stringify(rules);
    list.replaceChildren();
    if (!rules.length) {
      const note = document.createElement('div');
      note.className = 'group-note';
      note.style.padding = '12px 0 4px';
      note.textContent = t('urlBlacklistEmpty');
      list.appendChild(note);
    }
    rules.forEach((rule, index) => {
      const remove = cameraAction(t('commonRemove'), async () => {
        await cmd('removeUrlBlacklistRule', { index });
      }, false, 'delete');
      const row = cameraListRow(rule.name, rule.pattern, [remove], {
        onClick: () => openUrlBlacklistEditor(index, rule),
      });
      row.querySelector('.desc')?.classList.add('mono');
      const where = document.createElement('div');
      where.className = 'desc';
      where.textContent = [scopeLabel(rule.scope),
        ...(rule.type === 'regex' ? [typeLabel('regex')] : [])].join(' · ');
      row.querySelector('.info')?.appendChild(where);
      const icon = document.createElement('span');
      icon.className = 'camera-row-icon url-rule-icon';
      icon.innerHTML = RULE_ICON;
      row.querySelector('.camera-row-main')?.prepend(icon);
      list.appendChild(row);
    });
    // The device's primary add tile.
    const add = document.createElement('button');
    add.type = 'button';
    add.className = 'dp-add-row';
    add.textContent = t('urlBlacklistAdd');
    add.addEventListener('click', () => openUrlBlacklistEditor(-1, null));
    list.appendChild(add);
  };
  paint();
  panel.appendChild(card);

  // The device's echo of a save or a change made elsewhere.
  const onSettings = (e) => {
    if (!card.isConnected) {
      document.removeEventListener('ks-settings', onSettings);
      return;
    }
    if (!(e.detail || []).includes('browser.url_blacklist')) return;
    if (JSON.stringify(storedRules()) !== shown) paint();
  };
  document.addEventListener('ks-settings', onSettings);
}
