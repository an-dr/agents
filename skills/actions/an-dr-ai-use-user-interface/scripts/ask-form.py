#!/usr/bin/env python3
"""Ask the user a round of questions in a local browser form and write answers JSON.

INTENTIONAL EXCEPTION to an-dr-convention-script: this script is Python 3 (standard
library only), not PowerShell 7, because a local HTTP server is far simpler and safer
in Python. It is the only script in this repository allowed to be Python.

Reads a questions file (schema: references/answers-json.md), serves one page on
127.0.0.1 behind a random port and a one-time token, waits for the user's submit,
and writes the same answers JSON that read-answers.ps1 writes.

Exit codes:
  0  answers written
  2  the questions file is missing or invalid
  3  no browser can be opened here (headless session): use the text form
  4  the user did not answer in time: nothing written, use the text form
"""
import argparse
import hmac
import json
import os
import secrets
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

EXIT_OK, EXIT_BAD_INPUT, EXIT_NO_BROWSER, EXIT_TIMEOUT = 0, 2, 3, 4
MAX_BODY = 1_000_000


class InputError(Exception):
    pass


def load_questions(path):
    try:
        spec = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as error:
        raise InputError(f"Cannot read {path}: {error}")
    questions = spec.get("questions") if isinstance(spec, dict) else None
    if not isinstance(questions, list) or not questions:
        raise InputError(f"No questions in {path}.")
    for q in questions:
        options = q.get("options") if isinstance(q, dict) else None
        if not q.get("id") or not isinstance(options, list) or len(options) < 2:
            raise InputError(f"Question '{q.get('id') if isinstance(q, dict) else q}' needs an id and at least 2 options.")
        if not all(isinstance(o, dict) and o.get("label") for o in options):
            raise InputError(f"Question '{q['id']}' has an option without a label.")
    return questions


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


def answers_path(questions_path):
    path = Path(questions_path).resolve()
    if path.name.endswith(".questions.json"):
        return path.with_name(path.name[: -len(".questions.json")] + ".answers.json")
    return path.with_name("answers.json")


PAGE = """<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Questions</title>
<style>
:root{color-scheme:light dark;--bg:#fff;--fg:#1c1c1e;--muted:#6b6b70;--line:#d4d4d8;--accent:#2557d6;--card:#f6f6f8}
@media(prefers-color-scheme:dark){:root{--bg:#18181b;--fg:#ececef;--muted:#a1a1aa;--line:#3f3f46;--accent:#7aa2ff;--card:#222226}}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.5 system-ui,sans-serif}
main{max-width:46rem;margin:0 auto;padding:2rem 1rem 4rem}
fieldset{border:1px solid var(--line);border-radius:8px;background:var(--card);margin:0 0 1.25rem;padding:1rem 1.25rem}
legend{font-weight:600;padding:0 .4rem}
label.opt{display:block;padding:.4rem .5rem;border-radius:6px;cursor:pointer}
label.opt:hover{background:rgba(127,127,127,.12)}
.desc{display:block;color:var(--muted);font-size:.875rem;margin-left:1.6rem}
input[type=text]{width:100%;box-sizing:border-box;margin-top:.6rem;padding:.45rem .6rem;border:1px solid var(--line);border-radius:6px;background:var(--bg);color:var(--fg);font:inherit}
button{background:var(--accent);color:#fff;border:0;border-radius:6px;padding:.6rem 1.4rem;font:inherit;font-weight:600;cursor:pointer}
button.link{background:none;color:var(--muted);padding:.2rem 0;font-weight:400;font-size:.8rem;text-decoration:underline}
:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
#done{display:none}
</style></head>
<body><main>
<h1>Questions from your agent</h1>
<p style="color:var(--muted)">Pick an option, or type your own answer. Anything left blank stays open.</p>
<form id="form"></form>
<p id="status" role="status"></p>
<div id="done"><h2>Sent</h2><p>You can close this tab and go back to your agent.</p></div>
</main>
<script>
const QUESTIONS = __QUESTIONS__;
const TOKEN = __TOKEN__;
const form = document.getElementById('form');
function el(tag, props, ...kids) {
  const node = Object.assign(document.createElement(tag), props || {});
  kids.forEach(k => node.append(k));
  return node;
}
QUESTIONS.forEach((q, qi) => {
  const set = el('fieldset', {id: 'q' + qi}, el('legend', {textContent: q.id + ' — ' + q.question}));
  const type = q.multiSelect ? 'checkbox' : 'radio';
  q.options.forEach((o, oi) => {
    const key = o.key ? String(o.key).toLowerCase() : String.fromCharCode(97 + oi);
    const input = el('input', {type, name: 'q' + qi, value: key});
    const row = el('label', {className: 'opt'}, input, ' ', el('strong', {textContent: key + '. '}), o.label);
    if (o.description) row.append(el('span', {className: 'desc', textContent: o.description}));
    set.append(row);
  });
  set.append(el('input', {type: 'text', name: 't' + qi, placeholder: 'Or your own answer…', 'aria-label': 'Own answer for ' + q.id}));
  if (!q.multiSelect) {
    const clear = el('button', {type: 'button', className: 'link', textContent: 'Clear choice'});
    clear.onclick = () => set.querySelectorAll('input[type=radio]').forEach(r => r.checked = false);
    set.append(clear);
  }
  form.append(set);
});
form.append(el('button', {type: 'submit', textContent: 'Send answers'}));
form.onsubmit = async event => {
  event.preventDefault();
  const answers = QUESTIONS.map((q, qi) => ({
    id: q.id,
    choices: [...form.querySelectorAll('input[name=q' + qi + ']:checked')].map(i => i.value),
    text: form.querySelector('input[name=t' + qi + ']').value
  }));
  const status = document.getElementById('status');
  try {
    const response = await fetch('/submit?t=' + encodeURIComponent(TOKEN), {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({answers})});
    if (!response.ok) throw new Error('HTTP ' + response.status);
    form.style.display = 'none'; status.textContent = '';
    document.getElementById('done').style.display = 'block';
  } catch (error) { status.textContent = 'Not sent: ' + error.message + '. Answer in the chat instead.'; }
};
</script></body></html>
"""


