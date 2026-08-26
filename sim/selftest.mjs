/*
 * Headless check that nspire-shim.lua + src/apstats.lua actually run under
 * wasmoon -- the same Lua build the browser simulator uses.
 *
 * This exercises the exact shim the page loads, with a stub canvas standing
 * in for the real one, so a pass here means the browser only has rendering
 * left to get wrong.
 *
 *   node sim/selftest.mjs
 */

import { createRequire } from 'module'
import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

const require = createRequire(import.meta.url)
const { LuaFactory } = require('./vendor/wasmoon.js')

const here = dirname(fileURLToPath(import.meta.url))
const root = join(here, '..')

const drawn = []
let fontSize = 10
let fontStyle = 'r'

// crude but consistent text metrics -- good enough to drive layout code
const measure = (s) => [...s].length * fontSize * 0.55

const factory = new LuaFactory(join(here, 'vendor', 'glue.wasm'))
const lua = await factory.createEngine()

lua.global.set('js_setColor', () => {})
lua.global.set('js_setPen', () => {})
lua.global.set('js_setFont', (fam, sty, sz) => { fontStyle = sty; fontSize = sz })
lua.global.set('js_drawString', (s, x, y) => { drawn.push({ s, x, y }) })
lua.global.set('js_getStringWidth', (s) => measure(s))
lua.global.set('js_getStringHeight', () => fontSize * 1.3)
lua.global.set('js_fillRect', () => {})
lua.global.set('js_drawRect', () => {})
lua.global.set('js_drawLine', () => {})
lua.global.set('js_clipRect', () => {})
lua.global.set('js_invalidate', () => {})
lua.global.set('js_timerStart', () => {})
lua.global.set('js_timerStop', () => {})
lua.global.set('js_millis', () => 0)
lua.global.set('js_setCursor', () => {})

lua.doStringSync(readFileSync(join(here, 'nspire-shim.lua'), 'utf8'))
lua.doStringSync(readFileSync(join(root, 'src', 'apstats.lua'), 'utf8'))

const paint = lua.global.get('__paint')
const event = lua.global.get('__event')

const frame = () => { drawn.length = 0; paint(); return drawn.map((d) => d.s) }
const type = (s) => { for (const ch of s) event('charIn', ch === '~' ? '−' : ch) }

// the whole read-out only exists across several scroll positions
const scrollAll = () => {
    for (let i = 0; i < 60; i++) event('arrowUp')
    const all = []
    for (let i = 0; i < 60; i++) { all.push(...frame()); event('arrowDown') }
    return all
}

let pass = 0
let fail = 0
const check = (name, cond, extra) => {
    if (cond) { pass++; console.log('  ok   ' + name) }
    else { fail++; console.log('  FAIL ' + name + (extra ? '   <- ' + extra : '')) }
}
const stat = (lines, label, want) => {
    const hits = []
    for (let i = 0; i < lines.length - 1; i++) {
        if (lines[i] === label) {
            if (lines[i + 1] === want) { pass++; console.log(`  ok   ${label} = ${want}`); return }
            hits.push(lines[i + 1])
        }
    }
    fail++
    console.log(`  FAIL ${label} = ${want}   <- ${hits.length ? 'got ' + hits.join(' / ') : 'label never drawn'}`)
}

console.log('\n=== shim boots and paints the menu ===')
check('menu renders', frame().some((s) => s.includes('Exploring One-Variable Data')))

console.log('\n=== full walkthrough: 2 4 4 4 5 5 7 9 ===')
event('enterKey')
check('count screen', frame().some((s) => s.includes('How many data points?')))
type('8'); event('enterKey')
check('entry screen', frame().some((s) => s.includes('Value 1 of 8')))
for (const v of ['2', '4', '4', '4', '5', '5', '7', '9']) { type(v); event('enterKey') }

const out = scrollAll()
check('reached results', out.some((s) => s.includes('One-Variable Statistics')))
stat(out, 'n', '8')
stat(out, 'x    (mean)', '5')
stat(out, 'Σx', '40')
stat(out, 'Σx²', '232')
stat(out, 'sx   (sample SD)', '2.13809')
stat(out, 'σx   (population SD)', '2')
stat(out, 'MinX', '2')
stat(out, 'Q1', '4')
stat(out, 'Median', '4.5')
stat(out, 'Q3', '6')
stat(out, 'MaxX', '9')
stat(out, 'IQR    (Q3 - Q1)', '2')
stat(out, 'Mode', '4  (x3)')
check('shape called', out.some((s) => s.includes('skewed RIGHT')))

console.log('\n=== the (-) key really produces a negative ===')
for (let i = 0; i < 4; i++) event('escapeKey')
event('enterKey'); type('2'); event('enterKey')
type('~5'); event('enterKey')
type('5'); event('enterKey')
const neg = scrollAll()
stat(neg, 'MinX', '-5')
stat(neg, 'x    (mean)', '0')

console.log('\n=== unicode survives the Lua -> JS string bridge ===')
check('sigma decoded as one char', neg.some((s) => s === 'Σx'))
check('superscript two decoded', neg.some((s) => s === 'Σx²'))

console.log(`\n${pass} passed, ${fail} failed`)
lua.global.close()
process.exit(fail > 0 ? 1 : 0)
