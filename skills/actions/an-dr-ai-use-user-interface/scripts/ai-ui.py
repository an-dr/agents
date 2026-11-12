#!/usr/bin/env python3
"""An experimental browser page for talking to the user: a progress log and updatable forms.

INTENTIONAL EXCEPTION to an-dr-convention-script: this script is Python 3 (standard
library only), not PowerShell 7, because a local HTTP server is far simpler and safer
in Python. It is the only script in this repository allowed to be Python.

One page, two parts. Progress: the agent appends a step with `log` and the user sees it
within seconds. Forms: the agent writes or replaces <state>.questions.json (schema:
references/answers-json.md); the user answers, drafts are autosaved, and Commit writes
<state>.answers.json, which ends the agent's `wait`.

  serve  run in the background; serves the page on 127.0.0.1 behind a random port and a
         one-time token, until `stop` or --lifetime. Saves the page to --page when it
         starts and stops, as a read-only record.
  log    append one progress step to <state>.log.json.
  wait   block until the user commits the current questions; prints one echo line each.
  stop   ask a running server to stop.

<state> is a path prefix such as .tmp-ai-gen/ui/ui-2026-11-12_14-05, one per chat; every
file the commands share is <state>.<kind>.json. Nothing is cleared by stop and serve: the
log, the answered rounds (history), and the draft persist, and the page address is stable
for the chat (port and token are kept in <state>.session.json), so an open tab reconnects
by itself when serve runs again.

Exit codes: 0 done; 2 invalid input; 3 serve found no browser (use the text form);
4 wait timed out (the draft is kept; use the text form or wait again).
"""
import argparse
import hashlib
import hmac
import json
import os
import secrets
import subprocess
import sys
import threading
import time
import urllib.request
import webbrowser
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

EXIT_OK, EXIT_BAD_INPUT, EXIT_NO_BROWSER, EXIT_TIMEOUT = 0, 2, 3, 4
MAX_BODY = 1_000_000
STATUSES = ("doing", "done", "problem")


class InputError(Exception):
    pass


def part(state, kind):
    return Path(f"{state}.{kind}.json")


def read_json(path, default):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, ValueError):
        return default


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".tmp")
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temp, path)  # a reader never sees half a file


def validate_questions(spec):
    questions = spec.get("questions") if isinstance(spec, dict) else None
    if not isinstance(questions, list) or not questions:
        raise InputError("No questions.")
    for q in questions:
        options = q.get("options") if isinstance(q, dict) else None
        if not q.get("id") or not isinstance(options, list) or len(options) < 2:
            raise InputError(f"Question '{q.get('id') if isinstance(q, dict) else q}' needs an id and at least 2 options.")
        if not all(isinstance(o, dict) and o.get("label") for o in options):
            raise InputError(f"Question '{q['id']}' has an option without a label.")
    return questions


def load_questions(state):
    """Return (questions, hash, error); no questions file is a normal state, not an error."""
    path = part(state, "questions")
    try:
        raw = path.read_bytes()
    except OSError:
        return [], None, None
    digest = hashlib.sha1(raw).hexdigest()[:12]
    try:
        return validate_questions(json.loads(raw.decode("utf-8-sig"))), digest, None
    except (ValueError, InputError) as error:
        return [], digest, f"The questions file is invalid: {error}"


def option_keys(question):
    return [str(o["key"]).lower() if o.get("key") else chr(97 + i) for i, o in enumerate(question["options"])]


def build_answers(questions, submitted):
    """Turn the page's submission into answers JSON entries; unknown keys are dropped."""
    by_id = {item.get("id"): item for item in submitted if isinstance(item, dict)}
    answers, reply = [], []
    for number, q in enumerate(questions, start=1):
        keys = option_keys(q)
        item = by_id.get(q["id"], {})
        picked = [k for k in keys if k in (item.get("choices") or [])]
        if len(picked) > 1 and not q.get("multiSelect"):
            picked = picked[:1]
        text = (item.get("text") or "").strip() or None
        labels = [q["options"][keys.index(k)]["label"] for k in picked]
        status = "custom" if text else "answered" if picked else "open"
        answers.append({"id": q["id"], "status": status, "choices": picked, "labels": labels, "text": text})
        if text:
            reply.append(f"{number}: {text}")
        elif picked:
            reply.append(f"{number}{''.join(picked)}")
    return answers, " ".join(reply)


def echo_lines(answers):
    for a in answers:
        if a["status"] == "answered":
            yield f"{a['id']} → " + "; ".join(f"{c}. {l}" for c, l in zip(a["choices"], a["labels"]))
        elif a["status"] == "custom":
            yield f"{a['id']} → custom: {a['text']}"
        else:
            yield f"{a['id']} → open"


