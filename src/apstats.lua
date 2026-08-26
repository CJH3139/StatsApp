platform.apilevel = '2.0'

--[[ =========================================================================
     AP STATISTICS HELPER   --   TI-Nspire Lua
     Unit 1: Exploring One-Variable Data

     Flow:  Menu (pick a unit)
              -> How many data points?
              -> Type the values one at a time
              -> Full 1-Var Stats read-out

     This file is 100% ASCII on purpose: every special symbol (Sigma,
     sigma, superscript 2, the calculator's (-) minus) is written as a
     byte escape so the source survives any copy/paste or editor
     encoding without turning into garbage on the handheld.
========================================================================= ]]

local APP  = "AP Statistics"
local VER  = "1.0"
local MAXN = 200

-- UTF-8 byte escapes for the few non-ASCII glyphs we draw
local SIGMA_U = "\206\163"        -- U+03A3  capital sigma
local SIGMA_L = "\207\131"        -- U+03C3  small sigma
local SUP2    = "\194\178"        -- U+00B2  superscript two
local MINUS_U = "\226\136\146"    -- U+2212  the (-) key on the handheld

--=========================================================================
-- 1.  Look and feel
--=========================================================================
local W, H = 318, 212

local COL = {
  bg      = {255, 255, 255},
  header  = { 26,  58,  92},
  headerT = {255, 255, 255},
  headerS = {150, 180, 212},
  text    = { 25,  25,  25},
  dim     = {135, 135, 135},
  accent  = {  0, 110, 200},
  selBg   = {212, 231, 250},
  line    = {205, 205, 205},
  panel   = {243, 246, 250},
  ok      = {  0, 130,  65},
  bad     = {185,  45,  45},
  white   = {255, 255, 255},
}

local function setc(gc, c) gc:setColorRGB(c[1], c[2], c[3]) end

-- everything is authored against a 318x212 handheld screen and scaled up
local function u(v) return v * H / 212 end

local FSIZES = {6, 7, 8, 9, 10, 11, 12, 16, 24}
local function snapFont(s)
  local best = FSIZES[1]
  for _, v in ipairs(FSIZES) do
    if math.abs(v - s) < math.abs(best - s) then best = v end
  end
  return best
end

local function font(gc, base, style)
  gc:setFont("sansserif", style or "r", snapFont(base * H / 212))
end

local function box(gc, x, y, w, h, fill, border)
  if fill   then setc(gc, fill);   gc:fillRect(x, y, w, h) end
  if border then setc(gc, border); gc:drawRect(x, y, w, h) end
end

local function refresh() platform.window:invalidate() end

local function clip(gc, s, maxw)
  if gc:getStringWidth(s) <= maxw then return s end
  local out = s
  while #out > 1 and gc:getStringWidth(out .. "..") > maxw do
    out = out:sub(1, #out - 1)
  end
  return out .. ".."
end

--=========================================================================
-- 2.  Number formatting and keyboard input
--=========================================================================

-- 6 significant digits, integers stay integers, exponents look like 1.2E8
local function fmt(v, sig)
  if v == nil          then return "undef" end
  if v ~= v            then return "undef" end
  if v ==  math.huge   then return "inf"   end
  if v == -math.huge   then return "-inf"  end
  local a = math.abs(v)
  local s
  if v == math.floor(v) and a < 1e10 then
    s = string.format("%.0f", v)
  else
    s = string.format("%." .. (sig or 6) .. "g", v)
  end
  s = (s:gsub("e%+?(%-?)0*(%d)", "E%1%2"))
  if s == "-0" then s = "0" end
  return s
end

-- the handheld's (-) key sends U+2212, not ASCII '-'
local function normalize(ch)
  if ch == MINUS_U then return "-" end
  if ch == ","     then return "." end
  return ch
end

-- append one keystroke to a numeric edit buffer
local function acceptChar(s, ch)
  if ch:match("^%d$") then return s .. ch end
  if ch == "." then
    if s:find(".", 1, true) then return s end
    return (s == "" or s == "-") and (s .. "0.") or (s .. ".")
  end
  if ch == "-" then
    if s == ""  then return "-"          end   -- start a negative
    if s == "-" then return ""           end   -- pressed twice: undo
    if s:sub(1, 1) == "-" then return s:sub(2) end
    return "-" .. s                            -- flip the sign
  end
  return s
end

--=========================================================================
-- 3.  One-variable statistics
--=========================================================================

-- median of the slice t[lo..hi] (t must already be sorted)
local function medianOf(t, lo, hi)
  local cnt = hi - lo + 1
  if cnt <= 0 then return nil end
  local mid = lo + math.floor((cnt - 1) / 2)
  if cnt % 2 == 1 then return t[mid] end
  return (t[mid] + t[mid + 1]) / 2
end

local function computeStats(data)
  local n = #data
  if n == 0 then return nil end

  local x = {}
  for i = 1, n do x[i] = data[i] end
  table.sort(x)

  local s = { n = n, sorted = x }

  local sum, sumsq = 0, 0
  for i = 1, n do
    sum   = sum   + x[i]
    sumsq = sumsq + x[i] * x[i]
  end
  s.sum, s.sumsq = sum, sumsq
  s.mean = sum / n

  -- SSx computed from deviations (numerically kinder than sumsq - n*mean^2)
  local ss = 0
  for i = 1, n do
    local d = x[i] - s.mean
    ss = ss + d * d
  end
  s.ss    = ss
  s.sigma = math.sqrt(ss / n)
  s.sx    = (n > 1) and math.sqrt(ss / (n - 1)) or nil

  s.min = x[1]
  s.max = x[n]
  s.med = medianOf(x, 1, n)

  -- TI / AP quartiles: median of each half, the overall median excluded
  if n == 1 then
    s.q1, s.q3 = x[1], x[1]
  else
    local half = math.floor(n / 2)
    s.q1 = medianOf(x, 1, half)
    s.q3 = medianOf(x, n - half + 1, n)
  end
  s.iqr   = s.q3 - s.q1
  s.range = s.max - s.min
  s.lof   = s.q1 - 1.5 * s.iqr
  s.hif   = s.q3 + 1.5 * s.iqr

  s.outliers = {}
  for i = 1, n do
    if x[i] < s.lof or x[i] > s.hif then
      s.outliers[#s.outliers + 1] = x[i]
    end
  end

  -- mode(s): walk the sorted list counting runs of equal values
  local bestCount, modes = 0, {}
  local i = 1
  while i <= n do
    local j = i
    while j < n and x[j + 1] == x[i] do j = j + 1 end
    local c = j - i + 1
    if c > bestCount then
      bestCount, modes = c, {x[i]}
    elseif c == bestCount then
      modes[#modes + 1] = x[i]
    end
    i = j + 1
  end
  s.modeCount, s.modes = bestCount, modes

  return s
end

local function modeText(s)
  if s.modeCount <= 1 then return "none" end
  local parts = {}
  for i = 1, math.min(#s.modes, 3) do parts[i] = fmt(s.modes[i], 5) end
  local t = table.concat(parts, ", ")
  if #s.modes > 3 then t = t .. ", ..." end
  return t .. "  (x" .. s.modeCount .. ")"
end

local function listText(t, maxItems)
  if #t == 0 then return "none" end
  local parts = {}
  for i = 1, math.min(#t, maxItems) do parts[i] = fmt(t[i], 5) end
  local str = table.concat(parts, ", ")
  if #t > maxItems then str = str .. ", ...  (" .. #t .. " total)" end
  return str
end

local function shapeHint(s)
  if s.n == 1 then return "only one value - no shape to describe" end
  local spread = s.sx or s.sigma
  if spread == nil or spread == 0 then return "every value is identical" end
  local d = (s.mean - s.med) / spread
  if d > 0.15 then
    return "mean > median  ->  likely skewed RIGHT"
  elseif d < -0.15 then
    return "mean < median  ->  likely skewed LEFT"
  end
  return "mean is close to the median  ->  roughly symmetric"
end

--=========================================================================
-- 4.  Application state
--=========================================================================
local state     = "menu"     -- menu | count | entry | results
local menuSel   = 1
local menuRects = {}

local countBuf  = ""         -- edit buffer on the "how many?" screen
local nWanted   = 0

local values    = {}         -- values[i] = number, or nil if not typed yet
local idx       = 1          -- which value is being typed
local buf       = ""         -- edit buffer for values[idx]

local stats     = nil
local rows      = {}
local scrollIdx = 0

local err       = nil        -- one-line message under the input box

--=========================================================================
-- 5.  Building the results read-out
--=========================================================================
local function buildRows(s)
  local r = {}
  local function head(t)    r[#r + 1] = {kind = "head", label = t} end
  local function note(t, c) r[#r + 1] = {kind = "note", label = t, color = c} end
  local function row(l, v, o)
    o = o or {}
    r[#r + 1] = {kind = "row", label = l, value = v, bar = o.bar, color = o.color}
  end

  head("Summary")
  row("n",                    fmt(s.n))
  row("x    (mean)",          fmt(s.mean), {bar = true})
  row(SIGMA_U .. "x",         fmt(s.sum))
  row(SIGMA_U .. "x" .. SUP2, fmt(s.sumsq))
  row("sx   (sample SD)",     fmt(s.sx))
  row(SIGMA_L .. "x   (population SD)", fmt(s.sigma))
  row("SSx  (sum of sq. dev.)",         fmt(s.ss))

  head("Five-Number Summary")
  row("MinX",   fmt(s.min))
  row("Q1",     fmt(s.q1))
  row("Median", fmt(s.med))
  row("Q3",     fmt(s.q3))
  row("MaxX",   fmt(s.max))

  head("Spread")
  row("Range  (max - min)", fmt(s.range))
  row("IQR    (Q3 - Q1)",   fmt(s.iqr))
  row("Mode",               modeText(s))

  head("Outliers   (1.5 x IQR rule)")
  row("Lower fence  Q1 - 1.5*IQR", fmt(s.lof))
  row("Upper fence  Q3 + 1.5*IQR", fmt(s.hif))
  note(listText(s.outliers, 6), (#s.outliers > 0) and COL.bad or COL.ok)

  head("Shape")
  note(shapeHint(s))

  return r
end

--=========================================================================
-- 6.  Shared chrome
--=========================================================================
local function drawHeader(gc, title, right)
  local hh = u(26)
  setc(gc, COL.header)
  gc:fillRect(0, 0, W, hh)
  setc(gc, COL.headerT)
  font(gc, 11, "b")
  gc:drawString(title, u(8), hh / 2, "middle")
  if right then
    font(gc, 8, "r")
    setc(gc, COL.headerS)
    gc:drawString(right, W - u(8) - gc:getStringWidth(right), hh / 2, "middle")
  end
  return hh
end

local function drawFooter(gc, txt)
  local fh = u(16)
  setc(gc, COL.panel)
  gc:fillRect(0, H - fh, W, fh)
  setc(gc, COL.line)
  gc:drawLine(0, H - fh, W, H - fh)
  setc(gc, COL.dim)
  font(gc, 7, "r")
  gc:drawString(clip(gc, txt, W - u(12)), u(6), H - fh / 2, "middle")
  return fh
end

--=========================================================================
-- 7.  Screen: MENU
--=========================================================================
local UNITS = {
  {n = 1, title = "Exploring One-Variable Data",    ready = true },
  {n = 2, title = "Exploring Two-Variable Data",    ready = false},
  {n = 3, title = "Collecting Data",                ready = false},
  {n = 4, title = "Probability & Random Variables", ready = false},
  {n = 5, title = "Sampling Distributions",         ready = false},
  {n = 6, title = "Inference: Proportions",         ready = false},
  {n = 7, title = "Inference: Means",               ready = false},
  {n = 8, title = "Chi-Square Tests",               ready = false},
  {n = 9, title = "Inference: Slopes",              ready = false},
}

local function paintMenu(gc)
  local top = drawHeader(gc, APP, "v" .. VER)
  local fh  = drawFooter(gc, "Up / Down: choose      Enter: open")

  setc(gc, COL.dim)
  font(gc, 7, "r")
  gc:drawString("Choose a unit", u(8), top + u(9), "middle")

  local y0  = top + u(18)
  local ih  = ((H - fh - u(4)) - y0) / #UNITS
  menuRects = {}

  for i, unit in ipairs(UNITS) do
    local y  = y0 + (i - 1) * ih
    local rh = ih - u(1)
    menuRects[i] = {u(6), y, W - u(12), rh}

    if i == menuSel then
      box(gc, u(6), y, W - u(12), rh, COL.selBg, COL.accent)
    end

    local cy = y + rh / 2
    font(gc, 8, "b")
    setc(gc, unit.ready and COL.accent or COL.dim)
    gc:drawString("Unit " .. unit.n, u(11), cy, "middle")
    local badge = gc:getStringWidth("Unit 9") + u(9)

    font(gc, 8, unit.ready and "r" or "i")
    setc(gc, unit.ready and COL.text or COL.dim)
    local label = unit.title
    if not unit.ready then label = label .. "   (coming soon)" end
    gc:drawString(clip(gc, label, W - u(11) - badge - u(10)), u(11) + badge, cy, "middle")
  end
end

--=========================================================================
-- 8.  Screen: HOW MANY DATA POINTS
--=========================================================================
local function paintCount(gc)
  local top = drawHeader(gc, "Unit 1  -  One-Variable Data", "step 1 of 2")
  local fh  = drawFooter(gc, "Enter: continue      Esc: back to menu")

  setc(gc, COL.text)
  font(gc, 10, "b")
  gc:drawString("How many data points?", u(10), top + u(16), "middle")

  setc(gc, COL.dim)
  font(gc, 7, "r")
  gc:drawString("How many values are in your data set (1 - " .. MAXN .. ")?",
                u(10), top + u(30), "middle")

  local bx, by = u(10), top + u(44)
  local bw, bh = W - u(20), u(30)
  box(gc, bx, by, bw, bh, COL.white, COL.accent)

  font(gc, 16, "r")
  setc(gc, COL.text)
  gc:drawString(countBuf, bx + u(8), by + bh / 2, "middle")
  local cx = bx + u(8) + gc:getStringWidth(countBuf) + u(2)
  setc(gc, COL.accent)
  gc:drawLine(cx, by + u(6), cx, by + bh - u(6))

  if err then
    setc(gc, COL.bad)
    font(gc, 7.5, "r")
    gc:drawString(clip(gc, err, W - u(20)), u(10), by + bh + u(11), "middle")
  end
end

--=========================================================================
-- 9.  Screen: DATA ENTRY
--=========================================================================
local function paintEntry(gc)
  local top = drawHeader(gc, "Unit 1  -  Enter Data", idx .. " / " .. nWanted)
  local fh  = drawFooter(gc, "Enter: next    Up/Down: move    del: erase    Esc: back")

  local done = 0
  for i = 1, nWanted do if values[i] ~= nil then done = done + 1 end end

  -- progress bar
  local px, py = u(8), top + u(6)
  local pw, ph = W - u(16), u(5)
  box(gc, px, py, pw, ph, COL.panel, COL.line)
  setc(gc, COL.accent)
  gc:fillRect(px + 1, py + 1, math.max(0, (pw - 2) * done / nWanted), ph - 1)

  -- prompt line
  local promptY = py + ph + u(10)
  setc(gc, COL.text)
  font(gc, 9, "b")
  gc:drawString("Value " .. idx .. " of " .. nWanted, u(8), promptY, "middle")
  setc(gc, COL.dim)
  font(gc, 7, "r")
  local tally = done .. " of " .. nWanted .. " entered"
  gc:drawString(tally, W - u(8) - gc:getStringWidth(tally), promptY, "middle")

  -- input box
  local bx, by = u(8), promptY + u(9)
  local bw, bh = W - u(16), u(26)
  box(gc, bx, by, bw, bh, COL.white, COL.accent)
  font(gc, 14, "r")
  setc(gc, COL.text)
  gc:drawString(buf, bx + u(7), by + bh / 2, "middle")
  local cx = bx + u(7) + gc:getStringWidth(buf) + u(2)
  setc(gc, COL.accent)
  gc:drawLine(cx, by + u(5), cx, by + bh - u(5))
  if buf == "" then
    setc(gc, COL.dim)
    font(gc, 8, "i")
    local ghost = "type a number"
    if values[idx] ~= nil then ghost = "currently " .. fmt(values[idx]) end
    gc:drawString(ghost, cx + u(5), by + bh / 2, "middle")
  end

  -- message line
  local msgY = by + bh + u(7)
  font(gc, 7, "r")
  if err then
    setc(gc, COL.bad)
    gc:drawString(clip(gc, err, W - u(16)), u(8), msgY, "middle")
  else
    setc(gc, COL.dim)
    gc:drawString("(-) key for negatives    .  for decimals", u(8), msgY, "middle")
  end

  -- the values entered so far, in three columns
  local ly = msgY + u(8)
  setc(gc, COL.line)
  gc:drawLine(u(8), ly, W - u(8), ly)
  ly = ly + u(3)

  local listH = (H - fh - u(3)) - ly
  local lh    = u(10.5)
  local rowsV = math.max(1, math.floor(listH / lh))
  local cols  = 3
  local cap   = rowsV * cols
  local page  = math.floor((idx - 1) / cap)
  local start = page * cap + 1
  local colw  = (W - u(16)) / cols

  for k = 0, cap - 1 do
    local i = start + k
    if i > nWanted then break end
    local c = math.floor(k / rowsV)
    local x = u(8) + c * colw
    local y = ly + (k % rowsV) * lh

    if i == idx then
      box(gc, x - u(2), y, colw - u(3), lh, COL.selBg, nil)
      setc(gc, COL.accent)
      font(gc, 7.5, "b")
    elseif values[i] == nil then
      setc(gc, COL.dim)
      font(gc, 7.5, "r")
    else
      setc(gc, COL.text)
      font(gc, 7.5, "r")
    end

    local shown = "_"
    if values[i] ~= nil then shown = fmt(values[i], 5) end
    gc:drawString(clip(gc, i .. ": " .. shown, colw - u(7)), x, y + lh / 2, "middle")
  end

  if nWanted > cap then
    setc(gc, COL.dim)
    font(gc, 7, "i")
    local t = "page " .. (page + 1) .. " of " .. math.ceil(nWanted / cap)
    gc:drawString(t, W - u(8) - gc:getStringWidth(t), H - fh - u(6), "middle")
  end
end

--=========================================================================
-- 10. Screen: RESULTS
--=========================================================================
local function rowHeight(r)
  if r.kind == "head" then return u(17) end
  if r.kind == "note" then return u(12) end
  return u(13)
end

local function resultsViewH(top, fh)
  return (H - fh - u(3)) - (top + u(3))
end

-- the largest number of rows we may skip and still fill the view
local function maxScrollIdx(viewH)
  local h = 0
  for i = #rows, 1, -1 do
    h = h + rowHeight(rows[i])
    if h > viewH then return math.min(i, math.max(0, #rows - 1)) end
  end
  return 0
end

local function paintResults(gc)
  local n   = 0
  if stats then n = stats.n end
  local top = drawHeader(gc, "One-Variable Statistics", "n = " .. n)
  local fh  = drawFooter(gc, "Up/Down: scroll   Esc: edit data   M: menu   R: new set")

  local viewTop = top + u(3)
  local viewH   = resultsViewH(top, fh)
  local x       = u(8)
  local wd      = W - u(16) - u(6)      -- leave room for the scrollbar

  local y = viewTop
  local i = scrollIdx + 1
  while i <= #rows do
    local r  = rows[i]
    local rh = rowHeight(r)
    if y + rh > viewTop + viewH then break end

    if r.kind == "head" then
      setc(gc, COL.panel)
      gc:fillRect(x - u(4), y + u(1), wd + u(8), rh - u(3))
      setc(gc, COL.accent)
      font(gc, 8, "b")
      gc:drawString(r.label, x, y + rh / 2, "middle")

    elseif r.kind == "note" then
      setc(gc, r.color or COL.dim)
      font(gc, 7.5, "i")
      gc:drawString(clip(gc, r.label, wd), x, y + rh / 2, "middle")

    else
      setc(gc, COL.text)
      font(gc, 8.5, "r")
      gc:drawString(r.label, x, y + rh / 2, "middle")
      if r.bar then
        -- the bar of "x-bar", drawn over the leading x
        local cw = gc:getStringWidth(r.label:sub(1, 1))
        local hh = gc:getStringHeight(r.label)
        gc:drawLine(x, y + rh / 2 - hh * 0.33, x + cw, y + rh / 2 - hh * 0.33)
      end
      font(gc, 8.5, "b")
      setc(gc, r.color or COL.text)
      gc:drawString(r.value, x + wd - gc:getStringWidth(r.value), y + rh / 2, "middle")
    end

    y = y + rh
    i = i + 1
  end

  -- scrollbar
  local total = 0
  for k = 1, #rows do total = total + rowHeight(rows[k]) end
  if total > viewH then
    local sbx = W - u(7)
    setc(gc, COL.panel)
    gc:fillRect(sbx, viewTop, u(4), viewH)
    local before = 0
    for k = 1, scrollIdx do before = before + rowHeight(rows[k]) end
    local th = math.max(u(12), viewH * viewH / total)
    local ty = viewTop + (viewH - th) * math.min(1, before / math.max(1, total - viewH))
    setc(gc, COL.accent)
    gc:fillRect(sbx, ty, u(4), th)
  end
end

--=========================================================================
-- 11. Screen transitions
--=========================================================================
local function gotoMenu()
  state = "menu"
  err   = nil
end

local function gotoCount(keepBuffer)
  state = "count"
  if not keepBuffer then countBuf = "" end
  err = nil
end

local function startEntry(n)
  nWanted  = n
  countBuf = tostring(n)
  values   = {}
  idx      = 1
  buf      = ""
  err      = nil
  state    = "entry"
end

-- park whatever is in the edit buffer, quietly
local function stash()
  if buf ~= "" then
    local v = tonumber(buf)
    if v then values[idx] = v end
  end
  buf = ""
end

-- park the edit buffer, complaining if it is unusable
local function commitCurrent()
  if buf == "" then
    if values[idx] ~= nil then return true end
    err = "Type a value first."
    return false
  end
  local v = tonumber(buf)
  if v == nil then
    err = "That is not a valid number."
    return false
  end
  values[idx] = v
  buf = ""
  err = nil
  return true
end

local function firstMissing()
  for i = 1, nWanted do
    if values[i] == nil then return i end
  end
  return nil
end

local function showResults()
  local missing = firstMissing()
  if missing then
    idx = missing
    err = "Value " .. missing .. " is still empty."
    return
  end
  local d = {}
  for i = 1, nWanted do d[i] = values[i] end
  stats     = computeStats(d)
  rows      = buildRows(stats)
  scrollIdx = 0
  state     = "results"
  err       = nil
end

local function moveTo(newIdx)
  stash()
  if newIdx < 1       then newIdx = 1       end
  if newIdx > nWanted then newIdx = nWanted end
  idx = newIdx
  err = nil
end

--=========================================================================
-- 12. Events
--=========================================================================
function on.resize(w, h)
  W, H = w, h
end

function on.paint(gc)
  W = platform.window:width()
  H = platform.window:height()
  setc(gc, COL.bg)
  gc:fillRect(0, 0, W, H)

  if     state == "menu"    then paintMenu(gc)
  elseif state == "count"   then paintCount(gc)
  elseif state == "entry"   then paintEntry(gc)
  elseif state == "results" then paintResults(gc)
  end
end

function on.charIn(ch)
  ch = normalize(ch)

  if state == "menu" then
    local d = tonumber(ch)
    if d and UNITS[d] then menuSel = d end

  elseif state == "count" then
    if ch:match("^%d$") and #countBuf < 3 then
      countBuf = countBuf .. ch
      err = nil
    end

  elseif state == "entry" then
    local before = buf
    buf = acceptChar(buf, ch)
    if buf ~= before then err = nil end

  elseif state == "results" then
    local l = ch:lower()
    if     l == "m" then gotoMenu()
    elseif l == "r" then gotoCount(true)
    elseif l == "e" then state = "entry"
    end
  end

  refresh()
end

function on.enterKey()
  if state == "menu" then
    if UNITS[menuSel].ready then gotoCount(false) end

  elseif state == "count" then
    local n = tonumber(countBuf)
    if n == nil or n ~= math.floor(n) or n < 1 or n > MAXN then
      err = "Enter a whole number from 1 to " .. MAXN .. "."
    else
      startEntry(n)
    end

  elseif state == "entry" then
    if commitCurrent() then
      if idx >= nWanted then
        showResults()
      else
        idx = idx + 1
        buf = ""
      end
    end
  end

  refresh()
end

function on.tabKey()
  if state == "entry" then moveTo(idx + 1) end
  refresh()
end

function on.escapeKey()
  if     state == "results" then state = "entry"
  elseif state == "entry"   then stash(); gotoCount(true)
  elseif state == "count"   then gotoMenu()
  end
  err = nil
  refresh()
end

function on.backspaceKey()
  if state == "count" then
    countBuf = countBuf:sub(1, #countBuf - 1)
    err = nil

  elseif state == "entry" then
    if buf ~= "" then
      buf = buf:sub(1, #buf - 1)
    elseif values[idx] ~= nil then
      values[idx] = nil              -- first del clears the stored value
    elseif idx > 1 then
      idx = idx - 1                  -- then del walks backwards
    end
    err = nil
  end

  refresh()
end

function on.deleteKey() on.backspaceKey() end

function on.clearKey()
  if     state == "count" then countBuf = ""
  elseif state == "entry" then buf = ""
  end
  err = nil
  refresh()
end

function on.arrowUp()
  if state == "menu" then
    menuSel = menuSel - 1
    if menuSel < 1 then menuSel = #UNITS end
  elseif state == "entry" then
    moveTo(idx - 1)
  elseif state == "results" then
    if scrollIdx > 0 then scrollIdx = scrollIdx - 1 end
  end
  refresh()
end

function on.arrowDown()
  if state == "menu" then
    menuSel = menuSel + 1
    if menuSel > #UNITS then menuSel = 1 end
  elseif state == "entry" then
    moveTo(idx + 1)
  elseif state == "results" then
    local top   = u(26)
    local fh    = u(16)
    local limit = maxScrollIdx(resultsViewH(top, fh))
    if scrollIdx < limit then scrollIdx = scrollIdx + 1 end
  end
  refresh()
end

function on.arrowLeft()
  if state == "entry" then moveTo(idx - 1) end
  refresh()
end

function on.arrowRight()
  if state == "entry" then moveTo(idx + 1) end
  refresh()
end

function on.mouseDown(x, y)
  if state == "menu" then
    for i, r in ipairs(menuRects) do
      if x >= r[1] and x <= r[1] + r[3] and y >= r[2] and y <= r[2] + r[4] then
        menuSel = i
        if UNITS[i].ready then gotoCount(false) end
        break
      end
    end
  end
  refresh()
end
