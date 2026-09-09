import { chromium } from 'playwright';
import fs from 'node:fs/promises';

const base = process.env.WORLD_URL || 'http://127.0.0.1:8765/index.html';
const browser = await chromium.launch({
  headless: true,
  args: ['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist','--disable-dev-shm-usage']
});
const context = await browser.newContext({
  viewport: { width: 1440, height: 900 },
  deviceScaleFactor: 1,
  geolocation: { longitude: -72.6506, latitude: 41.5623 },
  permissions: ['geolocation']
});
const page = await context.newPage();
const pageErrors = [];
page.on('pageerror', e => pageErrors.push(String(e)));

await page.goto(base, { waitUntil: 'domcontentloaded', timeout: 45000 });
await page.waitForFunction(() => window.BridgePointWorldV2500?.version === 2500, null, { timeout: 45000 });
await page.waitForFunction(() => window.BridgePointWorldV2501?.version === 2501, null, { timeout: 45000 });
await page.waitForTimeout(4500);

const report = await page.evaluate(() => {
  const core = window.BridgePointWorldV2500;
  const intel = window.BridgePointWorldV2501;
  const status = document.getElementById('status')?.textContent || '';
  const canvas = document.querySelector('#cesiumContainer canvas');
  const gl = canvas?.getContext('webgl2') || canvas?.getContext('webgl');
  const visibleCanvases = [...document.querySelectorAll('canvas')].filter(c => {
    const s=getComputedStyle(c), r=c.getBoundingClientRect();
    return s.display!=='none' && s.visibility!=='hidden' && r.width>0 && r.height>0;
  });
  return {
    coreVersion: core?.version,
    intelVersion: intel?.version,
    status,
    hasWebGL: !!gl,
    visibleCanvasCount: visibleCanvases.length,
    opportunityLayerButton: !!document.getElementById('bpOpportunityLayerButton'),
    opportunityLayerActive: document.getElementById('bpOpportunityLayerButton')?.classList.contains('active') || false,
    systemPulse: !!document.getElementById('bpSystemPulse'),
    systemPulseText: document.getElementById('bpSystemPulse')?.innerText || '',
    layerPanel: !!document.getElementById('layerPanel'),
    propertyCard: !!document.getElementById('propertyCard'),
    studyLab: !!document.getElementById('studyLab'),
    radarActive: document.getElementById('radarButton')?.classList.contains('active') || false,
    circlesActive: document.getElementById('propertyCirclesButton')?.classList.contains('active') || false,
    fxActive: document.getElementById('fxButton')?.classList.contains('active') || false,
    oldControls: !!document.querySelector('nav#controls')
  };
});

const failures = [];
if (report.coreVersion !== 2500) failures.push('Core World API is not V2500');
if (report.intelVersion !== 2501) failures.push('Intelligence overlay API is not V2501');
if (!report.hasWebGL) failures.push('WebGL context unavailable');
if (report.visibleCanvasCount !== 1) failures.push(`Expected one visible primary canvas at boot, saw ${report.visibleCanvasCount}`);
if (!report.opportunityLayerButton || !report.opportunityLayerActive) failures.push('Verified opportunities layer control missing/inactive');
if (!report.systemPulse) failures.push('Live BridgePoint system pulse missing');
if (!/bridgepoint/i.test(report.systemPulseText)) failures.push('System pulse did not initialize');
if (!report.layerPanel || !report.propertyCard || !report.studyLab) failures.push('Required map panels missing');
if (!report.radarActive) failures.push('Radar did not remain active');
if (report.circlesActive) failures.push('Property circles incorrectly started active');
if (report.fxActive) failures.push('Close-up physical FX incorrectly started active');
if (report.oldControls) failures.push('Legacy map controls returned');
if (/failed to start/i.test(report.status)) failures.push(`Startup status reports failure: ${report.status}`);
if (pageErrors.length) failures.push(`Unhandled page errors: ${pageErrors.join(' | ')}`);

await fs.mkdir('artifacts', { recursive: true });
await page.screenshot({ path: 'artifacts/world-v2501-browser-smoke.png', fullPage: true });
await fs.writeFile('artifacts/world-v2501-browser-smoke.json', JSON.stringify({ report, pageErrors, failures }, null, 2));
console.log(JSON.stringify({ report, pageErrors, failures }, null, 2));
await browser.close();
if (failures.length) process.exit(1);