def snapshot(state):
    """Everything the page shows, read from the shared files."""
    questions, qhash, error = load_questions(state)
    answers = read_json(part(state, "answers"), {})
    committed = bool(qhash) and answers.get("qhash") == qhash
    # Once committed the draft is gone; show the committed answers instead.
    draft = ([{"id": a["id"], "choices": a["choices"], "text": a["text"] or ""} for a in answers["answers"]]
             if committed else read_json(part(state, "draft"), []))
    return {"questions": questions, "qhash": qhash, "error": error, "draft": draft,
            "log": read_json(part(state, "log"), []), "committed": committed,
            "history": read_json(part(state, "history"), [])}


PAGE = """<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Your agent</title>
<style>
:root{color-scheme:light dark;--bg:#fff;--fg:#1c1c1e;--muted:#6b6b70;--line:#d4d4d8;--accent:#2557d6;--card:#f6f6f8;--bad:#c0392b}
@media(prefers-color-scheme:dark){:root{--bg:#18181b;--fg:#ececef;--muted:#a1a1aa;--line:#3f3f46;--accent:#7aa2ff;--card:#222226;--bad:#ff8a7a}}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.5 system-ui,sans-serif}
main{max-width:76rem;margin:0 auto;padding:1.5rem 1rem 4rem}
.cols{display:grid;grid-template-columns:minmax(0,3fr) minmax(0,2fr);gap:2rem;align-items:start}
#right{position:sticky;top:1rem;max-height:calc(100vh - 2rem);overflow:auto}
@media(max-width:800px){.cols{grid-template-columns:1fr}#right{position:static;max-height:none}}
details{margin:.4rem 0;font-size:.9rem}
summary{cursor:pointer;color:var(--muted)}
.round{margin:.3rem 0 .6rem 1rem}
h2{font-size:1.05rem;margin:2rem 0 .6rem;border-bottom:1px solid var(--line);padding-bottom:.3rem}
#banner{padding:.6rem 1rem;border-radius:6px;background:var(--card);border:1px solid var(--line);margin:1rem 0}
#banner.bad{border-color:var(--bad)}
#log{list-style:none;margin:0;padding:0;font-size:.9rem}
#log li{padding:.25rem 0;border-bottom:1px solid var(--line)}
#log .t{color:var(--muted);font-variant-numeric:tabular-nums}
#log .s{display:inline-block;min-width:4.5rem;font-weight:600}
#log .problem .s{color:var(--bad)}
fieldset{border:1px solid var(--line);border-radius:8px;background:var(--card);margin:0 0 1.25rem;padding:1rem 1.25rem}
legend{font-weight:600;padding:0 .4rem}
label.opt{display:block;padding:.4rem .5rem;border-radius:6px;cursor:pointer}
label.opt:hover{background:rgba(127,127,127,.12)}
.desc{display:block;color:var(--muted);font-size:.875rem;margin-left:1.6rem}
input[type=text]{width:100%;box-sizing:border-box;margin-top:.6rem;padding:.45rem .6rem;border:1px solid var(--line);border-radius:6px;background:var(--bg);color:var(--fg);font:inherit}
button{background:var(--accent);color:#fff;border:0;border-radius:6px;padding:.6rem 1.4rem;font:inherit;font-weight:600;cursor:pointer}
button.link{background:none;color:var(--muted);padding:.2rem 0;font-weight:400;font-size:.8rem;text-decoration:underline}
:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
</style></head>
<body><main>
<h1>Your agent</h1>
<div id="banner" role="status" hidden></div>
<div class="cols">
<section id="left">
<h2>Interaction</h2>
<p id="note" style="color:var(--muted)"></p>
<form id="form"></form>
<p id="status" role="status"></p>
<h2>Earlier answers</h2>
<div id="history"></div>
</section>
<section id="right">
<h2>Progress</h2>
<ul id="log" aria-live="polite"></ul>
</section>
</div>
</main>
<script>
const TOKEN = __TOKEN__;
const LIVE = TOKEN !== null;
let S = __STATE__;
let shownHash = null, shownCommitted = null, sending = false;
const form = document.getElementById('form');
function el(tag, props, ...kids) {
  const node = Object.assign(document.createElement(tag), props || {});
  kids.forEach(k => node.append(k));
  return node;
}
const say = (text, bad) => { const b = document.getElementById('banner'); b.hidden = !text; b.textContent = text || ''; b.className = bad ? 'bad' : ''; };
const url = path => path + '?t=' + encodeURIComponent(TOKEN);
function collectFor(questions) {
  return questions.map((q, qi) => ({
    id: q.id,
    choices: [...form.querySelectorAll('input[name=q' + qi + ']:checked')].map(i => i.value),
    text: form.querySelector('input[name=t' + qi + ']').value
  }));
}
const collect = () => collectFor(S.questions);
function apply(values) {
  (values || []).forEach(d => {
    const qi = S.questions.findIndex(q => q.id === d.id);
    if (qi < 0) return;
    form.querySelectorAll('input[name=q' + qi + ']').forEach(i => i.checked = (d.choices || []).includes(i.value));
    form.querySelector('input[name=t' + qi + ']').value = d.text || '';
  });
}
function renderLog() {
  const list = document.getElementById('log');
  list.replaceChildren();
  if (!S.log.length) list.append(el('li', {textContent: 'Nothing yet.'}));
  [...S.log].reverse().forEach(e => list.append(el('li', {className: e.status},
    el('span', {className: 't', textContent: (e.time || '').slice(11, 19) + ' '}),
    el('span', {className: 's', textContent: e.status || ''}), e.text)));
}
function renderHistory() {
  const box = document.getElementById('history');
  box.replaceChildren();
  if (!S.history.length) { box.append(el('p', {textContent: 'None yet.', style: 'color:var(--muted)'})); return; }
  [...S.history].reverse().forEach(r => {
    const d = el('details', {}, el('summary', {textContent: (r.time || '').replace('T', ' ') + ' — ' + r.questions.length + ' question(s)'}));
    r.questions.forEach(q => {
      const a = r.answers.find(x => x.id === q.id) || {};
      const given = a.text ? 'custom: ' + a.text : (a.labels || []).join('; ') || 'open';
      d.append(el('div', {className: 'round', textContent: q.id + ' — ' + q.question + ' → ' + given}));
    });
    box.append(d);
  });
}
function renderForm(old) {
  // Keep what the user typed: read it from the form as it was, before it is rebuilt.
  const kept = old && old.questions.length ? collectFor(old.questions) : null;
  form.replaceChildren();
  const note = document.getElementById('note');
  if (S.error) { note.textContent = S.error; return; }
  if (!S.questions.length) { note.textContent = 'Nothing to answer right now.'; return; }
  note.textContent = S.committed ? 'Committed. Your agent is working on it.' : 'Pick an option or type your own answer. Changes are saved as you go; press Commit to send them.';
  S.questions.forEach((q, qi) => {
    const set = el('fieldset', {}, el('legend', {textContent: q.id + ' — ' + q.question}));
    q.options.forEach((o, oi) => {
      const key = o.key ? String(o.key).toLowerCase() : String.fromCharCode(97 + oi);
      const row = el('label', {className: 'opt'}, el('input', {type: q.multiSelect ? 'checkbox' : 'radio', name: 'q' + qi, value: key}), ' ', el('strong', {textContent: key + '. '}), o.label);
      if (o.description) row.append(el('span', {className: 'desc', textContent: o.description}));
      set.append(row);
    });
    set.append(el('input', {type: 'text', name: 't' + qi, placeholder: 'Or your own answer…', 'aria-label': 'Own answer for ' + q.id}));
    form.append(set);
  });
  if (LIVE && !S.committed) form.append(el('button', {type: 'submit', textContent: 'Commit'}));
  apply(kept || S.draft);
  if (!LIVE || S.committed) form.querySelectorAll('input,button').forEach(i => i.disabled = true);
}
function render(old) {
  renderLog(); renderHistory();
  if (S.qhash !== shownHash || S.committed !== shownCommitted) { renderForm(old); shownHash = S.qhash; shownCommitted = S.committed; }
}
render(null);
if (!LIVE) say('Read-only record: your agent is not running this page any more.');
else {
  let timer = null;
  form.addEventListener('input', () => {
    clearTimeout(timer);
    timer = setTimeout(() => fetch(url('/draft'), {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({answers: collect()})}).catch(() => {}), 400);
  });
  form.onsubmit = async event => {
    event.preventDefault();
    sending = true;
    try {
      const r = await fetch(url('/commit'), {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({answers: collect(), qhash: S.qhash})});
      if (!r.ok) throw new Error('HTTP ' + r.status);
      const old = S; S = Object.assign({}, S, {committed: true}); render(old);
    } catch (error) { document.getElementById('status').textContent = 'Not sent: ' + error.message + '. Answer in the chat instead.'; }
    sending = false;
  };
  setInterval(() => fetch(url('/state')).then(r => { if (!r.ok) throw 0; return r.json(); }).then(next => { if (sending) return; say(''); const old = S; S = next; render(old); })
    .catch(() => say('Your agent is not serving this page right now. Your draft is saved, and this page reconnects by itself when the agent starts it again.', true)), 2500);
}
</script></body></html>
"""


