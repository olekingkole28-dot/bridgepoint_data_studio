let threePromise;

const esc = (v) => String(v ?? '').replace(/[&<>'"]/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
const num = (v) => Number.isFinite(Number(v)) ? Number(v) : null;

async function loadThree() {
  if (!threePromise) {
    threePromise = Promise.all([
      import('https://cdn.jsdelivr.net/npm/three@0.180.0/build/three.module.js'),
      import('https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/controls/OrbitControls.js'),
    ]).then(([THREE, controls]) => ({ THREE, OrbitControls: controls.OrbitControls }));
  }
  return threePromise;
}

function outerRings(geometry) {
  if (!geometry) return [];
  if (geometry.type === 'Polygon') return geometry.coordinates?.[0] ? [geometry.coordinates[0]] : [];
  if (geometry.type === 'MultiPolygon') return (geometry.coordinates || []).map((p) => p?.[0]).filter(Boolean);
  return [];
}

function detailBuilding(detail = {}) {
  return detail.building || detail.structure || detail;
}

function detailProperty(detail = {}) {
  return detail.property || detail.property_detail || {};
}

function geometryFromDetail(detail = {}) {
  const b = detailBuilding(detail);
  return b.geometry || b.geometry_geojson || b.footprint_geometry || detail.building_geometry || detail.footprint || null;
}

function parcelGeometry(detail = {}) {
  const p = detailProperty(detail);
  return detail.parcel_geometry || p.parcel_geometry || p.geometry || detail.property_geometry || null;
}

function heightTruth(detail = {}) {
  const b = detailBuilding(detail);
  const source = num(b.height_m ?? b.source_height_m ?? detail.height_m);
  const render = num(b.render_height_m ?? detail.render_height_m ?? source);
  return {
    height: Math.max(1, source ?? render ?? 8.5),
    sourceBacked: source !== null && source > 0,
    label: source !== null && source > 0 ? 'source height' : 'visual estimate',
  };
}

function localProjector(rings) {
  const pts = rings.flat();
  if (!pts.length) return null;
  const lon0 = pts.reduce((s, p) => s + Number(p[0]), 0) / pts.length;
  const lat0 = pts.reduce((s, p) => s + Number(p[1]), 0) / pts.length;
  const mx = 111320 * Math.max(.12, Math.cos(lat0 * Math.PI / 180));
  const my = 110540;
  return {
    lon0, lat0,
    point: (p) => ({ x: (Number(p[0]) - lon0) * mx, y: (Number(p[1]) - lat0) * my }),
  };
}

function shapeFromRing(THREE, ring, project) {
  const shape = new THREE.Shape();
  let started = false;
  for (const p of ring || []) {
    if (!Array.isArray(p) || p.length < 2) continue;
    const q = project(p);
    if (!started) { shape.moveTo(q.x, q.y); started = true; }
    else shape.lineTo(q.x, q.y);
  }
  return started ? shape : null;
}

function addParcel(THREE, scene, geometry, projector) {
  const rings = outerRings(geometry);
  const points = [];
  for (const ring of rings) {
    for (const p of ring) {
      const q = projector.point(p);
      points.push(new THREE.Vector3(q.x, q.y, .04));
    }
    if (points.length > 1) {
      const g = new THREE.BufferGeometry().setFromPoints(points.splice(0));
      scene.add(new THREE.Line(g, new THREE.LineBasicMaterial({ color: 0x48e1ff, transparent: true, opacity: .92 })));
    }
  }
}

function addRoofCue(THREE, scene, shapes, h, detail) {
  const b = detailBuilding(detail);
  const roof = String(b.roof_shape ?? b.roof_type ?? detail.roof_shape ?? '').toLowerCase();
  if (!roof || !shapes.length) return;
  const color = 0xd7e3e9;
  for (const s of shapes) {
    const geo = new THREE.ShapeGeometry(s);
    const mesh = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ color, transparent: true, opacity: .68, side: THREE.DoubleSide }));
    mesh.position.z = h + .02;
    scene.add(mesh);
  }
}

