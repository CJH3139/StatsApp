--[[ =========================================================================
     TI-Nspire API shim for the browser simulator.

     This is loaded BEFORE src/apstats.lua and provides the globals the
     handheld normally supplies: `platform`, the `on` event table, and a
     graphics context whose methods forward to the host canvas.

     Everything the app is allowed to touch is defined here, so if the app
     ever calls something the real calculator has but this file doesn't,
     it fails loudly in the simulator instead of silently on the device.
========================================================================= ]]

local _w, _h = 318, 212

--------------------------------------------------------------------------
-- platform
--------------------------------------------------------------------------
platform = {
  apilevel = nil,        -- the app assigns this itself
  window = {
    width      = function() return _w end,
    height     = function() return _h end,
    invalidate = function() js_invalidate() end,
  },
  hw       = function() return 4 end,   -- pretend to be a CX
  isColorDisplay = function() return true end,
  isDeviceModeRestricted = function() return false end,
}

--------------------------------------------------------------------------
-- event table
--------------------------------------------------------------------------
on = {}

--------------------------------------------------------------------------
-- graphics context
--------------------------------------------------------------------------
local gc = {}

function gc:setColorRGB(r, g, b)
  if g == nil then                       -- single 0xRRGGBB argument form
    local v = r
    js_setColor(math.floor(v / 65536) % 256, math.floor(v / 256) % 256, v % 256)
  else
    js_setColor(r, g, b)
  end
end

function gc:setFont(family, style, size) js_setFont(family, style, size) end
function gc:setPen(thickness, style)     js_setPen(thickness or "thin", style or "smooth") end

function gc:drawString(s, x, y, anchor)  js_drawString(s, x, y, anchor or "baseline") end
function gc:getStringWidth(s)            return js_getStringWidth(s) end
function gc:getStringHeight(s)           return js_getStringHeight(s) end

function gc:fillRect(x, y, w, h)         js_fillRect(x, y, w, h) end
function gc:drawRect(x, y, w, h)         js_drawRect(x, y, w, h) end
function gc:drawLine(x1, y1, x2, y2)     js_drawLine(x1, y1, x2, y2) end

function gc:clipRect(mode, x, y, w, h)   js_clipRect(mode, x or 0, y or 0, w or 0, h or 0) end

-- Not implemented -- present so a future unit that uses them fails with a
-- clear message here rather than behaving differently on the handheld.
local function unsupported(name)
  return function() error("gc:" .. name .. "() is not implemented in the simulator", 2) end
end
gc.drawArc      = unsupported("drawArc")
gc.fillArc      = unsupported("fillArc")
gc.drawPolyLine = unsupported("drawPolyLine")
gc.fillPolygon  = unsupported("fillPolygon")
gc.drawImage    = unsupported("drawImage")

--------------------------------------------------------------------------
-- timer / cursor / toolpalette  (stubs backed by the host where useful)
--------------------------------------------------------------------------
timer = {
  start = function(seconds) js_timerStart(seconds) end,
  stop  = function()        js_timerStop()         end,
  getMilliSecCounter = function() return js_millis() end,
}

cursor = { set = function(kind) js_setCursor(kind) end }

toolpalette = { register = function() end }

var = {
  store  = function() return false end,
  recall = function() return nil end,
  monitor = function() end,
}

document = { markChanged = function() end }

--------------------------------------------------------------------------
-- Entry points the host calls
--------------------------------------------------------------------------
function __paint()
  if on.paint then on.paint(gc) end
end

function __resize(w, h)
  _w, _h = w, h
  if on.resize then on.resize(w, h) end
end

-- Dispatch a named on.* handler.  Returns true if the app actually has one,
-- so the host can tell "key ignored" from "key not wired up".
function __event(name, a, b)
  local fn = on[name]
  if type(fn) ~= "function" then return false end
  fn(a, b)
  return true
end

-- Names the simulator's keypad is allowed to send.
__EVENTS = {
  "charIn", "enterKey", "escapeKey", "backspaceKey", "deleteKey", "clearKey",
  "tabKey", "backtabKey", "arrowUp", "arrowDown", "arrowLeft", "arrowRight",
  "mouseDown", "mouseUp", "timer", "contextMenu", "help",
}