def render_page(questions, token):
    # Escape "<" so a label can never close the script element.
    embed = lambda value: json.dumps(value, ensure_ascii=False).replace("<", "\\u003c")
    return PAGE.replace("__QUESTIONS__", embed(questions)).replace("__TOKEN__", embed(token))


class Server(ThreadingHTTPServer):
    def __init__(self, questions, token):
        super().__init__(("127.0.0.1", 0), Handler)
        self.questions, self.token = questions, token
        self.submitted = None
        self.finished = threading.Event()

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
        if urlparse(self.path).path != "/" or not self.authorized():
            return self.reply(403, b"Forbidden")
        page = render_page(self.server.questions, self.server.token).encode("utf-8")
        self.reply(200, page, "text/html; charset=utf-8")

    def do_POST(self):
        if urlparse(self.path).path != "/submit" or not self.authorized():
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
        if self.server.finished.is_set():
            return self.reply(409, b"Already answered")
        self.server.submitted = submitted
        self.server.finished.set()
        self.reply(200, b"ok")


def can_open_browser():
    # webbrowser.open() succeeds on a headless Linux box with a text browser, which helps nobody.
    if sys.platform.startswith("linux") and not (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")):
        return False
    return True


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--questions", required=True, help="questions JSON file")
    parser.add_argument("--out", help="answers JSON file (default: beside the questions file)")
    parser.add_argument("--timeout", type=int, default=540, help="seconds to wait for the user (default 540)")
    parser.add_argument("--no-open", action="store_true", help="print the URL instead of opening a browser")
    args = parser.parse_args(argv)
    # The echo lines carry "→" and user text; a legacy Windows code page would crash on them.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

    try:
        questions = load_questions(args.questions)
    except InputError as error:
        print(error, file=sys.stderr)
        return EXIT_BAD_INPUT

    server = Server(questions, secrets.token_urlsafe(24))
    url = f"http://127.0.0.1:{server.server_address[1]}/?t={server.token}"
    if not args.no_open and not (can_open_browser() and webbrowser.open(url)):
        print("No browser could be opened here; use the text form.", file=sys.stderr)
        server.server_close()
        return EXIT_NO_BROWSER

    threading.Thread(target=server.serve_forever, daemon=True).start()
    print(f"Form open at {url}" if args.no_open else "Form opened in your browser; waiting for the answers.", flush=True)
    answered = server.finished.wait(args.timeout)
    server.shutdown()
    server.server_close()
    if not answered:
        print(f"No answers within {args.timeout} seconds; use the text form.", file=sys.stderr)
        return EXIT_TIMEOUT

    answers, reply = build_answers(questions, server.submitted)
    out = Path(args.out) if args.out else answers_path(args.questions)
    record = {"questions": str(Path(args.questions).resolve()), "reply": reply, "answers": answers}
    out.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("\n".join(echo_lines(answers)))
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
