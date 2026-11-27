"""Rebuild the checked-in Node runtime from the pinned Go module, without modifying its cache."""
import gzip
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

here = Path(__file__).resolve().parent
output = here.parents[1] / "plugins/sdd-quality-loop/scripts/v2/shell-parser"
os.chdir(here)
env = {**os.environ, "GOOS": "js", "GOARCH": "wasm", "CGO_ENABLED": "0", "GOTOOLCHAIN": "local"}


def go(*args, capture=True):
    return subprocess.run(["go", *args], env=env, check=True, text=True, capture_output=capture).stdout


if go("env", "GOVERSION").strip() != "go1.26.11":
    raise SystemExit("Go 1.26.11 is required to regenerate this artifact")
dependency = json.loads(go("mod", "download", "-json", "mvdan.cc/sh/v3"))
module = Path(dependency["Dir"])
goroot = Path(go("env", "GOROOT").strip())
with tempfile.TemporaryDirectory() as temp:
    temp = Path(temp)
    for name in ("main.go", "go.mod", "go.sum"):
        shutil.copyfile(here / name, temp / name)
    os.chdir(temp)
    go("mod", "vendor", capture=False)
    syntax = temp / "vendor/mvdan.cc/sh/v3/syntax"
    # Apply the zero-context patch against the pristine, checksum-pinned module.
    subprocess.run(["git", "apply", "--unidiff-zero", str(here / "zsh-loops.patch")], cwd=temp, check=True)
    shutil.copyfile(here / "zsh_loops.go.in", syntax / "zsh_loops.go")
    parser = syntax / "parser.go"
    original = parser.read_text()
    # Preserve the product's dialect-aware quote removal for the delimiter word supplied
    # by the actual grammar. Upstream leaves ANSI-C escapes in the stop word verbatim.
    signature = "func (p *Parser) unquotedWordBytes(w *Word) ([]byte, bool) {"
    assert original.count(signature) == 1
    modified = original.replace(signature, "var HeredocDelimiter func(*Word) ([]byte, bool)\n\n" + signature
                                + "\n\tif HeredocDelimiter != nil { return HeredocDelimiter(w) }")
    parser.write_text(modified)
    # The lexer measures the first rune of a delimiter line in bytes. Its
    # upstream one-byte subtraction splits non-ASCII terminators such as é.
    lexer = temp / "vendor/mvdan.cc/sh/v3/syntax/lexer.go"
    text = lexer.read_text()
    start = "lStart := len(p.litBs) - 1"
    assert text.count(start) == 2
    lexer.write_text(text.replace(start, start + "\n\tif r >= utf8.RuneSelf && r <= utf8.MaxRune { lStart -= utf8.RuneLen(r)-1 }"))
    wasm = temp / "parser.wasm"
    go("build", "-mod=vendor", "-trimpath", "-buildvcs=false", "-ldflags=-s -w -buildid=",
       "-o", str(wasm), ".", capture=False)
    with (output / "parser.wasm.gz").open("wb") as dest:
        with gzip.GzipFile(fileobj=dest, filename="", mode="wb", mtime=0) as archive:
            archive.write(wasm.read_bytes())
shutil.copyfile(goroot / "lib/wasm/wasm_exec.js", output / "wasm_exec.cjs")
shutil.copyfile(goroot / "LICENSE", output / "LICENSE.Go")
shutil.copyfile(module / "LICENSE", output / "LICENSE.mvdan-sh")
