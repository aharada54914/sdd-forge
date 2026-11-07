const tokens = await fetch('./design-system/design-tokens.json').then(response => {
  if (!response.ok) throw new Error('Design tokens unavailable');
  return response.json();
});
for (const [group, values] of Object.entries(tokens)) {
  for (const [name, token] of Object.entries(values)) {
    if (!token || !Object.hasOwn(token, '$value')) continue;
    const value = Array.isArray(token.$value) ? token.$value.join(', ') : token.$value;
    document.documentElement.style.setProperty(`--${group}-${name}`, value);
  }
}
const key = 'task-board:v1';
const input = document.querySelector('#title');
const validation = document.querySelector('#validation');
const notice = document.querySelector('#storage-notice');
let tasks = [];
function storageWarning() {
  notice.textContent = '保存データを利用できません。この画面では引き続き操作できます。変更は保存されない場合があります。';
}
try {
  const raw = localStorage.getItem(key);
  if (raw !== null) {
    const parsed = JSON.parse(raw);
    const ids = new Set();
    if (!Array.isArray(parsed) || !parsed.every(task => {
      if (!task || typeof task.id !== 'string' || !task.id || ids.has(task.id) || typeof task.title !== 'string' || !task.title.trim() || typeof task.completed !== 'boolean') return false;
      ids.add(task.id);
      return true;
    })) throw new Error('Invalid stored tasks');
    tasks = parsed;
  }
} catch { storageWarning(); }
function persist() {
  try { localStorage.setItem(key, JSON.stringify(tasks)); }
  catch { storageWarning(); }
}
function render() {
  const active = tasks.filter(task => !task.completed);
  const completed = tasks.filter(task => task.completed);
  document.querySelector('#total').textContent = tasks.length;
  document.querySelector('#active-count').textContent = active.length;
  document.querySelector('#completed-count').textContent = completed.length;
  for (const [name, list] of [['active', active], ['completed', completed]]) {
    const root = document.getElementById(name);
    root.replaceChildren();
    if (!list.length) {
      const empty = document.createElement('li');
      empty.className = 'empty';
      empty.textContent = name === 'active' ? '未完了のタスクはありません。' : '完了したタスクはありません。';
      root.append(empty);
    }
    for (const task of list) {
      const row = document.createElement('li');
      row.className = task.completed ? 'task completed' : 'task';
      const label = document.createElement('label');
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.checked = task.completed;
      const title = document.createElement('span');
      title.textContent = task.title;
      label.append(checkbox, title);
      checkbox.addEventListener('change', () => {
        task.completed = checkbox.checked;
        persist(); render();
        document.getElementById(task.id)?.focus();
      });
      checkbox.id = task.id;
      const remove = document.createElement('button');
      remove.type = 'button';
      remove.textContent = '削除';
      remove.setAttribute('aria-label', `${task.title} を削除`);
      remove.addEventListener('click', () => {
        tasks = tasks.filter(item => item.id !== task.id);
        persist(); render(); input.focus();
      });
      row.append(label, remove); root.append(row);
    }
  }
}
document.querySelector('form').addEventListener('submit', event => {
  event.preventDefault();
  const title = input.value.trim();
  if (!title) {
    validation.textContent = 'タスクを入力してください。';
    input.setAttribute('aria-invalid', 'true'); input.focus(); return;
  }
  validation.textContent = ''; input.removeAttribute('aria-invalid');
  tasks.push({id: `task-${crypto.randomUUID()}`, title, completed: false});
  persist(); render(); input.value = ''; input.focus();
});
render();
