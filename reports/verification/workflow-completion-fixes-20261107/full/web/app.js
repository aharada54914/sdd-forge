// @ts-check
'use strict';

/** @typedef {{id: string, title: string, completed: boolean}} Task */
/** @type {{tasks: Task[], loading: boolean, ready: boolean, pending: boolean}} */
const state = {tasks: [], loading: true, ready: false, pending: false};
const form = /** @type {HTMLFormElement} */ (document.getElementById('add-form'));
const input = /** @type {HTMLInputElement} */ (document.getElementById('task-title'));
const addButton = /** @type {HTMLButtonElement} */ (document.getElementById('add-button'));
const list = /** @type {HTMLUListElement} */ (document.getElementById('task-list'));
const empty = /** @type {HTMLElement} */ (document.getElementById('empty'));
const statusMessage = /** @type {HTMLElement} */ (document.getElementById('status'));
const error = /** @type {HTMLElement} */ (document.getElementById('error'));
const section = /** @type {HTMLElement} */ (document.getElementById('task-section'));
const dialog = /** @type {HTMLDialogElement} */ (document.getElementById('delete-dialog'));
const dialogTitle = /** @type {HTMLElement} */ (document.getElementById('delete-title'));
const cancelDelete = /** @type {HTMLButtonElement} */ (document.getElementById('cancel-delete'));
const confirmDelete = /** @type {HTMLButtonElement} */ (document.getElementById('confirm-delete'));
/** @type {{task: Task, trigger: HTMLButtonElement} | null} */
let deletion = null;

/** Match Python str.strip, rather than UTF-16 length or JavaScript's different whitespace set.
 * @param {string} value
 */
function trimTitle(value) {
  return value.replace(/^[\u0009-\u000d\u001c-\u0020\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]+|[\u0009-\u000d\u001c-\u0020\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]+$/gu, '');
}

/** @param {string} message */
function showError(message) {
  error.textContent = message;
  error.hidden = message === '';
}

function locked() { return state.loading || state.pending || !state.ready; }

function updateControls() {
  const disabled = locked();
  input.disabled = disabled;
  addButton.disabled = disabled;
  for (const control of list.querySelectorAll('input, button')) {
    if (control instanceof HTMLInputElement || control instanceof HTMLButtonElement) {
      control.disabled = disabled;
    }
  }
  cancelDelete.disabled = state.pending;
  confirmDelete.disabled = state.pending;
  statusMessage.textContent = state.loading ? '読み込み中' : state.pending ? '保存中' : '';
  section.setAttribute('aria-busy', String(state.loading || state.pending));
  empty.hidden = !state.ready || state.tasks.length !== 0;
}

/** Validate the API envelope before replacing any UI snapshot.
 * @param {unknown} value
 * @returns {Task[]}
 */
function tasksFrom(value) {
  if (typeof value !== 'object' || value === null || !('tasks' in value) ||
      Object.keys(value).length !== 1 || !Array.isArray(value.tasks)) {
    throw new Error('Invalid task envelope');
  }
  const ids = new Set();
  /** @type {Task[]} */
  const tasks = [];
  for (const item of value.tasks) {
    if (typeof item !== 'object' || item === null || Object.keys(item).length !== 3 ||
        typeof item.id !== 'string' ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(item.id) ||
        ids.has(item.id) || typeof item.title !== 'string' ||
        trimTitle(item.title) !== item.title || Array.from(item.title).length < 1 ||
        Array.from(item.title).length > 500 || /[\ud800-\udfff]/u.test(item.title) ||
        typeof item.completed !== 'boolean') {
      throw new Error('Invalid task');
    }
    ids.add(item.id);
    tasks.push({id: item.id, title: item.title, completed: item.completed});
  }
  return tasks;
}

/** @param {string} path
 * @param {string} method
 * @param {object | undefined} [body]
 * @returns {Promise<Task[]>}
 */
async function request(path, method, body) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(path, {
      method, signal: controller.signal, cache: 'no-store',
      headers: body === undefined ? {} : {'Content-Type': 'application/json'},
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (!response.ok) throw new Error('Request failed');
    return tasksFrom(await response.json());
  } finally {
    clearTimeout(timer);
  }
}

