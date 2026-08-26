# StatsApp — AP Statistics helper for the TI-Nspire

A TI-Nspire Lua app. Pick a unit, say how many data points you have, type them
in one at a time, and the moment you enter the last one it drops you straight
into a full 1-Var Stats read-out.

Currently implemented: **Unit 1 — Exploring One-Variable Data**. Units 2–9 are
listed on the menu but greyed out.

```
src/apstats.lua     the app (this is what goes inside the .tns)
tests/harness.lua   fake TI-Nspire environment + assertions
tests/run.py        runs the harness in a real Lua 5.1 interpreter
```

---

## Building the .tns

The `.tns` is a container format that only TI's tooling writes, so the Lua has
to be packaged. Pick whichever route you have access to.

### A. TI-Nspire Student / Teacher Software (the official route)

1. **File → New Document → Add Notes** (any page type is fine).
2. **Insert → Script Editor → Insert Script**.
3. Name it `apstats` and click OK.
4. Select everything in the editor and delete it.
5. Paste the entire contents of [src/apstats.lua](src/apstats.lua).
6. Click **Set Script** (the ✓ button, or Ctrl+B). Any error shows in the
   console pane at the bottom — a clean compile prints nothing.
7. **File → Save As → `StatsApp.tns`**.
8. Plug in the handheld and drag the `.tns` onto it in the Content Explorer.

### B. TI-Planet Project Builder (free, browser, no install)

<https://tiplanet.org/pb/> — paste `src/apstats.lua` in, hit build, download the
`.tns`. This is the easiest option if you don't have the TI software.

### C. Luna (command line)

[Luna](https://github.com/ndless-nspire/Luna) is the open-source packager:

```
luna src/apstats.lua StatsApp.tns
```

`build.ps1` in this repo wraps that — it finds `luna` on your PATH (or in
`tools/`) and writes `StatsApp.tns` for you.

---

## Using the app

**Menu** — Up/Down to move, **enter** to open. (You can also press `1`–`9`, or
click an entry in the computer software.)

**How many data points?** — type a whole number from 1 to 200, press **enter**.

**Entering data** — type a value, press **enter**, repeat. The values you've
typed appear underneath in three columns with the current one highlighted.

| key | what it does |
| --- | --- |
| `(-)` | negative sign — press it again to flip the sign back |
| `.` | decimal point |
| **del** | erase a digit; on an empty box it clears the stored value, then steps back |
| **clear** | wipe the whole box |
| **Up/Down/Left/Right** | jump to another value to fix a typo |
| **esc** | back to the "how many?" screen |

After the **last** value you press enter and the statistics appear immediately.

**Results** — Up/Down scrolls. **esc** goes back to the data so you can correct
a value (re-entering the last one takes you straight back to the results).
`M` returns to the menu, `R` starts a new data set.

### What you get

| section | values |
| --- | --- |
| Summary | `n`, `x̄`, `Σx`, `Σx²`, `sx` (sample SD), `σx` (population SD), `SSx` |
| Five-Number Summary | MinX, Q1, Median, Q3, MaxX |
| Spread | Range, IQR, Mode(s) |
| Outliers | lower/upper fence from the 1.5 × IQR rule, and any values outside them |
| Shape | compares mean to median and calls the skew |

Quartiles use the TI / AP method: the median of each half, with the overall
median excluded when `n` is odd. This matches what `OneVar` gives you on the
calculator, so your answers will agree with the TI-84 too.

`sx` shows `undef` when `n = 1`, same as the calculator.

---

## Running the tests

The tests load the real `src/apstats.lua` into a mocked TI-Nspire environment
and drive it with actual keystrokes, then read back every string it drew — so
they cover the statistics *and* the screen flow.

```
python -m pip install lupa
python tests/run.py
```

`lupa` bundles Lua 5.1, which is what the Nspire runs, so a pass here is
meaningful. Edit `src/apstats.lua`, re-run, then rebuild the `.tns`.
