"""Run tests/harness.lua against src/apstats.lua in a real Lua interpreter.

Needs `lupa`:  python -m pip install lupa
Run from the repo root:  python tests/run.py
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# allow a scratch install of lupa via LUPA_PATH
extra = os.environ.get("LUPA_PATH")
if extra:
    sys.path.insert(0, extra)

# The TI-Nspire runs Lua 5.1, so test against 5.1 whenever lupa provides it.
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    try:
        from lupa import LuaRuntime
    except ImportError:
        sys.exit("lupa is not installed.  python -m pip install lupa")
    print("warning: lupa has no Lua 5.1 runtime, falling back")

os.chdir(ROOT)

lua = LuaRuntime(unpack_returned_tuples=True)
print("Lua:", lua.eval("_VERSION"))

with open("tests/harness.lua", "r", encoding="ascii") as fh:
    source = fh.read()

try:
    lua.execute(source)
except BaseException as exc:  # os.exit(1) inside Lua surfaces here
    msg = str(exc)
    if "exit" in msg.lower():
        sys.exit(1)
    raise
