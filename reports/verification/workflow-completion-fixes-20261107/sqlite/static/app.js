"use strict";

const form = document.querySelector("#task-form");
const titleInput = document.querySelector("#title");
const addButton = document.querySelector("#add");
const list = document.querySelector("#task-list");
const empty = document.querySelector("#empty");
const status = document.querySelector("#status");
const error = document.querySelector("#error");
const retry = document.querySelector("#retry");
const region = document.querySelector("#tasks");
let tasks = [];
let pending = false;
let ready = false;

function normalizeTitle(value) {
  // Match the API's Python str.strip(): includes C0 separators/NEL, excludes FEFF.
  return value.replace(/^[\u0009-\u000D\u001C-\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+|[\u0009-\u000D\u001C-\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+$/gu, "");
}

function exactKeys(value, keys) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    && Object.keys(value).sort().join(",") === keys.slice().sort().join(",");
}

function validTask(task) {
  return exactKeys(task, ["id", "title", "completed"])
    && Number.isSafeInteger(task.id) && task.id > 0
    && typeof task.title === "string" && task.title === normalizeTitle(task.title)
    && Array.from(task.title).length >= 1 && Array.from(task.title).length <= 200
    && typeof task.completed === "boolean";
}

async function request(path, method = "GET", payload) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const options = { method, signal: controller.signal };
    if (method === "DELETE") options.body = "";
    else if (payload !== undefined) {
      options.headers = { "Content-Type": "application/json" };
      options.body = JSON.stringify(payload);
    }
    const response = await fetch(path, options);
    if (!response.ok) {
      const failure = new Error("request failed");
      failure.status = response.status;
      throw failure;
    }
    if (response.status !== (method === "POST" ? 201 : 200)) throw new Error("protocol status");
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

function controls() {
  const disabled = pending || !ready;
  titleInput.disabled = disabled;
  addButton.disabled = disabled;
  list.querySelectorAll("input, button").forEach(control => { control.disabled = disabled; });
  retry.disabled = pending;
  region.setAttribute("aria-busy", String(pending));
}

function clearError() {
  error.textContent = "";
  titleInput.removeAttribute("aria-invalid");
}

function render() {
  list.replaceChildren();
  for (const task of tasks) {
    const row = document.createElement("li");
    row.className = `task-row${task.completed ? " completed" : ""}`;
    row.dataset.id = String(task.id);
    const label = document.createElement("label");
    label.className = "task-toggle";
    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = task.completed;
    checkbox.addEventListener("change", () => {
      const completed = checkbox.checked;
      checkbox.checked = task.completed;
      void mutate("PATCH", task, completed);
    });
    const text = document.createElement("span");
    text.className = "task-title";
    text.textContent = task.title;
    label.append(checkbox, text);
    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "delete-button";
    remove.textContent = "削除";
    remove.addEventListener("click", () => {
      if (!pending && window.confirm(`「${task.title}」を削除しますか？`)) void mutate("DELETE", task);
    });
    row.append(label, remove);
    list.append(row);
  }
  empty.hidden = !ready || tasks.length !== 0;
  controls();
}

async function load() {
  if (pending) return;
  pending = true;
  clearError();
  retry.hidden = true;
  status.textContent = "読み込み中…";
  controls();
  try {
    const result = await request("/api/tasks");
    if (!exactKeys(result, ["tasks"]) || !Array.isArray(result.tasks)
        || !result.tasks.every(validTask)
        || !result.tasks.every((task, index) => index === 0 || task.id > result.tasks[index - 1].id)) {
      throw new Error("protocol list");
    }
    tasks = result.tasks;
    ready = true;
    status.textContent = "タスクを読み込みました。";
  } catch {
    status.textContent = "";
    error.textContent = "読み込めませんでした。再読み込みをお試しください。";
    retry.hidden = false;
  } finally {
    pending = false;
    render();
  }
}

async function mutate(method, task, completed) {
  if (pending || !ready) return;
  const title = normalizeTitle(titleInput.value);
  clearError();
  status.textContent = "";
  if (method === "POST" && (Array.from(title).length < 1 || Array.from(title).length > 200)) {
    error.textContent = "タスクのタイトルを1〜200文字で入力してください。";
    titleInput.setAttribute("aria-invalid", "true");
    titleInput.focus();
    return;
  }
  pending = true;
  controls();
  let focusId = task?.id;
  let succeeded = false;
  try {
    const path = method === "POST" ? "/api/tasks" : `/api/tasks/${task.id}`;
    const payload = method === "POST" ? { title } : method === "PATCH" ? { completed } : undefined;
    const result = await request(path, method, payload);
    if (method === "DELETE") {
      if (!exactKeys(result, ["deleted"]) || result.deleted !== task.id) throw new Error("protocol delete");
      const index = tasks.findIndex(item => item.id === task.id);
      tasks = tasks.filter(item => item.id !== task.id);
      focusId = tasks[index]?.id ?? tasks[index - 1]?.id;
    } else {
      if (!exactKeys(result, ["task"]) || !validTask(result.task)) throw new Error("protocol task");
      if (method === "POST") {
        if (result.task.title !== title || result.task.completed !== false
            || (tasks.length && result.task.id <= tasks[tasks.length - 1].id)) throw new Error("protocol insert");
        tasks = [...tasks, result.task];
        titleInput.value = "";
      } else {
        if (result.task.id !== task.id || result.task.title !== task.title
            || result.task.completed !== completed) throw new Error("protocol update");
        tasks = tasks.map(item => item.id === task.id ? result.task : item);
      }
    }
    succeeded = true;
    status.textContent = method === "POST" ? "タスクを追加しました。" : method === "PATCH" ? "タスクを更新しました。" : "タスクを削除しました。";
  } catch (failure) {
    status.textContent = "";
    error.textContent = "保存できませんでした。もう一度お試しください。";
    if (method === "POST" && failure.status === 400) titleInput.setAttribute("aria-invalid", "true");
  } finally {
    pending = false;
    render();
    if (method === "POST" || (method === "DELETE" && succeeded && focusId === undefined)) titleInput.focus();
    else list.querySelector(`[data-id="${focusId}"] ${method === "DELETE" && !succeeded ? "button" : "input"}`)?.focus();
  }
}

form.addEventListener("submit", event => { event.preventDefault(); void mutate("POST"); });
retry.addEventListener("click", () => { void load(); });
void load();
