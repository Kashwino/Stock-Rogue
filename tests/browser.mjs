import { chromium } from 'playwright';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import assert from 'node:assert/strict';

const root = resolve('build/web');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json' };
const server = createServer(async (req, res) => {
  const path = resolve(root, '.' + decodeURIComponent(new URL(req.url, 'http://localhost').pathname).replace(/\/$/, '/index.html'));
  if (!path.startsWith(root + sep)) { res.writeHead(403).end(); return; }
  try { res.setHeader('Content-Type', mime[extname(path)] || 'application/octet-stream'); res.end(await readFile(path)); }
  catch { res.writeHead(404).end(); }
});
await new Promise(r => server.listen(8123, '127.0.0.1', r));
await mkdir('artifacts', { recursive: true });
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const context = await browser.newContext({ viewport: { width: 844, height: 390 }, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
const page = await context.newPage();
const errors = [];
page.on('pageerror', e => errors.push(String(e)));
page.on('console', m => { console.log('ENGINE', m.text()); if (/SCRIPT ERROR|ERROR:/.test(m.text())) errors.push(m.text()); });
const state = () => page.evaluate(() => window.stockRogueQA);
const wait = (fn, arg) => page.waitForFunction(fn, arg, { timeout: 120000 });
async function point(x, y) {
  const s = await state();
  const r = await page.locator('#canvas').boundingBox();
  return { x: r.x + x * r.width / s.viewport[0], y: r.y + y * r.height / s.viewport[1] };
}
async function tap(text) {
  await wait(t => window.stockRogueQA?.controls.some(c => c.text === t) && !window.stockRogueQA.transition, text);
  const s = await state();
  const c = s.controls.find(c => c.text === text);
  const p = await point(c.rect[0] + c.rect[2] / 2, c.rect[1] + c.rect[3] / 2);
  await page.touchscreen.tap(p.x, p.y);
  await page.waitForTimeout(250);
}
async function tapCard() {
  await wait(() => !window.stockRogueQA?.transition);
  const s = await state();
  const c = s.controls.find(c => c.type === 'Button' && c.text === '');
  assert(c, 'selectable card is visible');
  const p = await point(c.rect[0] + c.rect[2] / 2, c.rect[1] + c.rect[3] / 2);
  await page.touchscreen.tap(p.x, p.y);
  await page.waitForTimeout(350);
}
async function shot(name) { const bytes = await page.screenshot({ path: 'artifacts/' + name + '.png' }); if (name === 'phone-infiltration' || name === 'failure') console.log('SCREENSHOT ' + name + ' ' + bytes.toString('base64')); }
async function slider(index, fraction) {
  const s = await state();
  const c = s.controls.filter(c => c.type === 'HSlider')[index];
  assert(c, 'volume slider exists');
  const p = await point(c.rect[0] + c.rect[2] * fraction, c.rect[1] + c.rect[3] / 2);
  await page.touchscreen.tap(p.x, p.y);
  await page.waitForTimeout(300);
}
try {
  await page.goto('http://127.0.0.1:8123/?qa=1');
  await wait(() => window.stockRogueQA?.scene.endsWith('home_screen.tscn'));
  await shot('phone-menu');
  await tap('SETTINGS');
  await slider(0, 0.37);
  await slider(1, 0.62);
  await tap('Low effects');
  let saved = (await state()).settings;
  assert(saved.low_effects);
  assert(saved.master > 0.25 && saved.master < 0.48, 'master changed by touch');
  assert(saved.sfx > 0.50 && saved.sfx < 0.72, 'effects changed by touch');
  await shot('phone-settings');
  await page.reload();
  await wait(() => window.stockRogueQA?.scene.endsWith('home_screen.tscn'));
  assert.deepEqual((await state()).settings, saved, 'audio/video settings survive browser reload');
  assert(Math.abs((await state()).master_db - 20 * Math.log10(saved.master)) < 0.02, 'saved volume applied to audio bus');
  // Seed earned currency only in this isolated test browser; purchases use real UI.
  await page.evaluate(() => localStorage.setItem('stock-rogue-career-v1', JSON.stringify({intel: 30, unlocked_assets: [], extraction_receipts: {'browser-fixture':30}})));
  await page.reload();
  await wait(() => window.stockRogueQA?.scene.endsWith('home_screen.tscn'));
  await tap('CONNECTIONS');
  await tap('BUY Circuit Thief · 12');
  await tap('BUY Fast Hands · 8');
  await tap('EQUIP Fast Hands');
  assert.equal((await state()).clout, 10, 'career purchases deduct Clout through touch UI');
  await shot('phone-network');
  await page.reload();
  await wait(() => window.stockRogueQA?.scene.endsWith('home_screen.tscn'));
  assert.equal((await state()).starting_perk, 'fast_hands', 'equipped starting perk survives reload');
  assert((await state()).unlocks.includes('circuit_smg'), 'weapon unlock survives reload');
  await tap('QUICK HEIST');
  await wait(() => window.stockRogueQA?.scene.endsWith('heist_floor.tscn') && window.stockRogueQA.touch_visible);
  await page.waitForTimeout(500);
  await shot('phone-heist');
  let s = await state();
  assert(s.perks.includes('fast_hands'), 'purchased starting perk applies to a new run');
  assert.equal(s.modifier, 'insider');
  assert(s.map_revealed && s.security_count >= 8, 'Insider reveals layout and security devices exist');
  await tap('MAP');
  await wait(() => window.stockRogueQA?.map_visible && window.stockRogueQA?.paused);
  assert((await state()).map_visible && (await state()).paused, 'tactical map opens and pauses by touch');
  await shot('phone-insider-map');
  await tap('MAP');
  assert(s.active_enemies < s.all_enemies, 'distance sleeping is active');
  const before = [...s.position], shotsBefore = s.shots;
  const cd = await context.newCDPSession(page);
  const l = await point(...s.left), r = await point(...s.right);
  const toward = [s.entrance[0] - s.position[0], s.entrance[1] - s.position[1]];
  const length = Math.hypot(...toward);
  const move = { x: l.x + toward[0] / length * 30, y: l.y + toward[1] / length * 30 };
  // Move diagonally away from the car while aiming/firing: two independent fingers.
  await cd.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...l }, { id: 2, ...r }] });
  await cd.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, ...move }, { id: 2, x: r.x, y: r.y - 30 }] });
  await page.waitForTimeout(1400);
  s = await state();
  assert(Math.hypot(s.position[0] - before[0], s.position[1] - before[1]) > 50, 'left touch moves player');
  assert(s.shots > shotsBefore, 'right touch fires while left moves');
  assert(s.entered && s.elapsed > 0.0, 'touch movement enters the building and starts the heist');
  await shot('phone-infiltration');
  await cd.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await page.waitForTimeout(300);
  s = await state();
  assert(!s.firing && s.move.every(v => v === 0), 'finger release clears both sticks');
  // Walk to the lobby terminal using the movement stick, then open a real short.
  for (let attempt = 0; attempt < 20; attempt++) {
    s = await state();
    const dx = s.terminal_position[0] - s.position[0], dy = s.terminal_position[1] - s.position[1];
    const distance = Math.hypot(dx, dy);
    if (distance < 85) break;
    const stick = await point(...s.left);
    await cd.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...stick }] });
    await cd.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, x: stick.x + dx / distance * 30, y: stick.y + dy / distance * 30 }] });
    await page.waitForTimeout(250);
    await cd.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await page.waitForTimeout(150);
  }
  await tap('USE');
  await wait(() => window.stockRogueQA?.controls.some(c => c.text.startsWith('SHORT THIS HEIST')));
  const shortButton = (await state()).controls.find(c => c.text.startsWith('SHORT THIS HEIST')).text;
  await tap(shortButton);
  assert.equal((await state()).short.payout, 75, 'opening a short only reserves collateral');
  await shot('phone-short-contract');
  await tap('BACK TO HEIST');
  await tap('PAUSE');
  assert((await state()).paused, 'pause button works with touch');
  const paused = await state();
  await page.waitForTimeout(750);
  s = await state();
  assert.equal(s.elapsed, paused.elapsed, 'browser pause freezes clock');
  assert.equal(s.heat, paused.heat, 'browser pause freezes heat');
  assert.deepEqual(s.position, paused.position, 'browser pause freezes movement');
  await shot('phone-paused');
  await tap('SETTINGS');
  await slider(0, 0.45);
  await tap('BACK');
  await tap('RESUME');
  assert(!(await state()).paused, 'resume works');
  await tap('PAUSE');
  await tap('MENU - LAST CHECKPOINT');
  await wait(() => window.stockRogueQA?.scene.endsWith('home_screen.tscn'));
  await tap('PLAY');
  await wait(() => window.stockRogueQA?.scene.endsWith('character_select.tscn'));
  await shot('phone-case-files');
  await tapCard();
  await page.waitForTimeout(400);
  await shot('phone-crew-select');
  await tapCard();
  await wait(() => window.stockRogueQA?.scene.endsWith('map_ui_screen.tscn'));
  s = await state();
  assert.equal(s.route_stage, 0);
  assert.equal(s.route_step, 0, 'a new run opens on the first hideout step');
  assert.equal(s.profile, 'operator', 'the Operator is hired from the crew cards');
  await shot('phone-case-wall');
  await tap('ENTER HIDEOUT');
  await wait(() => window.stockRogueQA?.scene.endsWith('hideout_room.tscn') && window.stockRogueQA.touch_visible);
  await shot('phone-hideout');
  s = await state();
  const hideoutStart = [...s.position];
  const hubStick = await point(...s.left);
  await cd.send('Input.dispatchTouchEvent', {type: 'touchStart', touchPoints: [{id: 1, ...hubStick}]});
  await cd.send('Input.dispatchTouchEvent', {type: 'touchMove', touchPoints: [{id: 1, x: hubStick.x, y: hubStick.y - 30}]});
  await page.waitForTimeout(650);
  await cd.send('Input.dispatchTouchEvent', {type: 'touchEnd', touchPoints: []});
  await page.waitForTimeout(250);
  assert((await state()).position[1] < hideoutStart[1] - 40, 'touch walks the hideout');
  await tap('TO THE JOB BOARD');
  await wait(() => window.stockRogueQA?.scene.endsWith('map_ui_screen.tscn'));
  assert.equal((await state()).route_step, 1, 'leaving the hideout reveals the heist choice');
  await shot('phone-contracts');
  await tap('HEIST OPTION 1');
  await wait(() => window.stockRogueQA?.scene.endsWith('heist_floor.tscn'));
  assert.equal((await state()).profile, 'operator', 'selected character enters heist');
  await tap('PAUSE');
  await tap('MENU - LAST CHECKPOINT');
  await wait(() => window.stockRogueQA?.scene.endsWith('home_screen.tscn'));
  await page.reload();
  await wait(() => window.stockRogueQA?.scene.endsWith('home_screen.tscn'));
  await tap('PLAY');
  await wait(() => window.stockRogueQA?.scene.endsWith('character_select.tscn'));
  await tapCard();
  await wait(() => window.stockRogueQA?.scene.endsWith('map_ui_screen.tscn'));
  assert.equal((await state()).profile, 'operator', 'save file resumes with the same character');
  assert.equal((await state()).route_step, 1, 'resume does not advance unfinished heist');
  assert.deepEqual(errors, [], 'no browser runtime errors');
  await writeFile('artifacts/browser-report.json', JSON.stringify({ passed: true, settings: saved, tests: ['mobile menu', 'touch settings', 'reload persistence', 'audio application', 'career purchases and reload persistence', 'starting perk applies', 'Insider tactical map', 'visible security devices', 'short contract opened by touch', 'distance sleeping', 'simultaneous movement and firing', 'touch release', 'pause heat/time/movement', 'resume', 'case-file screen', 'crew selection', 'walkable hideout', 'case wall', 'map selection', 'normal heist launch', 'compressed engine loading'] }, null, 2));
  assert.deepEqual(errors, [], 'no browser runtime errors');
  console.log('BROWSER TEST SUITE COMPLETE');
} catch (e) {
  await shot('failure');
  console.log('BROWSER STATE', JSON.stringify(await state()));
  console.log('BROWSER ERRORS', JSON.stringify(errors));
  throw e;
} finally {
  await browser.close();
  server.close();
}
