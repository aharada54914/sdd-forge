"""Real Chromium acceptance; test-only dependency: playwright and Chromium."""
from __future__ import annotations

import argparse
import importlib.metadata
import json
import signal
import socket
import subprocess
import sys
import tempfile
import time
import traceback
from collections.abc import Callable
from pathlib import Path
from typing import Any

from playwright.sync_api import Route, expect, sync_playwright

ROOT = Path(__file__).resolve().parents[1]


def route_collector(destination: list[Route]) -> Callable[[Route], None]:
    """Bind each interception list in a normal Playwright-compatible function."""
    def collect(route: Route) -> None:
        destination.append(route)
    return collect


def run(output: Path, screenshots: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    screenshots.mkdir(parents=True, exist_ok=True)
    observations: dict[str, Any] = {"checks": [], "requests": [], "responses": [], "processes": [], "console": [], "mutation_timings": [], "malformed_success": []}
    process: subprocess.Popen[str] | None = None

    def record(name: str, detail: Any = True) -> None:
        observations["checks"].append({"assertion": name, "detail": detail})
        print(f"PASS {name}", flush=True)

    def stop() -> None:
        nonlocal process
        if process is not None:
            process.send_signal(signal.SIGINT)
            process.wait(timeout=10)
            observations["processes"][-1]["exit"] = process.returncode
            process = None

    try:
        with tempfile.TemporaryDirectory(prefix="task-board-browser-") as temporary:
            db = str(Path(temporary) / "tasks.sqlite3")
            with socket.socket() as sock:
                sock.bind(("127.0.0.1", 0))
                port = sock.getsockname()[1]
            origin = f"http://127.0.0.1:{port}"

            def start() -> None:
                nonlocal process
                command = [sys.executable, "-B", "app.py", "--db", db, "--port", str(port)]
                with (output / "server.log").open("a") as log:
                    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                                               stderr=log, text=True)
                assert process.stdout is not None
                assert process.stdout.readline().strip() == f"LISTENING {origin}"
                observations["processes"].append({"pid": process.pid, "command": command, "db": db})

            start()
            with sync_playwright() as pw:
                browser = pw.chromium.launch(executable_path="/usr/bin/chromium", args=["--no-sandbox"])
                observations["environment"] = {"browser": browser.version, "python": sys.version,
                                               "playwright": importlib.metadata.version("playwright")}
                page = browser.new_page(viewport={"width": 1280, "height": 900})
                page.set_default_timeout(4000)
                console_phase = ["normal-ui"]
                page.on("request", lambda request: observations["requests"].append(
                    {"url": request.url, "method": request.method, "headers": request.all_headers(),
                     "body": request.post_data, "phase": console_phase[0]}))
                page.on("response", lambda response: observations["responses"].append(
                    {"url": response.url, "status": response.status}))
                errors: list[str] = []
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.on("console", lambda message: observations["console"].append(
                    {"phase": console_phase[0], "type": message.type, "text": message.text, "location": message.location}))
                response = page.goto(origin)
                assert response is not None and response.status == 200, "TEST-001 root must serve actual UI"
                expect(page.get_by_role("heading", name="今日のタスク")).to_be_visible()
                assert page.locator("html").get_attribute("lang") == "ja"
                title = page.get_by_role("textbox", name="タスクのタイトル", exact=True)
                add_button = page.get_by_role("button", name="追加", exact=True)
                rows = page.locator("#task-list > li")
                expect(title).to_be_visible()
                expect(page.get_by_text("タスクはまだありません", exact=True)).to_be_visible()
                assert page.locator("#empty").get_attribute("aria-live") == "polite"
                assert page.get_by_role("status").get_attribute("aria-live") == "polite"
                page.screenshot(path=str(screenshots / "empty.png"))
                record("TEST-001 Japanese root, labelled controls and empty state")

                def state() -> list[dict[str, Any]]:
                    return page.evaluate("async () => (await (await fetch('/api/tasks')).json()).tasks")

                def assert_view(expected: list[dict[str, Any]]) -> None:
                    expect(rows).to_have_count(len(expected))
                    assert rows.locator(".task-title").all_text_contents() == [task["title"] for task in expected]
                    assert rows.get_by_role("checkbox").evaluate_all("els => els.map(e => e.checked)") == [task["completed"] for task in expected]

                def mutation_time(method: str, began: float, before_count: int, detail: str) -> None:
                    elapsed = time.perf_counter() - began
                    measured = {"method": method, "elapsed_s": elapsed, "rows_before": before_count,
                                "detail": detail, "limit_s": 1, "confirmation_think_time_excluded": method == "DELETE"}
                    observations["mutation_timings"].append(measured)
                    assert elapsed < 1, measured

                delete_started: list[float] = []

                def confirm_timed(dialog: Any) -> None:
                    # Start at acceptance, after any time spent reading the confirmation.
                    delete_started[:] = [time.perf_counter()]
                    dialog.accept()

                def add(value: str, enter: bool = False) -> None:
                    before = state()
                    title.fill(value)
                    began = time.perf_counter()
                    if enter:
                        title.press("Enter")
                    else:
                        add_button.click()
                    expect(rows).to_have_count(len(before) + 1)
                    expect(title).to_have_value("")
                    expect(title).to_be_focused()
                    after = state()
                    assert after[:-1] == before and after[-1]["title"] == value.strip()
                    assert after[-1]["completed"] is False
                    mutation_time("POST", began, len(before), "button/Enter to acknowledged DOM and saved row")

                add("企画書の下書きをまとめる")
                add("午後の打ち合わせを確認する", enter=True)
                add("明日の準備をする")
                # The UI deliberately waits for server acknowledgment before checking.
                rows.nth(1).get_by_role("checkbox").click()
                expect(rows.nth(1).get_by_role("checkbox")).to_be_checked()
                expect(page.get_by_role("status")).to_contain_text("更新")
                for name, width, height in [("early-desktop", 1280, 900), ("early-mobile", 375, 812)]:
                    page.set_viewport_size({"width": width, "height": height})
                    page.screenshot(path=str(screenshots / f"{name}.png"), full_page=True)
                print(f"EARLY_SCREENSHOTS {screenshots / 'early-desktop.png'} {screenshots / 'early-mobile.png'}", flush=True)
                page.set_viewport_size({"width": 1280, "height": 900})
                # RT-0005: establish real success, then reject a subsequent write.
                observations["stale_success_regressions"] = []
                for method in ["POST", "PATCH", "DELETE"]:
                    console_phase[0] = "normal-rt0005"
                    add("成功表示の確認 " + method)
                    if method == "PATCH":
                        rows.last.get_by_role("checkbox").click()
                        expect(rows.last.get_by_role("checkbox")).to_be_checked()
                        expect(page.get_by_role("status")).to_contain_text("更新")
                    elif method == "DELETE":
                        count = rows.count()
                        page.once("dialog", lambda dialog: dialog.accept())
                        rows.last.get_by_role("button", name="削除", exact=True).click()
                        expect(rows).to_have_count(count - 1)
                        expect(page.get_by_role("status")).to_contain_text("削除")
                    else:
                        expect(page.get_by_role("status")).to_contain_text("追加")
                    previous_success = page.get_by_role("status").inner_text()
                    preserved = state()
                    draft = "保存失敗でも残る下書き " + method
                    title.fill(draft)
                    intercepted: list[Route] = []
                    route_pattern = "**/api/tasks" if method == "POST" else origin + "/api/tasks/" + str(preserved[0]["id"])
                    page.route(route_pattern, route_collector(intercepted))
                    console_phase[0] = "injected-" + method.lower() + "-500"
                    if method == "POST":
                        add_button.click()
                    elif method == "PATCH":
                        rows.first.get_by_role("checkbox").click()
                    else:
                        page.once("dialog", lambda dialog: dialog.accept())
                        rows.first.get_by_role("button", name="削除", exact=True).click()
                    expect(add_button).to_be_disabled()
                    assert_view(preserved)
                    pending_status = page.get_by_role("status").inner_text()
                    page.screenshot(path=str(screenshots / f"rt0005-{method.lower()}-pending.png"))
                    assert len(intercepted) == 1 and intercepted[0].request.method == method
                    intercepted.pop().fulfill(status=500, content_type="application/json", body='{"error":"storage_error"}')
                    expect(page.get_by_role("alert")).to_contain_text("保存できませんでした")
                    expect(add_button).to_be_enabled()
                    expect(title).to_have_value(draft)
                    assert_view(preserved)
                    assert page.request.get(origin + "/api/tasks").json()["tasks"] == preserved
                    if method == "POST":
                        expect(title).to_be_focused()
                    elif method == "PATCH":
                        expect(rows.first.get_by_role("checkbox")).to_be_focused()
                    else:
                        expect(rows.first.get_by_role("button", name="削除", exact=True)).to_be_focused()
                    failed_status = page.get_by_role("status").inner_text()
                    observations["stale_success_regressions"].append({"method": method, "previous_success": previous_success,
                        "pending_status": pending_status, "failed_status": failed_status, "draft": title.input_value(),
                        "error": page.get_by_role("alert").inner_text(), "saved_rows": preserved})
                    page.screenshot(path=str(screenshots / f"rt0005-{method.lower()}-failure.png"))
                    page.wait_for_timeout(200)
                    assert not intercepted, "failed mutation must not automatically replay"
                    page.unroute(route_pattern)
                    assert pending_status == "" and failed_status == "", observations["stale_success_regressions"][-1]
                console_phase[0] = "normal-ui"
                add("入力検証前の成功確認")
                expect(page.get_by_role("status")).to_contain_text("追加")
                preserved = state()
                title.fill(" \t ")
                add_button.click()
                expect(page.get_by_role("alert")).to_contain_text("200")
                expect(page.get_by_role("status")).to_have_text("")
                expect(title).to_be_focused()
                assert state() == preserved
                add("失敗後の再保存確認")
                expect(page.get_by_role("status")).to_contain_text("追加")
                expect(page.get_by_role("alert")).to_have_text("")
                record("RT-0005 real success followed by POST/PATCH/DELETE failure or invalid draft clears stale success, preserves state/focus and recovers")
                add("企画書の下書きをまとめる", enter=True)
                duplicates = [task for task in state() if task["title"] == "企画書の下書きをまとめる"]
                assert len(duplicates) == 2 and duplicates[0]["id"] != duplicates[1]["id"]
                literals = ['<img src=x onerror="window.xss=1">', "'); DROP TABLE tasks; --"]
                boundaries = ["あ" * 200, "あ" * 199 + "😀", "😀" * 200, "  " + "字" * 200 + "  "]
                for value in literals + boundaries:
                    add(value, enter=True)
                expected = state()
                page.reload()
                expect(rows).to_have_count(len(expected))
                assert state() == expected
                assert rows.locator("img").count() == 0 and page.evaluate("window.xss") is None
                for value in boundaries:
                    assert len(value.strip()) == 200
                    expect(page.get_by_text(value.strip(), exact=True)).to_be_visible()
                before = state()
                for value in ["", " \t ", "あ" * 200 + "😀"]:
                    title.fill(value)
                    add_button.click()
                    expect(page.get_by_role("alert")).to_contain_text("200")
                    assert state() == before
                record("TEST-002 button/Enter/duplicates/literal and exact Unicode boundaries", [len(v.strip()) for v in boundaries])
                title.fill("")
                first = rows.first.get_by_role("checkbox")
                for completed in [True, False]:
                    first.focus()
                    began = time.perf_counter()
                    first.press("Space")
                    expect(first).to_be_checked(checked=completed)
                    assert state()[0]["completed"] is completed
                    decoration = rows.first.locator(".task-title").evaluate("e => getComputedStyle(e).textDecorationLine")
                    assert ("line-through" in decoration) is completed
                    expect(first).to_be_enabled()
                    mutation_time("PATCH", began, rows.count(), f"keyboard completion={completed}, saved value and styling")
                    page.reload()
                    expect(first).to_be_checked(checked=completed)
                record("TEST-003 keyboard completion both ways, styling and reload")
                before = state()
                mutation_count = len([r for r in observations["requests"] if r["method"] == "DELETE"])
                dialogs: list[str] = []

                def cancel(dialog: Any) -> None:
                    dialogs.append(dialog.message)
                    dialog.dismiss()

                page.once("dialog", cancel)
                rows.first.get_by_role("button", name="削除", exact=True).click()
                assert state() == before
                assert len([r for r in observations["requests"] if r["method"] == "DELETE"]) == mutation_count
                assert "削除" in dialogs[0]
                page.once("dialog", confirm_timed)
                rows.first.get_by_role("button", name="削除", exact=True).focus()
                rows.first.get_by_role("button", name="削除", exact=True).press("Enter")
                expect(rows).to_have_count(len(before) - 1)
                expect(rows.first.get_by_role("checkbox")).to_be_focused()
                assert state() == before[1:]
                mutation_time("DELETE", delete_started[0], len(before), "confirmation acceptance to saved deletion and focus")
                saved = state()
                page.reload()
                expect(rows).to_have_count(len(saved))
                assert state() == saved
                record("TEST-004 Japanese cancel sends no request; keyboard confirm deletes only selected row")
                old_pid = observations["processes"][-1]["pid"]
                stop()
                start()
                assert observations["processes"][-1]["pid"] != old_pid
                page.reload()
                expect(rows).to_have_count(len(saved))
                assert state() == saved
                observations["restart"] = {"before": saved, "after": state(), "deleted_id": before[0]["id"]}
                assert_view(saved)
                record("TEST-005 new PID same SQLite path exact surviving/completed/deleted state")
                # Injected DELETEs never reach the server or acquire transport framing.
                # Keep the real RT-0005 success and normal confirmed-deletion requests.
                actual_deletes = [r for r in observations["requests"]
                                  if r["method"] == "DELETE" and r["phase"].startswith("normal")]
                observations["actual_delete_framing"] = actual_deletes

                for name, width, height in [("desktop", 1280, 900), ("mobile", 375, 812)]:
                    page.set_viewport_size({"width": width, "height": height})
                    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
                    observations[name + "_all_buttons"] = page.locator("button").evaluate_all(
                        "els => els.map(e => ({id:e.id,hidden:e.hidden,width:e.getBoundingClientRect().width,height:e.getBoundingClientRect().height}))")
                    geometry = page.locator("button:visible, .task-toggle:visible, #title:visible").evaluate_all(
                        "els => els.map(e => ({name: e.getAttribute('aria-label') || e.textContent, width: e.getBoundingClientRect().width, height: e.getBoundingClientRect().height}))")
                    observations[name + "_geometry"] = geometry
                    assert all(item["width"] >= 44 and item["height"] >= 44 for item in geometry), geometry
                    page.screenshot(path=str(screenshots / f"{name}.png"), full_page=True)
                    observations[name] = {"targets": geometry, "accessibility": page.locator("body").aria_snapshot()}
                page.set_viewport_size({"width": 1280, "height": 900})
                page.evaluate("document.documentElement.style.zoom = '2'")
                assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
                page.screenshot(path=str(screenshots / "zoom-200.png"), full_page=True)
                page.evaluate("document.documentElement.style.zoom = ''")
                title.focus()
                title.press("Tab")
                expect(add_button).to_be_focused()
                add_button.press("Tab")
                expect(rows.first.get_by_role("checkbox")).to_be_focused()
                focus = rows.first.get_by_role("checkbox").evaluate("e => ({style: getComputedStyle(e).outlineStyle, width: getComputedStyle(e).outlineWidth})")
                assert focus["style"] != "none" and float(focus["width"].replace("px", "")) > 0
                observations["focus"] = focus
                observations["styles"] = page.evaluate("""() => Object.fromEntries(['body','h1','#add','#title','.task-title','.delete-button','.task-toggle'].map(s => {const c=getComputedStyle(document.querySelector(s));return [s,{color:c.color,background:c.backgroundColor,font:c.fontFamily,size:c.fontSize,lineHeight:c.lineHeight,padding:c.padding,border:c.borderColor,radius:c.borderRadius}]}))""")
                contrast = page.evaluate("""() => {
                  const luminance = color => color.match(/[\\d.]+/g).slice(0,3).map(Number).map(v => {v/=255;return v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4;}).reduce((s,v,i)=>s+v*[0.2126,0.7152,0.0722][i],0);
                  const ratio = (a,b) => {const x=luminance(a),y=luminance(b);return (Math.max(x,y)+0.05)/(Math.min(x,y)+0.05);};
                  const bg = getComputedStyle(document.body).backgroundColor;
                  const pairs = ['body','h1','#title','.task-title','.hint','.delete-button','#status','#error'].map(s => ({name:s,foreground:getComputedStyle(document.querySelector(s)).color,background:bg,minimum:4.5}));
                  const add = getComputedStyle(document.querySelector('#add'));
                  pairs.push({name:'primary text',foreground:add.color,background:add.backgroundColor,minimum:4.5});
                  for(const s of ['#title','.delete-button','.task-toggle input']) pairs.push({name:s+' boundary',foreground:getComputedStyle(document.querySelector(s)).borderColor,background:bg,minimum:3});
                  pairs.push({name:'focus',foreground:getComputedStyle(document.querySelector('.task-toggle input')).outlineColor,background:bg,minimum:3});
                  pairs.push({name:'checked control',foreground:getComputedStyle(document.querySelector('.task-toggle input:checked')).backgroundColor,background:bg,minimum:3});
                  pairs.push({name:'unchecked control',foreground:getComputedStyle(document.querySelector('.task-toggle input:not(:checked)')).borderColor,background:bg,minimum:3});
                  return pairs.map(p=>({...p,ratio:ratio(p.foreground,p.background)}));
                }""")
                observations["contrast"] = contrast
                assert all(pair["ratio"] >= pair["minimum"] for pair in contrast), contrast
                record("TEST-007 computed WCAG text/control/focus contrast", contrast)
                record("TEST-006 responsive screenshots long-title wrapping, target geometry and 200% zoom")
                assert not [message for message in observations["console"] if message["type"] == "error" and message["phase"].startswith("normal")], observations["console"]
                record("TEST-008 actual browser console has no errors in normal CRUD/reload/restart")

                pending_routes: list[Route] = []
                console_phase[0] = "injected-read-500"
                page.route("**/api/tasks", lambda route: pending_routes.append(route))
                page.reload(wait_until="domcontentloaded")
                expect(page.get_by_role("status")).to_contain_text("読み込み中")
                expect(add_button).to_be_disabled()
                page.screenshot(path=str(screenshots / "loading.png"))
                assert pending_routes
                pending_routes.pop().fulfill(status=500, content_type="application/json", body='{"error":"storage_error"}')
                expect(page.get_by_role("alert")).to_contain_text("読み込めませんでした")
                page.screenshot(path=str(screenshots / "read-error.png"))
                page.unroute("**/api/tasks")
                console_phase[0] = "normal-read-recovery"
                page.get_by_role("button", name="再読み込み", exact=True).click()
                expect(rows).to_have_count(len(saved))
                expect(add_button).to_be_enabled()
                assert state() == saved
                title.fill("失敗しても残る下書き")

                def intercept_write(route: Route) -> None:
                    if route.request.method == "POST":
                        pending_routes.append(route)
                    else:
                        route.continue_()

                page.route("**/api/tasks", intercept_write)
                console_phase[0] = "injected-post-500"
                add_button.click()
                expect(add_button).to_be_disabled()
                expect(title).to_be_disabled()
                expect(page.get_by_role("status")).to_have_text("")
                assert page.locator("#task-list input:enabled, #task-list button:enabled").count() == 0
                assert state() == saved
                pending_routes.pop().fulfill(status=500, content_type="application/json", body='{"error":"storage_error"}')
                expect(page.get_by_role("alert")).to_contain_text("保存できませんでした")
                expect(title).to_have_value("失敗しても残る下書き")
                assert state() == saved
                expect(page.get_by_role("status")).to_have_text("")
                page.screenshot(path=str(screenshots / "write-error.png"))
                page.unroute("**/api/tasks")
                console_phase[0] = "normal-write-recovery"
                add_button.click()
                expect(rows).to_have_count(len(saved) + 1)
                expect(title).to_be_focused()
                expect(page.get_by_role("status")).to_contain_text("追加")
                record("TEST-007 loading/read retry/write failure preserve draft+rows, pending disables all mutations, explicit recovery")

                saved = state()
                console_phase[0] = "injected-timeout"
                page.route("**/api/tasks", intercept_write)
                title.fill("タイムアウト下書き")
                began = time.perf_counter()
                add_button.click()
                expect(page.get_by_role("alert")).to_contain_text("保存できませんでした", timeout=12000)
                expect(page.get_by_role("status")).to_have_text("")
                elapsed = time.perf_counter() - began
                assert 9 <= elapsed <= 12
                expect(title).to_have_value("タイムアウト下書き")
                expect(add_button).to_be_enabled()
                assert len(pending_routes) == 1 and state() == saved
                pending_routes.pop().abort()
                page.unroute("**/api/tasks")
                record("TEST-007 10s abort restores controls without automatic retry", elapsed)
                console_phase[0] = "injected-protocol"
                page.route("**/api/tasks", lambda route: route.fulfill(status=201, content_type="application/json", body='{"task":{"id":999,"title":"偽","completed":1}}') if route.request.method == "POST" else route.continue_())
                add_button.click()
                expect(page.get_by_role("alert")).to_contain_text("保存できませんでした")
                assert state() == saved
                expect(page.get_by_role("status")).to_have_text("")
                expect(title).to_have_value("タイムアウト下書き")
                page.unroute("**/api/tasks")
                record("TEST-007 malformed success DTO is not acknowledged")

                # RT-0004: malformed 200 acknowledgments are protocol failures, not HTTP500.
                durable = state()
                console_phase[0] = "malformed-success-GET"
                held_reads: list[Route] = []
                page.route("**/api/tasks", lambda route: held_reads.append(route))
                page.reload(wait_until="domcontentloaded")
                expect(add_button).to_be_disabled()
                expect(title).to_be_disabled()
                expect(page.get_by_role("status")).to_contain_text("読み込み中")
                assert len(held_reads) == 1
                held_reads.pop().fulfill(status=200, content_type="application/json", body='{"tasks":"not-a-list"}')
                expect(page.get_by_role("alert")).to_contain_text("読み込めませんでした")
                expect(page.get_by_role("button", name="再読み込み", exact=True)).to_be_enabled()
                expect(add_button).to_be_disabled()
                expect(title).to_be_disabled()
                assert_view([])
                expect(title).to_have_value("")
                page.wait_for_timeout(200)
                assert not held_reads, "malformed initial GET must not retry automatically"
                assert page.request.get(origin + "/api/tasks").json()["tasks"] == durable
                observations["malformed_success"].append({"method": "GET", "case": "initial wrong list type", "http_status": 200,
                    "saved_server_rows": durable, "accepted_ui_rows": [], "draft": "", "automatic_replay": False})
                page.unroute("**/api/tasks")
                page.get_by_role("button", name="再読み込み", exact=True).click()
                assert_view(durable)
                expect(add_button).to_be_enabled()
                title.fill("タイムアウト下書き")
                # No user reload control exists in ready state. Invoke the real read client once
                # to enter its retained-state error branch, then use visible explicit retries.
                console_phase[0] = "injected-read-500"
                page.route("**/api/tasks", lambda route: held_reads.append(route))
                page.evaluate("void load()")
                expect(add_button).to_be_disabled()
                assert_view(durable)
                assert len(held_reads) == 1
                held_reads.pop().fulfill(status=500, content_type="application/json", body='{"error":"storage_error"}')
                expect(page.get_by_role("alert")).to_contain_text("読み込めませんでした")
                expect(add_button).to_be_enabled()
                console_phase[0] = "malformed-success-GET"
                malformed_lists = [
                    {"tasks": [{**durable[0], "completed": 1}]},
                    {"tasks": [{**durable[0], "title": 3}]},
                    {"tasks": [{**durable[0], "id": 0}]},
                    {"tasks": [durable[0], durable[0]]},
                    {"tasks": [durable[1], durable[0]]},
                    {"tasks": durable, "unexpected": True},
                ]
                for payload in malformed_lists:
                    page.get_by_role("button", name="再読み込み", exact=True).click()
                    expect(add_button).to_be_disabled()
                    assert_view(durable)
                    assert len(held_reads) == 1
                    held_reads.pop().fulfill(status=200, content_type="application/json", body=json.dumps(payload, ensure_ascii=False))
                    expect(page.get_by_role("alert")).to_contain_text("読み込めませんでした")
                    expect(add_button).to_be_enabled()
                    expect(title).to_be_enabled()
                    expect(title).to_have_value("タイムアウト下書き")
                    expect(page.get_by_role("button", name="再読み込み", exact=True)).to_be_enabled()
                    assert_view(durable)
                    page.wait_for_timeout(200)
                    assert not held_reads, "malformed GET must wait for explicit retry"
                    assert page.request.get(origin + "/api/tasks").json()["tasks"] == durable
                    observations["malformed_success"].append({"method": "GET", "case": "ready explicit retry", "http_status": 200,
                        "payload": payload, "saved_rows": durable, "draft": title.input_value(), "automatic_replay": False})
                page.unroute("**/api/tasks")
                page.get_by_role("button", name="再読み込み", exact=True).click()
                assert_view(durable)
                expect(page.get_by_role("alert")).to_have_text("")
                expect(add_button).to_be_enabled()
                expect(title).to_have_value("タイムアウト下書き")
                expect(page.get_by_role("button", name="再読み込み", exact=True)).to_be_hidden()
                record("RT-0004 malformed initial/ready GET200 rejected, saved state and draft retained, explicit retry recovers")

                target = durable[0]
                desired = not target["completed"]
                malformed_mutations = {
                    "PATCH": [
                        {"task": {**target, "completed": 1}},
                        {"task": {**target, "id": durable[1]["id"], "completed": desired}},
                        {"task": {**target, "title": "異なるタイトル", "completed": desired}},
                        {"task": {**target, "completed": target["completed"]}},
                        {"task": {**target, "completed": desired, "unexpected": True}},
                        {"wrong_key": {**target, "completed": desired}},
                    ],
                    "DELETE": [{"deleted": durable[1]["id"]}, {"deleted": str(target["id"])},
                               {"deleted": target["id"], "unexpected": True}, {"wrong_key": target["id"]}],
                }
                for method, payloads in malformed_mutations.items():
                    console_phase[0] = "malformed-success-" + method
                    for payload in payloads:
                        held_writes: list[Route] = []
                        page.route("**/api/tasks/*", route_collector(held_writes))
                        if method == "PATCH":
                            rows.first.get_by_role("checkbox").click()
                        else:
                            page.once("dialog", lambda dialog: dialog.accept())
                            rows.first.get_by_role("button", name="削除", exact=True).click()
                        expect(add_button).to_be_disabled()
                        expect(page.get_by_role("status")).to_have_text("")
                        assert_view(durable)
                        assert len(held_writes) == 1 and held_writes[0].request.method == method
                        held_writes.pop().fulfill(status=200, content_type="application/json", body=json.dumps(payload, ensure_ascii=False))
                        expect(page.get_by_role("alert")).to_contain_text("保存できませんでした")
                        expect(add_button).to_be_enabled()
                        expect(title).to_be_enabled()
                        expect(title).to_have_value("タイムアウト下書き")
                        assert page.locator("#task-list input:disabled, #task-list button:disabled").count() == 0
                        assert_view(durable)
                        assert state() == durable
                        expect(page.get_by_role("status")).to_have_text("")
                        if method == "PATCH":
                            expect(rows.first.get_by_role("checkbox")).to_be_focused()
                        else:
                            expect(rows.first.get_by_role("button", name="削除", exact=True)).to_be_focused()
                        page.wait_for_timeout(200)
                        assert not held_writes, "malformed mutation acknowledgment must not auto-replay"
                        observations["malformed_success"].append({"method": method, "http_status": 200, "payload": payload,
                            "saved_rows": durable, "draft": title.input_value(), "automatic_replay": False,
                            "restored_focus": "checkbox" if method == "PATCH" else "delete button"})
                        page.unroute("**/api/tasks/*")
                    record(f"RT-0004 malformed {method}200 acknowledgments preserve draft/rows, restore controls/focus, never auto-replay")

                # These routes inject failures only; committed state still comes from the real server.
                for method in ["PATCH", "DELETE"]:
                    console_phase[0] = "injected-" + method.lower() + "-500"
                    saved = state()
                    pending_routes.clear()
                    page.route("**/api/tasks/*", lambda route: pending_routes.append(route))
                    if method == "PATCH":
                        rows.first.get_by_role("checkbox").click()
                    else:
                        page.once("dialog", lambda dialog: dialog.accept())
                        rows.first.get_by_role("button", name="削除", exact=True).click()
                    expect(add_button).to_be_disabled()
                    assert_view(saved)
                    assert state() == saved and len(pending_routes) == 1
                    pending_routes.pop().fulfill(status=500, content_type="application/json", body='{"error":"storage_error"}')
                    expect(page.get_by_role("alert")).to_contain_text("保存できませんでした")
                    expect(page.get_by_role("status")).to_have_text("")
                    expect(add_button).to_be_enabled()
                    assert_view(saved)
                    expect(title).to_have_value("タイムアウト下書き")
                    page.unroute("**/api/tasks/*")
                    record(f"TEST-007 {method} pending and failure retain acknowledged browser/server rows and draft")
                console_phase[0] = "injected-post-400"
                page.route("**/api/tasks", lambda route: route.fulfill(status=400, content_type="application/json", body='{"error":"invalid_input"}') if route.request.method == "POST" else route.continue_())
                add_button.click()
                expect(page.get_by_role("alert")).to_contain_text("保存できませんでした")
                expect(page.get_by_role("status")).to_have_text("")
                assert title.get_attribute("aria-invalid") == "true"
                assert "error" in (title.get_attribute("aria-describedby") or "")
                assert_view(saved)
                page.unroute("**/api/tasks")
                record("TEST-007 server title validation is associated with input")

                assert actual_deletes and all(r["headers"].get("content-length") == "0" for r in actual_deletes)
                assert all("transfer-encoding" not in r["headers"] for r in observations["requests"])
                assert all(r["url"].startswith(origin) for r in observations["requests"])
                assert page.evaluate("localStorage.length") == 0
                assert not errors, errors
                assets = [ROOT / p for p in ["static/index.html", "static/app.js", "static/styles.css", "design-system/build/tokens.css"]]
                observations["asset_bytes"] = sum(p.stat().st_size for p in assets)
                assert observations["asset_bytes"] < 100 * 1024
                record("TEST-008 actual browser DELETE Content-Length:0, local assets, literal titles, no localStorage/errors")
                # Real browser fetch supplements UI controls; raw framing negatives live in HTTP regression.
                console_phase[0] = "real-byte-boundaries"
                byte_cases = page.evaluate("""async () => {
                  const outcomes=[];
                  for (const escaped of [false,true]) {
                    const raw=escaped ? '{"title":"\\\\u65e5\\\\u672c\\\\u8a9e\\\\ud83d\\\\ude00"}' : JSON.stringify({title:'日本語😀'});
                    for (const size of [4096,4097]) {
                      const body=raw+' '.repeat(size-new TextEncoder().encode(raw).length);
                      const before=await (await fetch('/api/tasks')).json();
                      const response=await fetch('/api/tasks',{method:'POST',headers:{'Content-Type':'application/json'},body});
                      const result=await response.json(); const after=await (await fetch('/api/tasks')).json();
                      outcomes.push({escaped,size,bytes:new TextEncoder().encode(body).length,status:response.status,before,after,result});
                    }
                  }
                  return outcomes;
                }""")
                for case in byte_cases:
                    assert case["size"] == case["bytes"]
                    assert case["status"] == (201 if case["size"] == 4096 else 413)
                    if case["size"] == 4097:
                        assert case["before"] == case["after"]
                    else:
                        assert case["result"]["task"]["title"] == "日本語😀"
                observations["browser_raw_bytes"] = byte_cases
                record("TEST-008 browser-fetch literal/escaped UTF-8 4096 acceptance and 4097 rejection")
                console_phase[0] = "normal-final-deletion-and-performance"
                page.reload()
                expect(rows).to_have_count(len(state()))
                while rows.count():
                    count = rows.count()
                    page.once("dialog", lambda dialog: dialog.accept())
                    rows.first.get_by_role("button", name="削除", exact=True).click()
                    expect(rows).to_have_count(count - 1)
                expect(title).to_be_focused()
                expect(page.get_by_text("タスクはまだありません", exact=True)).to_be_visible()
                assert state() == []
                record("TEST-004 deleting final row restores input focus and empty state")

                # RT-0003: Python's authoritative whitespace set differs from JS trim.
                # Derive expectations independently from the running Python, not the UI rule.
                python_whitespace = [chr(point) for point in range(0x110000) if chr(point).isspace()]
                observations["unicode_whitespace_codepoints"] = [ord(char) for char in python_whitespace]
                observations["unicode_ui_cases"] = []
                console_phase[0] = "normal-unicode-ui"
                ui_values = [
                    "\u0085日本語\u0085", "\x1c\x1d区切り\x1e\x1f", "\ufeff日本語\ufeff", "\ufeff",
                    " \ufeff ", "\u0085" + "あ" * 199 + "😀\u0085", "\ufeff" + "あ" * 198 + "\ufeff",
                    "\u0085" + "\ufeff" * 200 + "\u0085",
                ]
                # Single-line text inputs discard CR/LF; actual API cases below still cover them.
                ui_values += [char + "空白" + str(ord(char)) + char for char in python_whitespace if char not in "\r\n"]
                for value in ui_values:
                    expected_title = value.strip()
                    before = state()
                    request_count = len([r for r in observations["requests"] if r["method"] == "POST"])
                    title.fill(value)
                    with page.expect_response(lambda response: response.request.method == "POST" and response.url == origin + "/api/tasks") as response_info:
                        add_button.click()
                    response = response_info.value
                    saved_response = response.json()
                    after = state()
                    case = {"input": value, "expected": expected_title, "status": response.status,
                            "response": saved_response, "before": before, "after": after,
                            "visible_error": page.get_by_role("alert").inner_text()}
                    observations["unicode_ui_cases"].append(case)
                    assert response.status == 201 and saved_response["task"]["title"] == expected_title, case
                    assert after == before + [saved_response["task"]] and saved_response["task"]["completed"] is False, case
                    expect(title).to_have_value("")
                    expect(page.get_by_role("alert")).to_have_text("")
                    expect(page.get_by_role("status")).to_contain_text("追加")
                    assert_view(after)
                    assert len([r for r in observations["requests"] if r["method"] == "POST"]) == request_count + 1
                for value in python_whitespace + ["".join(python_whitespace), "\u0085" + "あ" * 200 + "😀\u0085", "\ufeff" + "あ" * 199 + "\ufeff"]:
                    before = state()
                    request_count = len([r for r in observations["requests"] if r["method"] == "POST"])
                    title.fill(value)
                    add_button.click()
                    expect(page.get_by_role("alert")).to_contain_text("200")
                    assert state() == before
                    assert len([r for r in observations["requests"] if r["method"] == "POST"]) == request_count
                saved = state()
                page.reload()
                assert_view(saved)
                assert state() == saved
                record("RT-0003 UI Python whitespace parity, FEFF preserved, blanks/bounds, exact acknowledgment/reload and no duplicate")

                console_phase[0] = "real-unicode-api-boundaries"
                api_values = [char + "API日本語" + char for char in python_whitespace] + python_whitespace + ui_values[:8] + ["\u0085" + "あ" * 200 + "😀\u0085", "\ufeff" + "あ" * 199 + "\ufeff"]
                observations["unicode_api_cases"] = []
                for value in api_values:
                    expected_title = value.strip()
                    expected_status = 201 if 1 <= len(expected_title) <= 200 else 400
                    before = state()
                    outcome = page.evaluate("""async title => { const response=await fetch('/api/tasks',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({title})});return {status:response.status,body:await response.json()}; }""", value)
                    after = state()
                    case = {"input": value, "expected": expected_title, "outcome": outcome, "before": before, "after": after}
                    observations["unicode_api_cases"].append(case)
                    assert outcome["status"] == expected_status, case
                    if expected_status == 201:
                        assert outcome["body"]["task"]["title"] == expected_title
                        assert after == before + [outcome["body"]["task"]]
                    else:
                        assert after == before
                saved = state()
                page.reload()
                assert_view(saved)
                assert state() == saved
                record("RT-0003 real API covers entire Python whitespace set, FEFF and 200/201 boundaries without mutation on rejection")
                console_phase[0] = "normal-final-performance"
                # Fresh 100-row fixture in same invocation's DB; user actions above are never substituted.
                page.evaluate("""async () => {const tasks=(await (await fetch('/api/tasks')).json()).tasks;for (const task of tasks) await fetch('/api/tasks/'+task.id,{method:'DELETE',body:''});for(let i=0;i<100;i++) await fetch('/api/tasks',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({title:'性能確認 '+i})});}""")
                began = time.perf_counter()
                page.reload()
                expect(rows).to_have_count(100)
                elapsed = time.perf_counter() - began
                assert elapsed < 2
                record("100-row local list usable within 2s", elapsed)
                # Measure normal acknowledged mutations on the declared 100-row local scale.
                for completed in [True, False]:
                    rows.first.get_by_role("checkbox").focus()
                    began = time.perf_counter()
                    rows.first.get_by_role("checkbox").press("Space")
                    expect(rows.first.get_by_role("checkbox")).to_be_checked(checked=completed)
                    expect(rows.first.get_by_role("checkbox")).to_be_enabled()
                    assert state()[0]["completed"] is completed
                    mutation_time("PATCH", began, 100, f"100-row completion={completed}, UI and saved acknowledgment")
                before = state()
                page.once("dialog", confirm_timed)
                rows.first.get_by_role("button", name="削除", exact=True).click()
                expect(rows).to_have_count(99)
                expect(rows.first.get_by_role("checkbox")).to_be_focused()
                assert state() == before[1:]
                mutation_time("DELETE", delete_started[0], 100, "100-row confirmed delete, saved absence and focus")
                add("100件の状態へ戻す")
                add("100件での追加時間を確認する", enter=True)
                record("RT-0004 normal POST/PATCH both directions/confirmed DELETE below1s on 100-row fixture", observations["mutation_timings"])
                allowed_console_errors = {
                    "injected-read-500": ["500"], "injected-post-500": ["500"],
                    "injected-patch-500": ["500"], "injected-delete-500": ["500"],
                    "injected-post-400": ["400"], "injected-timeout": ["net::ERR_FAILED", "net::ERR_ABORTED"],
                    "real-byte-boundaries": ["413"],
                    "real-unicode-api-boundaries": ["400"],
                }
                for message in observations["console"]:
                    if message["type"] != "error":
                        continue
                    expected_fragments = allowed_console_errors.get(message["phase"], [])
                    assert message["text"].startswith("Failed to load resource:"), message
                    assert any(fragment in message["text"] for fragment in expected_fragments), message
                    assert message["location"]["url"].startswith(origin + "/api/tasks"), message
                    message["attribution"] = "Explicit expected rejection/abort in " + message["phase"]
                observations["page_errors"] = errors
                assert not errors, errors
                record("TEST-008 console errors only match explicit injected failures or actual 413 boundary rejection")
                browser.close()
            stop()
        observations["result"] = "PASS"
    except BaseException:
        observations["result"] = "FAIL"
        observations["failure"] = traceback.format_exc()
        raise
    finally:
        stop()
        (output / "observations.json").write_text(json.dumps(observations, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--screenshots", type=Path, required=True)
    arguments = parser.parse_args()
    run(arguments.output, arguments.screenshots)
