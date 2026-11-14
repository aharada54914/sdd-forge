'use strict';
const storageKey = 'task-board.tasks.v1';
const form = document.querySelector('#add-form');
const titleInput = document.querySelector('#title');
const error = document.querySelector('#input-error');
const warning = document.querySelector('#storage-warning');
const list = document.querySelector('#tasks');
let tasks = [];

function warn(message) {
  warning.textContent = message;
  warning.hidden = false;
}

try {
  const stored = localStorage.getItem(storageKey);
  if (stored !== null) {
    const parsed = JSON.parse(stored);
    if (!Array.isArray(parsed) || !parsed.every(task => task && typeof task.id === 'string' && task.id.length > 0 && typeof task.title === 'string' && task.title.trim().length > 0 && typeof task.completed === 'boolean') || new Set(parsed.map(task => task.id)).size !== parsed.length) {
      throw new Error('Invalid saved list');
    }
    tasks = parsed;
  }
} catch {
  warn('Saved tasks could not be read. You can use a new list for this session.');
}

function save() {
  try {
    localStorage.setItem(storageKey, JSON.stringify(tasks));
  } catch {
    warn('Tasks cannot be saved in this browser. Changes will last only for this session.');
  }
}

function render() {
  list.replaceChildren();
  document.querySelector('#empty').hidden = tasks.length > 0;
  document.querySelector('#summary').textContent = `${tasks.filter(task => !task.completed).length} remaining · ${tasks.length} total`;
  for (const task of tasks) {
    const row = document.createElement('li');
    row.classList.toggle('completed', task.completed);
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.id = `task-${task.id}`;
    checkbox.checked = task.completed;
    const label = document.createElement('label');
    label.htmlFor = checkbox.id;
    label.textContent = task.title;
    checkbox.addEventListener('change', () => {
      task.completed = checkbox.checked;
      save();
      row.classList.toggle('completed', task.completed);
      document.querySelector('#summary').textContent = `${tasks.filter(item => !item.completed).length} remaining · ${tasks.length} total`;
    });
    const remove = document.createElement('button');
    remove.type = 'button';
    remove.textContent = 'Delete';
    remove.setAttribute('aria-label', `Delete ${task.title}`);
    remove.addEventListener('click', () => {
      tasks = tasks.filter(item => item.id !== task.id);
      save();
      render();
      titleInput.focus();
    });
    row.append(checkbox, label, remove);
    list.append(row);
  }
}

form.addEventListener('submit', event => {
  event.preventDefault();
  const title = titleInput.value.trim();
  if (!title) {
    error.textContent = 'Enter a task title.';
    titleInput.setAttribute('aria-invalid', 'true');
    titleInput.focus();
    return;
  }
  error.textContent = '';
  titleInput.removeAttribute('aria-invalid');
  tasks.push({ id: crypto.randomUUID(), title, completed: false });
  save();
  render();
  titleInput.value = '';
  titleInput.focus();
});
render();