def render_page(state_data, token):
    """token=None renders the read-only record: nothing polls and nothing can be sent."""
    # Escape "<" so a label or log line can never close the script element.
    embed = lambda value: json.dumps(value, ensure_ascii=False).replace("<", "\\u003c")
    return PAGE.replace("__STATE__", embed(state_data)).replace("__TOKEN__", embed(token))


class Server(ThreadingHTTPServer):
    # On Windows SO_REUSEADDR would let a second server share the port, so it stays off there.
    allow_reuse_address = os.name != "nt"

    def __init__(self, state, token, port=0):
        super().__init__(("127.0.0.1", port), Handler)
        self.state, self.token = state, token
        self.last_touch = 0.0

    def touch_seen(self):
        """Note that a page is open (at most every 10 s) so a restart does not open a second tab."""
        now = time.time()
        if now - self.last_touch > 10:
            self.last_touch = now
            part(self.state, "seen").write_text(str(now), encoding="utf-8")

    def allowed_hosts(self):
        port = self.server_address[1]
        return {f"127.0.0.1:{port}", f"localhost:{port}"}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass  # stdout belongs to the agent; keep it free of request noise

    def authorized(self):
        # Host check stops DNS rebinding; the token stops other local pages posting here.
        if self.headers.get("Host", "") not in self.server.allowed_hosts():
            return False
        given = parse_qs(urlparse(self.path).query).get("t", [""])[0]
        return hmac.compare_digest(given, self.server.token)

    def reply(self, code, body=b"", content_type="text/plain; charset=utf-8"):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        if path not in ("/", "/state") or not self.authorized():
            return self.reply(403, b"Forbidden")
        data = snapshot(self.server.state)
        if path == "/state":
            self.server.touch_seen()
            return self.reply(200, json.dumps(data, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")
        self.reply(200, render_page(data, self.server.token).encode("utf-8"), "text/html; charset=utf-8")

    def do_POST(self):
        path = urlparse(self.path).path
        if path not in ("/draft", "/commit") or not self.authorized():
            return self.reply(403, b"Forbidden")
        length = int(self.headers.get("Content-Length") or 0)
        if not 0 < length <= MAX_BODY:
            return self.reply(400, b"Bad body")
        try:
            body = json.loads(self.rfile.read(length))
            submitted = body["answers"]
            assert isinstance(submitted, list)
        except (ValueError, KeyError, AssertionError):
            return self.reply(400, b"Bad body")
        state = self.server.state
        if path == "/draft":
            write_json(part(state, "draft"), submitted)
            return self.reply(200, b"ok")
        questions, qhash, _ = load_questions(state)
        if not questions or body.get("qhash") != qhash:
            return self.reply(409, b"The questions changed; reload the page")
        answers, reply = build_answers(questions, submitted)
        write_json(part(state, "answers"), {"questions": str(part(state, "questions").resolve()), "qhash": qhash, "reply": reply, "answers": answers})
        part(state, "draft").unlink(missing_ok=True)
        history = read_json(part(state, "history"), [])
        history.append({"time": datetime.now().isoformat(timespec="seconds"), "questions": questions, "answers": answers})
        write_json(part(state, "history"), history)
        self.reply(200, b"ok")


def can_open_browser():
    # webbrowser.open() succeeds on a headless Linux box with a text browser, which helps nobody.
    if sys.platform.startswith("linux") and not (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")):
        return False
    return True


def exclude_from_git(page):
    """Add the page to .git/info/exclude (as the progress page does) so the skill leaves no git diff."""
    page = Path(page).resolve()
    try:
        run = lambda *a: subprocess.run(["git", *a], cwd=page.parent, capture_output=True, text=True, check=True).stdout.strip()
        relative = page.relative_to(Path(run("rev-parse", "--show-toplevel")).resolve()).as_posix()
        exclude = run("rev-parse", "--git-path", "info/exclude")
    except (OSError, subprocess.CalledProcessError, ValueError):
        return  # not in a git repository: nothing to exclude
    exclude = Path(exclude) if os.path.isabs(exclude) else page.parent / exclude
    lines = exclude.read_text(encoding="utf-8").splitlines() if exclude.exists() else []
    if f"/{relative}" not in lines:
        exclude.parent.mkdir(parents=True, exist_ok=True)
        with exclude.open("a", encoding="utf-8") as handle:
            handle.write(("\n" if lines and lines[-1] else "") + f"/{relative}\n")


def save_record(state, page):
    Path(page).write_text(render_page(snapshot(state), None), encoding="utf-8")
    exclude_from_git(page)


def session(state):
    """The chat's stable address: a port derived from the state name and a token, kept on disk."""
    data = read_json(part(state, "session"), {})
    if not (isinstance(data.get("port"), int) and data.get("token")):
        digest = int(hashlib.sha1(str(state).encode("utf-8")).hexdigest()[:8], 16)
        data = {"port": 49152 + digest % 10000, "token": secrets.token_urlsafe(24)}
        write_json(part(state, "session"), data)
    return data


def already_serving(port, token):
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/state?t={token}", timeout=2) as response:
            return response.status == 200
    except OSError:
        return False


def cmd_serve(args):
    sess = session(args.state)
    address = lambda port: f"http://127.0.0.1:{port}/?t={sess['token']}"
    if already_serving(sess["port"], sess["token"]):
        print(f"Page already served at {address(sess['port'])}")
        return EXIT_OK
    stop_file = part(args.state, "stop")
    stop_file.unlink(missing_ok=True)
    try:
        server = Server(args.state, sess["token"], sess["port"])
    except OSError:  # something else holds the port: take another one, so the address changes this once
        server = Server(args.state, sess["token"], 0)
        sess["port"] = server.server_address[1]
        write_json(part(args.state, "session"), sess)
    url = address(server.server_address[1])
    seen = part(args.state, "seen")
    tab_open = seen.exists() and time.time() - seen.stat().st_mtime < 60  # an open tab reconnects by itself
    if not args.no_open and not tab_open and not (can_open_browser() and webbrowser.open(url)):
        print("No browser could be opened here; use the text form.", file=sys.stderr)
        server.server_close()
        return EXIT_NO_BROWSER
    threading.Thread(target=server.serve_forever, daemon=True).start()
    save_record(args.state, args.page)
    print(f"Page served at {url}" + (" (the open tab reconnects by itself)" if tab_open and not args.no_open else ""), flush=True)
    deadline = time.monotonic() + args.lifetime
    while not stop_file.exists() and time.monotonic() < deadline:
        time.sleep(0.5)
    server.shutdown()
    server.server_close()
    stop_file.unlink(missing_ok=True)
    save_record(args.state, args.page)
    return EXIT_OK


def cmd_log(args):
    log = read_json(part(args.state, "log"), [])
    log.append({"time": datetime.now().isoformat(timespec="seconds"), "status": args.status, "text": args.text})
    write_json(part(args.state, "log"), log)
    return EXIT_OK


def cmd_wait(args):
    deadline = time.monotonic() + args.timeout
    while True:
        questions, qhash, error = load_questions(args.state)
        if error or not questions:
            print(error or "No questions to wait for; write <state>.questions.json first.", file=sys.stderr)
            return EXIT_BAD_INPUT
        answers = read_json(part(args.state, "answers"), {})
        if answers.get("qhash") == qhash:
            print("\n".join(echo_lines(answers["answers"])))
            return EXIT_OK
        if time.monotonic() >= deadline:
            print(f"No Commit within {args.timeout} seconds; the draft is kept. Use the text form or wait again.", file=sys.stderr)
            return EXIT_TIMEOUT
        time.sleep(1)


def cmd_stop(args):
    part(args.state, "stop").write_text("stop", encoding="utf-8")
    return EXIT_OK


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    for name, helptext in (("serve", "serve the page until stopped"), ("log", "append a progress step"),
                           ("wait", "block until the user commits"), ("stop", "stop a running server")):
        command = sub.add_parser(name, help=helptext)
        command.add_argument("--state", required=True, help="path prefix shared by every file of this conversation")
        if name == "serve":
            command.add_argument("--page", default="tmp-ai-ui.html", help="read-only record of the page (default tmp-ai-ui.html)")
            command.add_argument("--lifetime", type=int, default=3600, help="seconds before the server stops by itself (default 3600)")
            command.add_argument("--no-open", action="store_true", help="print the URL instead of opening a browser")
        if name == "log":
            command.add_argument("text", help="what is happening, one line")
            command.add_argument("--status", choices=STATUSES, default="doing")
        if name == "wait":
            command.add_argument("--timeout", type=int, default=540, help="seconds to wait for Commit (default 540)")
    args = parser.parse_args(argv)
    # The echo lines carry "→" and user text; a legacy Windows code page would crash on them.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    return {"serve": cmd_serve, "log": cmd_log, "wait": cmd_wait, "stop": cmd_stop}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