function factRows(detail) {
  const b = detailBuilding(detail), p = detailProperty(detail), ht = heightTruth(detail);
  const rows = [
    ['Height', `${ht.height.toFixed(1)} m · ${ht.label}`],
    ['Floors', b.floors ?? b.floor_count ?? p.floors],
    ['Roof shape', b.roof_shape ?? b.roof_type ?? p.roof_shape],
    ['Roof material', b.roof_material ?? p.roof_material],
    ['Roof pitch', b.roof_pitch ?? p.roof_pitch],
    ['Assessed value', p.assessed_value ?? p.total_assessed_value ?? b.assessed_value],
    ['Parcel', p.parcel_id ?? p.apn ?? b.parcel_id],
    ['Elevation', b.ground_elevation_m ?? p.elevation_m ?? detail.elevation?.elevation_m],
    ['Geometry source', b.source_name ?? b.source_key ?? detail.source_name],
    ['Confidence', b.confidence ?? detail.confidence],
  ].filter(([, v]) => v !== null && v !== undefined && String(v).trim() !== '');
  return rows;
}

export async function createStructureLab({ root, canvasHost, infoHost, measurementHost, detail, onClose }) {
  if (!root || !canvasHost || !detail) throw new Error('Structure lab requires root, canvasHost and building detail.');
  const { THREE, OrbitControls } = await loadThree();
  const geometry = geometryFromDetail(detail);
  const rings = outerRings(geometry);
  if (!rings.length) {
    infoHost.innerHTML = '<b>Structure geometry unavailable</b><small>BridgePoint will not fabricate an exact 3D footprint when the source geometry is missing.</small>';
    root.classList.add('open');
    return { destroy: () => root.classList.remove('open') };
  }

  const projector = localProjector(rings);
  if (!projector) throw new Error('Could not project structure geometry.');
  const ht = heightTruth(detail);
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x020711);
  scene.fog = new THREE.FogExp2(0x020711, .0018);
  const camera = new THREE.PerspectiveCamera(48, 1, .05, 5000);
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.6));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  canvasHost.replaceChildren(renderer.domElement);

  const shapes = rings.map((r) => shapeFromRing(THREE, r, projector.point)).filter(Boolean);
  const buildingMeshes = [];
  for (const shape of shapes) {
    const geo = new THREE.ExtrudeGeometry(shape, { depth: ht.height, bevelEnabled: false, steps: 1 });
    const mat = new THREE.MeshStandardMaterial({ color: 0x36bed7, roughness: .68, metalness: .08, transparent: true, opacity: .9 });
    const mesh = new THREE.Mesh(geo, mat);
    scene.add(mesh);
    buildingMeshes.push(mesh);
    const edge = new THREE.LineSegments(new THREE.EdgesGeometry(geo, 28), new THREE.LineBasicMaterial({ color: 0xa6f5ff, transparent: true, opacity: .68 }));
    scene.add(edge);
  }
  addRoofCue(THREE, scene, shapes, ht.height, detail);
  addParcel(THREE, scene, parcelGeometry(detail), projector);

  const ground = new THREE.GridHelper(300, 60, 0x1d5264, 0x0d2632);
  ground.rotation.x = Math.PI / 2;
  scene.add(ground);
  scene.add(new THREE.HemisphereLight(0xcdefff, 0x061019, 1.45));
  const sun = new THREE.DirectionalLight(0xffffff, 1.7); sun.position.set(80, -110, 180); scene.add(sun);

  const bounds = new THREE.Box3();
  for (const m of buildingMeshes) bounds.expandByObject(m);
  const size = bounds.getSize(new THREE.Vector3());
  const center = bounds.getCenter(new THREE.Vector3());
  const span = Math.max(size.x, size.y, size.z, 15);
  camera.position.set(center.x + span * 1.25, center.y - span * 1.5, center.z + span * .95);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.target.copy(center);
  controls.enableDamping = true;
  controls.dampingFactor = .075;
  controls.minDistance = Math.max(3, span * .18);
  controls.maxDistance = span * 8;
  controls.update();

  const p = detailProperty(detail), b = detailBuilding(detail);
  infoHost.innerHTML = `<b>${esc(p.full_address || p.address || b.address || 'Structure + Parcel Lab')}</b><small>${esc(b.source_name || b.source_key || 'BridgePoint source geometry')} · ${esc(ht.label)}</small>`;
  const rows = factRows(detail);
  const factPanel = document.createElement('div');
  factPanel.className = 'measurement panel';
  factPanel.style.right = '10px'; factPanel.style.left = 'auto'; factPanel.style.maxHeight = '42vh'; factPanel.style.overflow = 'auto';
  factPanel.innerHTML = rows.map(([k, v]) => `<div><b>${esc(k)}:</b> ${esc(v)}</div>`).join('');
  root.appendChild(factPanel);

  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();
  const measurePts = [];
  const measureVisuals = [];
  let measuring = false;
  let xray = false;

  function clearMeasurement() {
    measurePts.length = 0;
    for (const o of measureVisuals.splice(0)) { scene.remove(o); o.geometry?.dispose?.(); o.material?.dispose?.(); }
    measurementHost.textContent = 'Measure: tap Measure, then choose two points on the source-backed structure.';
  }
  function setMeasure(enabled) { measuring = enabled; clearMeasurement(); measurementHost.textContent = enabled ? 'Choose point 1 on the structure.' : 'Measurement off.'; }
  function onPointer(ev) {
    if (!measuring) return;
    const rect = renderer.domElement.getBoundingClientRect();
    pointer.x = ((ev.clientX - rect.left) / rect.width) * 2 - 1;
    pointer.y = -((ev.clientY - rect.top) / rect.height) * 2 + 1;
    raycaster.setFromCamera(pointer, camera);
    const hit = raycaster.intersectObjects(buildingMeshes, false)[0];
    if (!hit) return;
    measurePts.push(hit.point.clone());
    const dot = new THREE.Mesh(new THREE.SphereGeometry(Math.max(.08, span * .006), 12, 8), new THREE.MeshBasicMaterial({ color: 0xffd15c })); dot.position.copy(hit.point); scene.add(dot); measureVisuals.push(dot);
    if (measurePts.length === 1) measurementHost.textContent = 'Choose point 2 on the structure.';
    if (measurePts.length === 2) {
      const lineGeo = new THREE.BufferGeometry().setFromPoints(measurePts);
      const line = new THREE.Line(lineGeo, new THREE.LineBasicMaterial({ color: 0xffd15c })); scene.add(line); measureVisuals.push(line);
      const d = measurePts[0].distanceTo(measurePts[1]);
      measurementHost.textContent = `3D point-to-point distance: ${d.toFixed(d < 10 ? 2 : 1)} m. Measurement is on the rendered source geometry.`;
      measuring = false;
    }
  }
  renderer.domElement.addEventListener('pointerdown', onPointer);

  const resize = () => {
    const w = Math.max(1, canvasHost.clientWidth), h = Math.max(1, canvasHost.clientHeight);
    renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix();
  };
  const ro = new ResizeObserver(resize); ro.observe(canvasHost); resize();
  let raf = 0, stopped = false;
  const loop = () => { if (stopped) return; controls.update(); renderer.render(scene, camera); raf = requestAnimationFrame(loop); }; loop();

  const api = {
    reset() { camera.position.set(center.x + span * 1.25, center.y - span * 1.5, center.z + span * .95); controls.target.copy(center); controls.update(); },
    measure() { setMeasure(!measuring); },
    xray() { xray = !xray; for (const m of buildingMeshes) { m.material.transparent = true; m.material.opacity = xray ? .25 : .9; m.material.needsUpdate = true; } return xray; },
    destroy() {
      stopped = true; cancelAnimationFrame(raf); ro.disconnect(); renderer.domElement.removeEventListener('pointerdown', onPointer); controls.dispose();
      scene.traverse((o) => { o.geometry?.dispose?.(); if (Array.isArray(o.material)) o.material.forEach((m) => m.dispose?.()); else o.material?.dispose?.(); });
      renderer.dispose(); renderer.forceContextLoss?.(); renderer.domElement.remove(); factPanel.remove(); clearMeasurement(); root.classList.remove('open'); onClose?.();
    },
  };
  root.classList.add('open');
  return api;
}
