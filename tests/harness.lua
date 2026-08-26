--[[ =========================================================================
     Desktop test harness for src/apstats.lua

     Fakes just enough of the TI-Nspire Lua environment (platform, the
     graphics context, the on.* event table) to load the real script and
     drive it with real keystrokes, then reads back every string it drew.

     Run it with:  python tests/run.py
========================================================================= ]]

local SCRIPT = "src/apstats.lua"

--------------------------------------------------------------------------
-- Fake TI-Nspire environment
--------------------------------------------------------------------------
local drawn = {}

platform = {
  window = {
    width      = function() return 318 end,
    height     = function() return 212 end,
    invalidate = function() end,
  },
}

on = {}

local gc = {size = 10}
function gc:setColorRGB(r, g, b)      end
function gc:setFont(fam, sty, sz)     self.size = sz end
function gc:getStringWidth(s)         return #s * (self.size or 10) * 0.55 end
function gc:getStringHeight(s)        return (self.size or 10) * 1.30 end
function gc:drawString(s, x, y, a)    drawn[#drawn + 1] = s end
function gc:fillRect(x, y, w, h)      end
function gc:drawRect(x, y, w, h)      end
function gc:drawLine(a, b, c, d)      end

--------------------------------------------------------------------------
-- Load the app under test
--------------------------------------------------------------------------
local chunk, loadErr = loadfile(SCRIPT)
if not chunk then
  print("SYNTAX ERROR: " .. tostring(loadErr))
  os.exit(1)
end
chunk()

--------------------------------------------------------------------------
-- Driving helpers
--------------------------------------------------------------------------
local MINUS_U = "\226\136\146"   -- what the handheld (-) key actually sends

local function paint()
  drawn = {}
  on.paint(gc)
  return drawn
end

local function typeText(s)
  local i = 1
  while i <= #s do
    local ch = s:sub(i, i)
    if ch == "~" then ch = MINUS_U end   -- "~" in a test string means the (-) key
    on.charIn(ch)
    i = i + 1
  end
end

-- The results list scrolls, so one paint only shows part of it.  Rewind to
-- the top and collect every string drawn on the way down.
local function fullResults()
  for i = 1, 60 do on.arrowUp() end
  local all = {}
  for step = 0, 60 do
    for _, s in ipairs(paint()) do all[#all + 1] = s end
    on.arrowDown()
  end
  return all
end

local function has(t, needle)
  for _, s in ipairs(t) do
    if s:find(needle, 1, true) then return true end
  end
  return false
end

--------------------------------------------------------------------------
-- Assertions
--------------------------------------------------------------------------
local pass, fail = 0, 0

local function check(name, cond, extra)
  if cond then
    pass = pass + 1
    print("  ok   " .. name)
  else
    fail = fail + 1
    print("  FAIL " .. name .. (extra and ("   <- " .. tostring(extra)) or ""))
  end
end

local function checkStat(lines, label, want)
  -- a stat row draws its label then its value, back to back; the label can
  -- appear on several scroll positions so accept any matching pair
  local seen, found = {}, false
  for i = 1, #lines - 1 do
    if lines[i] == label then
      found = true
      if lines[i + 1] == want then
        pass = pass + 1
        print("  ok   " .. label .. " = " .. want)
        return
      end
      seen[#seen + 1] = lines[i + 1]
    end
  end
  fail = fail + 1
  if found then
    print("  FAIL " .. label .. " = " .. want .. "   <- got " .. table.concat(seen, " / "))
  else
    print("  FAIL " .. label .. " -- label never drawn")
  end
end

--------------------------------------------------------------------------
-- Walk the whole app: menu -> count -> entry -> results
--------------------------------------------------------------------------
local function runDataSet(data, howToType)
  on.escapeKey(); on.escapeKey(); on.escapeKey()   -- back to the menu
  local menu = paint()
  check("menu lists Unit 1", has(menu, "Exploring One-Variable Data"))
  check("menu greys out Unit 9", has(menu, "coming soon"))

  on.enterKey()                                    -- open Unit 1
  check("count screen asks for n", has(paint(), "How many data points?"))

  typeText(tostring(#data))
  on.enterKey()                                    -- start entering values
  check("entry screen starts at value 1", has(paint(), "Value 1 of " .. #data))

  for i = 1, #data do
    typeText(howToType[i])
    on.enterKey()
  end
  return fullResults()
end

print("")
print("=== Data set A: 2 4 4 4 5 5 7 9 ===")
local A     = {2, 4, 4, 4, 5, 5, 7, 9}
local Atype = {"2", "4", "4", "4", "5", "5", "7", "9"}
local out   = runDataSet(A, Atype)

check("auto-jumped to results", has(out, "One-Variable Statistics"))
checkStat(out, "n", "8")
checkStat(out, "x    (mean)", "5")
checkStat(out, "\206\163x", "40")
checkStat(out, "\206\163x\194\178", "232")
checkStat(out, "SSx  (sum of sq. dev.)", "32")
checkStat(out, "\207\131x   (population SD)", "2")
checkStat(out, "sx   (sample SD)", "2.13809")
checkStat(out, "MinX", "2")
checkStat(out, "Q1", "4")
checkStat(out, "Median", "4.5")
checkStat(out, "Q3", "6")
checkStat(out, "MaxX", "9")
checkStat(out, "Range  (max - min)", "7")
checkStat(out, "IQR    (Q3 - Q1)", "2")
checkStat(out, "Mode", "4  (x3)")
checkStat(out, "Lower fence  Q1 - 1.5*IQR", "1")
checkStat(out, "Upper fence  Q3 + 1.5*IQR", "9")
check("no outliers reported", has(out, "none"))
check("shape called right-skewed", has(out, "skewed RIGHT"))

-- scrolling must reach the bottom of the read-out
for i = 1, 40 do on.arrowDown() end
check("can scroll to the Shape section", has(paint(), "Shape"))
for i = 1, 60 do on.arrowUp() end
check("can scroll back to the top", has(paint(), "Summary"))

print("")
print("=== Data set B: negatives, decimals, an outlier ===")
-- sorted: -2.5  1  1  1.5  2  2  2.5  3  40
-- Q1 = 1, Q3 = 2.75, IQR = 1.75  ->  fences at -1.625 and 5.375
local B     = {-2.5, 1, 1, 1.5, 2, 2, 2.5, 3, 40}
local Btype = {"~2.5", "1", "1", "1.5", "2", "2", "2.5", "3", "40"}
local out2  = runDataSet(B, Btype)

checkStat(out2, "n", "9")
checkStat(out2, "MinX", "-2.5")
checkStat(out2, "MaxX", "40")
checkStat(out2, "Median", "2")
checkStat(out2, "Q1", "1")
checkStat(out2, "Q3", "2.75")
checkStat(out2, "IQR    (Q3 - Q1)", "1.75")
checkStat(out2, "Range  (max - min)", "42.5")
checkStat(out2, "Lower fence  Q1 - 1.5*IQR", "-1.625")
checkStat(out2, "Upper fence  Q3 + 1.5*IQR", "5.375")
checkStat(out2, "Mode", "1, 2  (x2)")     -- two-way tie
check("both outliers listed", has(out2, "-2.5, 40"))
check("shape called right-skewed", has(out2, "skewed RIGHT"))

print("")
print("=== Editing an already-entered value ===")
on.escapeKey()                                     -- results -> entry
for i = 1, 8 do on.arrowUp() end                   -- walk back to value 1
check("landed on value 1", has(paint(), "Value 1 of 9"))
on.backspaceKey()                                  -- clear the stored value
check("cleared value shows the placeholder", has(paint(), "type a number"))
typeText("7")                                      -- -2.5 becomes 7
on.enterKey()
for i = 1, 7 do on.arrowDown() end                 -- back to the last value
on.enterKey()                                      -- last value -> results
local out3 = fullResults()
checkStat(out3, "n", "9")
checkStat(out3, "MinX", "1")                       -- -2.5 is gone
checkStat(out3, "MaxX", "40")

print("")
print("=== Edge cases ===")
on.escapeKey(); on.escapeKey(); on.escapeKey()
on.enterKey()
typeText("0"); on.enterKey()
check("rejects n = 0", has(paint(), "whole number from 1"))
on.clearKey()
typeText("1"); on.enterKey()
typeText("42"); on.enterKey()
local out4 = fullResults()
checkStat(out4, "n", "1")
checkStat(out4, "x    (mean)", "42")
checkStat(out4, "sx   (sample SD)", "undef")     -- undefined for n = 1
checkStat(out4, "\207\131x   (population SD)", "0")
checkStat(out4, "Q1", "42")
check("n=1 shape note", has(out4, "only one value"))

on.escapeKey(); on.escapeKey(); on.escapeKey()
on.enterKey()
typeText("999"); on.enterKey()
check("rejects n above the cap", has(paint(), "whole number from 1"))

print("")
print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