/** @param {number} index */
function focusRow(index) {
  const row = list.children[index];
  const checkbox = row?.querySelector('input');
  if (checkbox instanceof HTMLInputElement) checkbox.focus();
  else input.focus();
}

function renderTasks() {
  const fragment = document.createDocumentFragment();
  state.tasks.forEach((task, index) => {
    const row = document.createElement('li');
    const label = document.createElement('label');
    label.className = 'task-label';
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.checked = task.completed;
    const title = document.createElement('span');
    title.className = 'task-title';
    title.textContent = task.title;
    label.append(checkbox, title);
    const remove = document.createElement('button');
    remove.type = 'button';
    remove.textContent = '削除';
    checkbox.addEventListener('change', () => {
      const completed = checkbox.checked;
      checkbox.checked = task.completed;
      if (locked()) return;
      void mutate('PATCH', '/api/tasks/' + task.id, {completed}, () => focusRow(index));
    });
    remove.addEventListener('click', () => {
      if (locked()) return;
      deletion = {task, trigger: remove};
      dialogTitle.textContent = task.title;
      dialog.showModal();
      cancelDelete.focus();
    });
    row.append(label, remove);
    fragment.append(row);
  });
  list.replaceChildren(fragment);
}

/** Acquire the shared guard synchronously, before starting any request.
 * @param {string} method
 * @param {string} path
 * @param {object | undefined} body
 * @param {() => void} onSuccess
 */
async function mutate(method, path, body, onSuccess) {
  if (locked()) return;
  state.pending = true;
  showError('');
  updateControls();
  let saved = false;
  try {
    state.tasks = await request(path, method, body);
    renderTasks();
    saved = true;
  } catch {
    showError('保存できませんでした。再読み込みして状態を確認してください。');
  } finally {
    state.pending = false;
    updateControls();
  }
  if (saved) onSuccess();
}

form.addEventListener('submit', (event) => {
  event.preventDefault();
  if (locked()) return;
  const title = trimTitle(input.value);
  if (title.length === 0) {
    showError('タスクを入力してください。');
    input.focus();
    return;
  }
  if (Array.from(title).length > 500 || /[\ud800-\udfff]/u.test(title)) {
    showError('タスクは500文字以内で入力してください。');
    input.focus();
    return;
  }
  void mutate('POST', '/api/tasks', {title}, () => {
    input.value = '';
    input.focus();
  });
});

function closeDeletion() {
  if (state.pending) return;
  const trigger = deletion?.trigger;
  dialog.close();
  deletion = null;
  trigger?.focus();
}
cancelDelete.addEventListener('click', closeDeletion);
dialog.addEventListener('cancel', (event) => {
  event.preventDefault();
  closeDeletion();
});
confirmDelete.addEventListener('click', () => {
  if (locked() || deletion === null) return;
  const task = deletion.task;
  const index = state.tasks.findIndex((item) => item.id === task.id);
  closeDeletion();
  void mutate('DELETE', '/api/tasks/' + task.id, undefined,
    () => focusRow(Math.min(index, state.tasks.length - 1)));
});

// CSS variables cannot be used in media-query conditions. Read the canonical
// breakpoint, and observe real available width (including magnification).
const breakpoint = parseFloat(getComputedStyle(document.documentElement)
  .getPropertyValue('--layout-mobile-breakpoint'));
const main = /** @type {HTMLElement} */ (document.querySelector('main'));
new ResizeObserver(() => {
  const zoom = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('zoom')) || 1;
  main.classList.toggle('compact', window.innerWidth / zoom < breakpoint);
}).observe(main);

async function load() {
  updateControls();
  try {
    state.tasks = await request('/api/tasks', 'GET');
    state.ready = true;
    renderTasks();
  } catch {
    showError('読み込みできませんでした。再読み込みして状態を確認してください。');
  } finally {
    state.loading = false;
    updateControls();
  }
}
void load();
