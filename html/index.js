    const root = document.getElementById('root');
    const panel = document.getElementById('panel');
    const topbar = document.getElementById('topbar');
    const backdrop = document.getElementById('backdrop');
    const closeBtn = document.getElementById('closeBtn');
    const clockEl = document.getElementById('clock');
    const titleEl = document.getElementById('title');
    const subtitleEl = document.getElementById('subtitle');
    const condEl = document.getElementById('cond');
    const summaryEl = document.getElementById('summary');
    const tempEl = document.getElementById('temp');
    const precipValEl = document.getElementById('precipVal');
    const precipLabEl = document.getElementById('precipLab');
    const windValEl = document.getElementById('windVal');
    const regionValEl = document.getElementById('regionVal');
    const weeklyRangeEl = document.getElementById('weeklyRange');
    const modelTextEl = document.getElementById('modelText');
    const regionTagEl = document.getElementById('regionTag');
    const hourlyEl = document.getElementById('hourly');
    const forecastStripEl = document.getElementById('forecastStrip');
    const zoneOverviewEl = document.getElementById('zoneOverview');
    const zoneListEl = document.getElementById('zoneList');
    const selectedTitleEl = document.getElementById('selectedTitle');
    const selectedDescEl = document.getElementById('selectedDesc');
    const selectedForecastEl = document.getElementById('selectedForecast');
    const zoneMapEl = document.getElementById('zoneMap');
    const zoneMapCanvasEl = document.getElementById('zoneMapCanvas');
    const zoneOverlayDomEl = document.getElementById('zoneOverlayDom');
    const mapLoadStateEl = document.getElementById('mapLoadState');
    const zoneLabelEl = document.getElementById('zoneLabel');
    const zoneProfileEl = document.getElementById('zoneProfile');
    const zoneRadiusEl = document.getElementById('zoneRadius');
    const zoneIntensityEl = document.getElementById('zoneIntensity');
    const radiusOutEl = document.getElementById('radiusOut');
    const intensityOutEl = document.getElementById('intensityOut');
    const mapCoordsEl = document.getElementById('mapCoords');
    const newZoneBtn = document.getElementById('newZoneBtn');
    const saveZoneBtn = document.getElementById('saveZoneBtn');
    const deleteZoneBtn = document.getElementById('deleteZoneBtn');
    const focusOverviewBtn = document.getElementById('focusOverviewBtn');
    const fitZonesBtn = document.getElementById('fitZonesBtn');
    const fitWorldBtn = document.getElementById('fitWorldBtn');
    const nwsStack = document.getElementById('nwsStack');
    const resizeHandle = document.getElementById('resizeHandle');
    const tabs = [...document.querySelectorAll('.tab')];
    const mapStyleBtns = [...document.querySelectorAll('.mapStyleBtn')];

    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'nui-resource';
    const post = (name, data={}) => fetch(`https://${RESOURCE}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data)
    }).catch(() => {});

    let state = null;
    let zones = [];
    let profiles = [];
    let selectedZoneId = null;
    let draftZone = null;
    let activeTab = 'overview';

    const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const clamp01 = (v) => clamp(Number(v || 0), 0, 1);
    const fmtTemp = (v) => `${Math.round(Number(v || 0))}°`;
    const fmtPct = (v) => `${Math.round(clamp01(v) * 100)}%`;

    function iconSvg(name) {
      if (name === 'thunder') return '<svg viewBox="0 0 64 64" fill="none"><path d="M20 32h25a10 10 0 0 0 0-20 15 15 0 0 0-29-3A10 10 0 0 0 20 32z" fill="rgba(255,255,255,.84)"/><path d="M30 36h9l-5 10h6L28 60l4-12h-6l4-12z" fill="#ffd36a"/></svg>';
      if (name === 'rain') return '<svg viewBox="0 0 64 64" fill="none"><path d="M20 30h25a10 10 0 0 0 0-20 15 15 0 0 0-29-3A10 10 0 0 0 20 30z" fill="rgba(255,255,255,.84)"/><g fill="#79d6ff"><path d="M24 38c2 3 0 6-2 8-2-2-4-5-2-8 1-2 3-2 4 0z"/><path d="M34 38c2 3 0 6-2 8-2-2-4-5-2-8 1-2 3-2 4 0z"/><path d="M44 38c2 3 0 6-2 8-2-2-4-5-2-8 1-2 3-2 4 0z"/></g></svg>';
      if (name === 'snow') return '<svg viewBox="0 0 64 64" fill="none"><path d="M20 30h25a10 10 0 0 0 0-20 15 15 0 0 0-29-3A10 10 0 0 0 20 30z" fill="rgba(255,255,255,.84)"/><g fill="rgba(255,255,255,.95)"><circle cx="25" cy="43" r="2.4"/><circle cx="34" cy="47" r="2.4"/><circle cx="43" cy="43" r="2.4"/></g></svg>';
      if (name === 'wind') return '<svg viewBox="0 0 64 64" fill="none"><path d="M10 24h34c6 0 9-7 2-10" stroke="rgba(255,255,255,.9)" stroke-width="4" stroke-linecap="round"/><path d="M10 36h40c8 0 11-8 2-12" stroke="rgba(255,255,255,.72)" stroke-width="4" stroke-linecap="round"/><path d="M10 48h25c6 0 8 6 2 8" stroke="rgba(255,255,255,.62)" stroke-width="4" stroke-linecap="round"/></svg>';
      if (name === 'clear-night') return '<svg viewBox="0 0 64 64" fill="none"><path d="M40 10c-10 4-15 16-11 26s16 15 26 11c-3 7-10 12-18 12C25 59 15 49 15 37c0-8 4-15 10-19 4-3 9-5 15-5z" fill="rgba(255,255,255,.88)"/></svg>';
      if (name === 'clear-day') return '<svg viewBox="0 0 64 64" fill="none"><circle cx="32" cy="32" r="12" fill="#ffd164"/><g stroke="#ffd164" stroke-width="4" stroke-linecap="round"><path d="M32 8v8"/><path d="M32 48v8"/><path d="M8 32h8"/><path d="M48 32h8"/></g></svg>';
      return '<svg viewBox="0 0 64 64" fill="none"><path d="M20 34h26a10 10 0 0 0 0-20 15 15 0 0 0-29-3A10 10 0 0 0 20 34z" fill="rgba(255,255,255,.84)"/></svg>';
    }

    function show() { root.classList.remove('hidden'); requestAnimationFrame(() => root.classList.add('open')); }
    function hide() { root.classList.remove('open'); setTimeout(() => root.classList.add('hidden'), 120); }
    function closeUi() { hide(); post('azwx_weather_close', {}); }

    function setTab(tab) {
      activeTab = tab;
      tabs.forEach(btn => btn.classList.toggle('active', btn.dataset.tab === tab));
      document.getElementById('tab-overview').classList.toggle('hidden', tab !== 'overview');
      document.getElementById('tab-regional').classList.toggle('hidden', tab !== 'regional');
      if (tab === 'regional') requestAnimationFrame(() => renderMap(true));
    }
    tabs.forEach(btn => btn.addEventListener('click', () => setTab(btn.dataset.tab)));
    mapStyleBtns.filter((btn) => btn.dataset.mapStyle).forEach((btn) => btn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      applyMapStyle(btn.dataset.mapStyle);
      renderMap(true, true);
    }));
    fitZonesBtn?.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      mapHasInitialFrame = true;
      fitMapToZones(true);
    });
    fitWorldBtn?.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      mapHasInitialFrame = true;
      fitWorldMap();
      renderMap(true, true);
    });
    focusOverviewBtn.addEventListener('click', () => setTab('overview'));


let leafletMap = null;
let mapImageOverlay = null;
let mapReady = false;
let currentMapStyle = 'road';
let mapHasInitialFrame = false;
let zoneOverlayQueued = false;
let zoneDrag = null;
let lastMapRenderKey = '';
let lastMapPlayerKey = '';
let mapWorldEl = null;
let mapImageEl = null;
let mapOverlayWorldEl = null;
let mapPan = null;
let suppressMapClick = false;

const MAP_STYLE_META = {
  road: {
    label: 'Road',
    url: 'map-road.jpg',
    loading: 'Loading embedded Los Santos road map…',
    ready: 'Embedded Los Santos road map',
  },
  atlas: {
    label: 'Atlas',
    url: 'map-atlas.jpg',
    loading: 'Loading embedded Los Santos atlas map…',
    ready: 'Embedded Los Santos atlas map',
  },
};

const MAP_BASE = { width: 4096, height: 4096 };
const MAP_VIEW_PADDING = 24;
const mapView = { scale: 1, minScale: 0.12, maxScale: 9, tx: 0, ty: 0 };

function worldToLatLng(x, y) { return [Number(y) || 0, Number(x) || 0]; }
function latLngToWorld(latlng) {
  return {
    x: Number(latlng?.lng || 0),
    y: Number(latlng?.lat || 0),
  };
}
function worldBounds() {
  const w = state?.world || { minX:-4200, maxX:4500, minY:-4200, maxY:8000 };
  return [[Number(w.minY), Number(w.minX)], [Number(w.maxY), Number(w.maxX)]];
}
function worldMeta() {
  const b = worldBounds();
  const minY = Number(b[0][0]);
  const minX = Number(b[0][1]);
  const maxY = Number(b[1][0]);
  const maxX = Number(b[1][1]);
  return {
    minX, minY, maxX, maxY,
    rangeX: Math.max(1, maxX - minX),
    rangeY: Math.max(1, maxY - minY),
  };
}
function worldToBase(x, y) {
  const w = worldMeta();
  return {
    x: ((Number(x || 0) - w.minX) / w.rangeX) * MAP_BASE.width,
    y: MAP_BASE.height - (((Number(y || 0) - w.minY) / w.rangeY) * MAP_BASE.height),
  };
}
function baseToWorld(x, y) {
  const w = worldMeta();
  return {
    x: w.minX + (Number(x || 0) / MAP_BASE.width) * w.rangeX,
    y: w.minY + ((MAP_BASE.height - Number(y || 0)) / MAP_BASE.height) * w.rangeY,
  };
}
function worldToScreen(x, y) {
  const base = worldToBase(x, y);
  return {
    x: base.x * mapView.scale + mapView.tx,
    y: base.y * mapView.scale + mapView.ty,
  };
}
function screenToWorld(clientX, clientY) {
  const rect = zoneMapCanvasEl.getBoundingClientRect();
  const localX = clamp(Number(clientX) - rect.left, 0, rect.width);
  const localY = clamp(Number(clientY) - rect.top, 0, rect.height);
  const baseX = (localX - mapView.tx) / mapView.scale;
  const baseY = (localY - mapView.ty) / mapView.scale;
  return baseToWorld(baseX, baseY);
}
function worldRadiusToBase(r) {
  const w = worldMeta();
  const pxPerMeterX = MAP_BASE.width / w.rangeX;
  const pxPerMeterY = MAP_BASE.height / w.rangeY;
  return Math.max(8, Number(r || 0) * Math.min(pxPerMeterX, pxPerMeterY));
}
function setMapStatus(text, tone = '') {
  mapLoadStateEl.textContent = text;
  mapLoadStateEl.className = `mapLoadState${tone ? ` ${tone}` : ''}`;
}
function mapImageUrl(style = currentMapStyle) {
  return MAP_STYLE_META[style]?.url || MAP_STYLE_META.road.url;
}
function clampMapView() {
  const rect = zoneMapCanvasEl.getBoundingClientRect();
  const scaledW = MAP_BASE.width * mapView.scale;
  const scaledH = MAP_BASE.height * mapView.scale;
  if (scaledW <= rect.width) {
    mapView.tx = Math.round((rect.width - scaledW) * 0.5);
  } else {
    mapView.tx = clamp(mapView.tx, rect.width - scaledW, 0);
  }
  if (scaledH <= rect.height) {
    mapView.ty = Math.round((rect.height - scaledH) * 0.5);
  } else {
    mapView.ty = clamp(mapView.ty, rect.height - scaledH, 0);
  }
}
function applyWorldTransform() {
  if (!mapWorldEl) return;
  clampMapView();
  mapWorldEl.style.transform = `translate(${Math.round(mapView.tx)}px, ${Math.round(mapView.ty)}px) scale(${mapView.scale})`;
  zoneMapCanvasEl.style.setProperty('--map-scale', String(mapView.scale));
}
function fitViewToBounds(bounds, opts = {}) {
  ensureLeafletMap();
  const rect = zoneMapCanvasEl.getBoundingClientRect();
  if (!rect.width || !rect.height) return;
  const padding = Number(opts.padding || 56);
  const minLat = Number(bounds?.[0]?.[0] || worldBounds()[0][0]);
  const minLng = Number(bounds?.[0]?.[1] || worldBounds()[0][1]);
  const maxLat = Number(bounds?.[1]?.[0] || worldBounds()[1][0]);
  const maxLng = Number(bounds?.[1]?.[1] || worldBounds()[1][1]);
  const tl = worldToBase(minLng, minLat);
  const br = worldToBase(maxLng, maxLat);
  const bw = Math.max(120, br.x - tl.x);
  const bh = Math.max(120, br.y - tl.y);
  const sx = Math.max(0.01, (rect.width - padding * 2) / bw);
  const sy = Math.max(0.01, (rect.height - padding * 2) / bh);
  mapView.scale = clamp(Math.min(sx, sy), mapView.minScale, mapView.maxScale);
  const cx = (tl.x + br.x) * 0.5;
  const cy = (tl.y + br.y) * 0.5;
  mapView.tx = rect.width * 0.5 - cx * mapView.scale;
  mapView.ty = rect.height * 0.5 - cy * mapView.scale;
  applyWorldTransform();
}
function fitWorldMap() {
  fitViewToBounds(worldBounds(), { padding: MAP_VIEW_PADDING });
  mapHasInitialFrame = true;
  scheduleZoneOverlayUpdate(true);
}
function updateMapCoordLabel(world) {
  mapCoordsEl.textContent = `X ${Math.round(Number(world?.x || 0))} • Y ${Math.round(Number(world?.y || 0))}`;
}
function ensureDraftFromSelection() {
  if (draftZone) return;
  const z = zones.find(z => Number(z.id) === Number(selectedZoneId));
  if (z) draftZone = { ...z };
}

function getRenderableZones() {
  if (Array.isArray(zones) && zones.length) return zones;
  if (Array.isArray(state?.regional) && state.regional.length) {
    return state.regional.map((z) => ({
      id: z.id,
      label: z.label,
      profile: z.profile,
      x: Number(z.x || 0),
      y: Number(z.y || 0),
      r: Number(z.r || 0),
      intensity: Number(z.intensity || 0.85),
      priority: Number(z.priority || 0),
    }));
  }
  return [];
}

function getDisplayZones() {
  const base = getRenderableZones().map((z) => ({ ...z }));
  if (!draftZone) return base;
  let replaced = false;
  for (let i = 0; i < base.length; i++) {
    if (draftZone.id != null && Number(base[i].id) === Number(draftZone.id)) {
      base[i] = { ...base[i], ...draftZone };
      replaced = true;
      break;
    }
  }
  if (!replaced) base.push({ ...draftZone, id: draftZone.id ?? '__draft__' });
  return base;
}

function scheduleZoneOverlayUpdate(force = false) {
  if (!mapOverlayWorldEl) return;
  if (zoneOverlayQueued && !force) return;
  zoneOverlayQueued = true;
  requestAnimationFrame(() => {
    zoneOverlayQueued = false;
    renderZoneOverlay(force);
  });
}

function beginZoneDrag(ev, zoneId) {
  ev.preventDefault();
  ev.stopPropagation();
  const zone = getDisplayZones().find((z) => String(z.id) === String(zoneId));
  if (!zone) return;
  selectedZoneId = zone.id;
  draftZone = { ...zone };
  zoneDrag = { zoneId: String(zone.id) };
  suppressMapClick = true;
  renderZoneList();
  renderSelectedZone();
  scheduleZoneOverlayUpdate(true);
}

function renderZoneOverlay(force = false) {
  if (!mapOverlayWorldEl) return;
  const displayZones = getDisplayZones();
  const key = JSON.stringify(displayZones.map((z) => [String(z.id), Math.round(Number(z.x || 0)), Math.round(Number(z.y || 0)), Math.round(Number(z.r || 0)), Number(z.intensity || 0), z.label || '', z.profile || '']));
  const playerKey = state?.player ? `${Math.round(Number(state.player.x || 0))}:${Math.round(Number(state.player.y || 0))}` : '';
  if (!force && key === lastMapRenderKey && playerKey === lastMapPlayerKey) return;
  lastMapRenderKey = key;
  lastMapPlayerKey = playerKey;

  mapOverlayWorldEl.innerHTML = '';
  const frag = document.createDocumentFragment();
  displayZones.forEach((z) => {
    const point = worldToBase(z.x, z.y);
    const rBase = worldRadiusToBase(z.r);
    const selected = String(z.id) === String(selectedZoneId) || (draftZone && draftZone.id == null && String(z.id) === '__draft__');

    const circle = document.createElement('button');
    circle.type = 'button';
    circle.className = `zoneDomCircle${selected ? ' selected' : ''}`;
    circle.style.left = `${point.x}px`;
    circle.style.top = `${point.y}px`;
    circle.style.width = `${rBase * 2}px`;
    circle.style.height = `${rBase * 2}px`;
    circle.title = `${z.label || 'Zone'} • radius ${Math.round(Number(z.r || 0))}m`;
    circle.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      selectedZoneId = z.id;
      draftZone = { ...z };
      renderZoneList();
      renderSelectedZone();
      scheduleZoneOverlayUpdate(true);
    });
    frag.appendChild(circle);

    const handle = document.createElement('button');
    handle.type = 'button';
    handle.className = `zoneDomHandle${selected ? ' selected' : ''}`;
    handle.style.left = `${point.x}px`;
    handle.style.top = `${point.y}px`;
    handle.title = `Drag ${z.label || 'zone'} center`;
    handle.addEventListener('mousedown', (e) => beginZoneDrag(e, z.id));
    frag.appendChild(handle);

    if (rBase >= 30 || selected) {
      const label = document.createElement('div');
      label.className = 'zoneDomLabel';
      label.style.left = `${point.x}px`;
      label.style.top = `${Math.max(18, point.y - rBase - 18)}px`;
      label.innerHTML = `<div class="zoneLabelBadge">${esc(z.label || 'Zone')}</div>`;
      frag.appendChild(label);
    }
  });

  if (state?.player) {
    const point = worldToBase(state.player.x, state.player.y);
    const player = document.createElement('div');
    player.className = 'zoneDomPlayer';
    player.style.left = `${point.x}px`;
    player.style.top = `${point.y}px`;
    frag.appendChild(player);
  }

  mapOverlayWorldEl.appendChild(frag);

  if (displayZones.length) {
    setMapStatus(`${MAP_STYLE_META[currentMapStyle].ready} • ${displayZones.length} zone${displayZones.length === 1 ? '' : 's'} visible`, 'ok');
  } else {
    setMapStatus(`${MAP_STYLE_META[currentMapStyle].ready} • no zones available`, 'warn');
  }
}

function fitMapToZones(preferAll = false) {
  ensureLeafletMap();
  const src = getDisplayZones();
  if (!src.length) {
    fitWorldMap();
    return;
  }

  const target = (!preferAll && draftZone) ? [draftZone] : src;
  let minLat = Infinity, minLng = Infinity, maxLat = -Infinity, maxLng = -Infinity;
  target.forEach((z) => {
    const r = Math.max(120, Number(z.r || 0));
    const lat = Number(z.y || 0);
    const lng = Number(z.x || 0);
    minLat = Math.min(minLat, lat - r);
    minLng = Math.min(minLng, lng - r);
    maxLat = Math.max(maxLat, lat + r);
    maxLng = Math.max(maxLng, lng + r);
  });
  if (!isFinite(minLat) || !isFinite(minLng) || !isFinite(maxLat) || !isFinite(maxLng)) {
    fitWorldMap();
    return;
  }
  fitViewToBounds([[minLat, minLng], [maxLat, maxLng]], { padding: preferAll ? 56 : 44 });
  mapHasInitialFrame = true;
  scheduleZoneOverlayUpdate(true);
}
function setupMapInteractions() {
  if (!zoneMapCanvasEl || zoneMapCanvasEl.dataset.bound === '1') return;
  zoneMapCanvasEl.dataset.bound = '1';

  zoneMapCanvasEl.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    if (e.target.closest('.zoneDomHandle, .zoneDomCircle, .mapStyleBtn, .leaflet-control-zoom')) return;
    suppressMapClick = false;
    mapPan = {
      startX: e.clientX,
      startY: e.clientY,
      tx: mapView.tx,
      ty: mapView.ty,
      moved: false,
    };
    zoneMapCanvasEl.classList.add('draggingMap');
  });
  zoneMapCanvasEl.addEventListener('mousemove', (e) => {
    const world = screenToWorld(e.clientX, e.clientY);
    updateMapCoordLabel(world);
  });
  zoneMapCanvasEl.addEventListener('click', (e) => {
    if (suppressMapClick) {
      suppressMapClick = false;
      return;
    }
    if (e.target.closest('.zoneDomHandle, .zoneDomCircle, .mapStyleBtn, .leaflet-control-zoom')) return;
    const world = screenToWorld(e.clientX, e.clientY);
    handleMapLatLng({ lat: world.y, lng: world.x });
  });
  zoneMapCanvasEl.addEventListener('wheel', (e) => {
    e.preventDefault();
    const rect = zoneMapCanvasEl.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const localX = e.clientX - rect.left;
    const localY = e.clientY - rect.top;
    const baseX = (localX - mapView.tx) / mapView.scale;
    const baseY = (localY - mapView.ty) / mapView.scale;
    const factor = e.deltaY < 0 ? 1.18 : (1 / 1.18);
    const nextScale = clamp(mapView.scale * factor, mapView.minScale, mapView.maxScale);
    mapView.scale = nextScale;
    mapView.tx = localX - baseX * nextScale;
    mapView.ty = localY - baseY * nextScale;
    applyWorldTransform();
  }, { passive: false });
}
function applyMapStyle(style = currentMapStyle) {
  currentMapStyle = MAP_STYLE_META[style] ? style : 'road';
  mapStyleBtns.forEach((btn) => btn.classList.toggle('active', btn.dataset.mapStyle === currentMapStyle));
  ensureLeafletMap();
  mapReady = false;
  setMapStatus(MAP_STYLE_META[currentMapStyle].loading);
  if (mapImageEl) {
    mapImageEl.src = mapImageUrl(currentMapStyle);
  }
}
function ensureLeafletMap() {
  if (leafletMap) return leafletMap;

  zoneMapCanvasEl.innerHTML = '';
  zoneOverlayDomEl.innerHTML = '';
  zoneOverlayDomEl.style.display = 'none';
  zoneMapCanvasEl.classList.add('azwxMapViewport');

  mapWorldEl = document.createElement('div');
  mapWorldEl.className = 'azwxMapWorld';
  mapWorldEl.style.width = `${MAP_BASE.width}px`;
  mapWorldEl.style.height = `${MAP_BASE.height}px`;

  mapImageEl = document.createElement('img');
  mapImageEl.className = 'azwxMapImage';
  mapImageEl.alt = '';
  mapImageEl.draggable = false;
  mapImageEl.decoding = 'async';
  mapImageEl.addEventListener('load', () => {
    mapReady = true;
    setMapStatus(MAP_STYLE_META[currentMapStyle].ready, 'ok');
    scheduleZoneOverlayUpdate(true);
  });
  mapImageEl.addEventListener('error', () => {
    mapReady = false;
    setMapStatus(`Failed to load ${MAP_STYLE_META[currentMapStyle].label.toLowerCase()} map image.`, 'warn');
  });

  mapOverlayWorldEl = document.createElement('div');
  mapOverlayWorldEl.className = 'azwxWorldOverlay';

  mapWorldEl.appendChild(mapImageEl);
  mapWorldEl.appendChild(mapOverlayWorldEl);
  zoneMapCanvasEl.appendChild(mapWorldEl);

  leafletMap = {
    invalidateSize() { applyWorldTransform(); },
    setMaxBounds() {},
    fitBounds(bounds, opts = {}) { fitViewToBounds(bounds, { padding: Array.isArray(opts.padding) ? opts.padding[0] : 56 }); },
    latLngToContainerPoint(latlng) {
      const world = latLngToWorld(latlng);
      return worldToScreen(world.x, world.y);
    },
    containerPointToLatLng(point) {
      const world = screenToWorld(point[0], point[1]);
      return { lat: world.y, lng: world.x };
    },
    dragging: {
      disable() { if (mapPan) mapPan.disabled = true; },
      enable() { if (mapPan) mapPan.disabled = false; },
    },
  };

  setupMapInteractions();
  applyMapStyle(currentMapStyle);
  fitWorldMap();
  return leafletMap;
}

function renderMap(forceInvalidate = false, forceOverlay = false) {
  if (!state) return;
  ensureLeafletMap();
  if (forceInvalidate) applyWorldTransform();
  const focusWorld = draftZone ? { x: draftZone.x, y: draftZone.y } : state.player ? { x: state.player.x, y: state.player.y } : null;
  if (activeTab === 'regional' && !mapHasInitialFrame) {
    fitMapToZones(true);
  }
  if (focusWorld) updateMapCoordLabel(focusWorld);
  if (forceOverlay || forceInvalidate) scheduleZoneOverlayUpdate(true);
  else scheduleZoneOverlayUpdate(false);
}

function handleMapLatLng(latlng) {
  const world = latLngToWorld(latlng);
  updateMapCoordLabel(world);
  if (!draftZone) {
    draftZone = { label: 'Regional Zone', profile: profiles[0]?.id || 'CUSTOM', r: 1600, intensity: 0.85 };
  }
  draftZone.x = world.x;
  draftZone.y = world.y;
  draftZone.label = zoneLabelEl.value || draftZone.label || 'Regional Zone';
  draftZone.profile = zoneProfileEl.value || draftZone.profile || 'CUSTOM';
  draftZone.r = Number(zoneRadiusEl.value || draftZone.r || 1600);
  draftZone.intensity = Number(zoneIntensityEl.value || draftZone.intensity || 0.85);
  scheduleZoneOverlayUpdate(true);
}
    function renderProfiles() {
      zoneProfileEl.innerHTML = profiles.map(p => `<option value="${esc(p.id)}">${esc(p.label)}</option>`).join('');
      if (draftZone?.profile) zoneProfileEl.value = draftZone.profile;
    }

    function buildForecastCard(d, idx) {
      return `<div class="forecastCard"><div class="forecastLabel">${esc(idx === 0 ? 'Now' : (d.label || `+${idx}`))}</div><div>${iconSvg(d.icon || 'cloudy')}</div><div class="forecastTemp">${fmtTemp(d.tempC ?? d.temp ?? 0)}</div><div class="forecastCond">${esc(d.condition || d.detail || '')}</div></div>`;
    }

    function renderOverview() {
      if (!state) return;
      const now = state.now || {};
      titleEl.textContent = state.location || 'Regional Weather';
      subtitleEl.textContent = state.subtitle || 'Live regional forecast';
      clockEl.textContent = state.clock || '00:00';
      condEl.textContent = now.condition || 'Clear';
      summaryEl.textContent = now.summary || 'Forecast at your position';
      tempEl.textContent = fmtTemp(now.tempC ?? 0);
      const snow = clamp01(now.snow || 0);
      const rain = clamp01(now.rain || 0);
      precipValEl.textContent = fmtPct(Math.max(snow, rain));
      precipLabEl.textContent = snow >= rain && snow > 0.15 ? 'Snow chance' : 'Rain chance';
      windValEl.textContent = `${Math.round(Number(now.windMph || 0))} mph`;
      regionValEl.textContent = state.currentRegion || 'Open skies';
      regionTagEl.textContent = state.currentRegion || 'Dominant zone';
      weeklyRangeEl.textContent = `H:${state.weekly?.hi ?? '--'}  L:${state.weekly?.lo ?? '--'}`;
      modelTextEl.textContent = state.model || 'Dynamic fronts + regional zones';

      const days = (state.days || []).slice(0, 6);
      hourlyEl.innerHTML = days.map((d, idx) => buildForecastCard(d, idx)).join('');
      forecastStripEl.innerHTML = (state.days || []).slice(0, 10).map((d, idx) => buildForecastCard(d, idx)).join('');

      zoneOverviewEl.innerHTML = '';
      (state.regional || []).forEach((z) => {
        const row = document.createElement('div');
        row.className = 'zoneSnap';
        row.innerHTML = `
          <div class="zoneTop">
            <div>
              <div class="zoneName">${esc(z.label)}</div>
              <div class="zoneMeta">${esc(z.profileLabel || z.profile || 'Zone')}</div>
            </div>
            <div>${iconSvg(z.current?.icon || 'cloudy')}</div>
          </div>
          <div class="chipRow">
            <span class="chip">${esc(z.current?.condition || 'Clear')}</span>
            <span class="chip">${fmtTemp(z.current?.tempC ?? 0)}</span>
            <span class="chip">Wind ${Math.round(Number(z.current?.windMph || 0))} mph</span>
          </div>
        `;
        row.addEventListener('click', () => {
          selectedZoneId = z.id;
          draftZone = zones.find(v => Number(v.id) === Number(z.id)) ? { ...zones.find(v => Number(v.id) === Number(z.id)) } : null;
          renderZoneList();
          renderSelectedZone();
          renderMap(true);
          setTab('regional');
        });
        zoneOverviewEl.appendChild(row);
      });
    }

    function renderZoneList() {
      zoneListEl.innerHTML = '';
      (state.regional || []).forEach((z) => {
        const row = document.createElement('div');
        row.className = 'zoneRow' + (Number(z.id) === Number(selectedZoneId) ? ' selected' : '');
        row.innerHTML = `
          <div class="zoneTop">
            <div>
              <div class="zoneName">${esc(z.label)}</div>
              <div class="zoneMeta">${esc(z.profileLabel || z.profile || 'Zone')} • radius ${Math.round(Number(z.r || 0))}m</div>
            </div>
            <div>${iconSvg(z.current?.icon || 'cloudy')}</div>
          </div>
          <div class="chipRow">
            <span class="chip">${esc(z.current?.condition || 'Clear')}</span>
            <span class="chip">${fmtTemp(z.current?.tempC ?? 0)}</span>
            ${(z.upcoming || []).slice(0, 3).map(step => `<span class="chip">${esc(step.label)} ${esc(step.condition || '')}</span>`).join('')}
          </div>
        `;
        row.addEventListener('click', () => {
          selectedZoneId = z.id;
          const saved = zones.find(v => Number(v.id) === Number(z.id));
          draftZone = saved ? { ...saved } : null;
          renderSelectedZone();
          renderMap();
          syncEditor();
          renderZoneList();
        });
        zoneListEl.appendChild(row);
      });
    }

    function syncEditor() {
      ensureDraftFromSelection();
      if (!draftZone) return;
      zoneLabelEl.value = draftZone.label || 'Regional Zone';
      zoneProfileEl.value = draftZone.profile || (profiles[0]?.id || 'CUSTOM');
      zoneRadiusEl.value = clamp(Number(draftZone.r || 1600), Number(zoneRadiusEl.min), Number(zoneRadiusEl.max));
      zoneIntensityEl.value = clamp(Number(draftZone.intensity || 0.85), Number(zoneIntensityEl.min), Number(zoneIntensityEl.max));
      radiusOutEl.textContent = `${Math.round(Number(zoneRadiusEl.value))}m`;
      intensityOutEl.textContent = `${Math.round(Number(zoneIntensityEl.value) * 100)}%`;
    }

    function renderSelectedZone() {
      const z = (state.regional || []).find(v => Number(v.id) === Number(selectedZoneId));
      if (!z && !draftZone) {
        selectedTitleEl.textContent = 'No zone selected';
        selectedDescEl.textContent = 'Pick a regional zone to review its current atmosphere and upcoming changes.';
        selectedForecastEl.innerHTML = '';
        return;
      }
      const use = z || draftZone;
      selectedTitleEl.textContent = use.label || 'Regional Zone';
      selectedDescEl.textContent = use.description || 'Custom regional atmosphere.';
      selectedForecastEl.innerHTML = '';
      if (z) {
        const current = document.createElement('div');
        current.className = 'zoneRow selected';
        current.innerHTML = `
          <div class="zoneTop">
            <div>
              <div class="zoneName">Current atmosphere</div>
              <div class="zoneMeta">${esc(z.profileLabel || z.profile || 'Zone')}</div>
            </div>
            <div>${iconSvg(z.current?.icon || 'cloudy')}</div>
          </div>
          <div class="chipRow">
            <span class="chip">${esc(z.current?.condition || 'Clear')}</span>
            <span class="chip">${fmtTemp(z.current?.tempC ?? 0)}</span>
            <span class="chip">Rain ${fmtPct(z.current?.rain || 0)}</span>
            <span class="chip">Wind ${Math.round(Number(z.current?.windMph || 0))} mph</span>
          </div>
        `;
        selectedForecastEl.appendChild(current);

        (z.upcoming || []).forEach((step) => {
          const row = document.createElement('div');
          row.className = 'zoneRow';
          row.innerHTML = `
            <div class="zoneTop">
              <div>
                <div class="zoneName">${esc(step.label || 'Upcoming')}</div>
                <div class="zoneMeta">${esc(step.condition || '')}</div>
              </div>
              <div>${iconSvg(step.icon || 'cloudy')}</div>
            </div>
            <div class="chipRow">
              <span class="chip">${fmtTemp(step.tempC ?? 0)}</span>
              <span class="chip">Rain ${fmtPct(step.rain || 0)}</span>
              <span class="chip">Snow ${fmtPct(step.snow || 0)}</span>
            </div>
          `;
          selectedForecastEl.appendChild(row);
        });
      }
      syncEditor();
    }

    function renderMap(forceInvalidate = false, forceOverlay = false) {
      if (!state) return;
      const map = ensureLeafletMap();
      if (!map) {
        setMapStatus('Map framework failed to load. Check the embedded UI assets.', 'warn');
        return;
      }
      if (forceInvalidate) map.invalidateSize(false);
      const bounds = worldBounds();
      map.setMaxBounds(bounds);

      const focusWorld = draftZone ? { x: draftZone.x, y: draftZone.y } : state.player ? { x: state.player.x, y: state.player.y } : null;
      if (activeTab === 'regional' && !mapHasInitialFrame) {
        fitMapToZones(true);
        mapHasInitialFrame = true;
      }
      if (focusWorld) updateMapCoordLabel(focusWorld);
      scheduleZoneOverlayUpdate(forceInvalidate || forceOverlay);
      if (forceInvalidate) requestAnimationFrame(() => map.invalidateSize(false));
    }

    function handleMapLatLng(latlng) {
      const world = latLngToWorld(latlng);
      updateMapCoordLabel(world);
      if (!draftZone) {
        draftZone = { label: 'Regional Zone', profile: profiles[0]?.id || 'CUSTOM', r: 1600, intensity: 0.85 };
      }
      draftZone.x = world.x;
      draftZone.y = world.y;
      draftZone.label = zoneLabelEl.value || draftZone.label || 'Regional Zone';
      draftZone.profile = zoneProfileEl.value || draftZone.profile || 'CUSTOM';
      draftZone.r = Number(zoneRadiusEl.value || draftZone.r || 1600);
      draftZone.intensity = Number(zoneIntensityEl.value || draftZone.intensity || 0.85);
      renderMap();
    }
    function newZone() {
      selectedZoneId = null;
      const p = state?.player || { x: 0, y: 0 };
      draftZone = {
        label: 'Regional Zone',
        profile: profiles[0]?.id || 'CUSTOM',
        x: p.x, y: p.y,
        r: Number(zoneRadiusEl.value || 1600),
        intensity: Number(zoneIntensityEl.value || 0.85),
      };
      syncEditor();
      renderSelectedZone();
      renderMap();
      fitMapToZones(false);
      renderZoneList();
    }

    function saveZone() {
      if (!draftZone) newZone();
      draftZone.label = zoneLabelEl.value || 'Regional Zone';
      draftZone.profile = zoneProfileEl.value || 'CUSTOM';
      draftZone.r = Number(zoneRadiusEl.value || draftZone.r || 1600);
      draftZone.intensity = Number(zoneIntensityEl.value || draftZone.intensity || 0.85);
      if (draftZone.x == null || draftZone.y == null) {
        const p = state?.player || { x: 0, y: 0 };
        draftZone.x = p.x; draftZone.y = p.y;
      }
      post('azwx_zone_save', draftZone);
    }

    function deleteZone() {
      const id = Number(selectedZoneId || draftZone?.id || 0);
      if (!id) return;
      post('azwx_zone_delete', { id });
      selectedZoneId = null;
      draftZone = null;
    }

    newZoneBtn.addEventListener('click', newZone);
    saveZoneBtn.addEventListener('click', saveZone);
    deleteZoneBtn.addEventListener('click', deleteZone);
    zoneLabelEl.addEventListener('input', () => { if (draftZone) draftZone.label = zoneLabelEl.value; });
    zoneProfileEl.addEventListener('change', () => { if (draftZone) draftZone.profile = zoneProfileEl.value; });
    zoneRadiusEl.addEventListener('input', () => {
      radiusOutEl.textContent = `${Math.round(Number(zoneRadiusEl.value))}m`;
      if (draftZone) { draftZone.r = Number(zoneRadiusEl.value); renderMap(); }
    });
    zoneIntensityEl.addEventListener('input', () => {
      intensityOutEl.textContent = `${Math.round(Number(zoneIntensityEl.value) * 100)}%`;
      if (draftZone) draftZone.intensity = Number(zoneIntensityEl.value);
    });

    function payloadZones(rawState) {
      const rawZones = Array.isArray(rawState?.zones) ? rawState.zones.map(z => ({ ...z })) : [];
      if (rawZones.length) return rawZones;
      if (Array.isArray(rawState?.regional) && rawState.regional.length) {
        return rawState.regional.map((z) => ({ id: z.id, label: z.label, profile: z.profile, x: z.x, y: z.y, r: z.r, intensity: z.intensity, priority: z.priority || 0 }));
      }
      return [];
    }

    function applyPayload(payload, initial = false) {
      const nextState = payload || {};
      const nextZones = payloadZones(nextState);
      const nextProfiles = Array.isArray(nextState.profiles) ? nextState.profiles.map(p => ({ ...p })) : [{ id:'CUSTOM', label:'Custom', description:'Custom regional atmosphere.' }];
      const zonesChanged = JSON.stringify(nextZones.map((z) => [z.id, Math.round(Number(z.x || 0)), Math.round(Number(z.y || 0)), Math.round(Number(z.r || 0)), Number(z.intensity || 0), z.label || '', z.profile || '']))
        !== JSON.stringify(zones.map((z) => [z.id, Math.round(Number(z.x || 0)), Math.round(Number(z.y || 0)), Math.round(Number(z.r || 0)), Number(z.intensity || 0), z.label || '', z.profile || '']));
      const prevPlayer = state?.player || null;
      const nextPlayer = nextState?.player || null;
      const playerMoved = !prevPlayer || !nextPlayer ? prevPlayer !== nextPlayer : (Math.abs(Number(prevPlayer.x || 0) - Number(nextPlayer.x || 0)) > 10 || Math.abs(Number(prevPlayer.y || 0) - Number(nextPlayer.y || 0)) > 10);
      const profilesChanged = JSON.stringify(nextProfiles) !== JSON.stringify(profiles);

      state = nextState;
      zones = nextZones;
      profiles = nextProfiles;

      if (selectedZoneId && !zones.find((z) => Number(z.id) === Number(selectedZoneId))) {
        selectedZoneId = null;
        draftZone = null;
      }
      if (!selectedZoneId) {
        const activeRegional = Array.isArray(state.regional)
          ? state.regional.find((z) => String(z.label || '').toLowerCase() === String(state.currentRegion || '').toLowerCase())
          : null;
        if (activeRegional) selectedZoneId = activeRegional.id;
      }
      if (!selectedZoneId && zones.length) selectedZoneId = zones[0].id;

      if (selectedZoneId) {
        const saved = zones.find(z => Number(z.id) === Number(selectedZoneId));
        if (!draftZone || draftZone.id != null) draftZone = saved ? { ...saved } : draftZone;
      }

      if (profilesChanged || initial) renderProfiles();
      renderOverview();
      renderZoneList();
      renderSelectedZone();
      if (initial) show();

      requestAnimationFrame(() => {
        if (activeTab === 'regional' || initial || zonesChanged || playerMoved) {
          renderMap(initial, zonesChanged || playerMoved || initial);
        }
      });
    }

    function sevColor(sev) {
      sev = Number(sev || 3);
      if (sev <= 1) return 'var(--good)';
      if (sev === 2) return 'var(--warn)';
      if (sev === 3) return '#ff8b3d';
      return 'var(--bad)';
    }
    function pushNws(payload) {
      const card = document.createElement('div');
      card.className = 'nwsCard';
      card.innerHTML = `<div style="background:${sevColor(payload.sev)}"></div><div class="nwsBody"><div class="nwsEvent">${esc(payload.event || 'Weather Statement')}</div><div class="nwsHeadline">${esc(payload.headline || '')}</div><div class="nwsSource">${esc(payload.source || '')}</div></div>`;
      nwsStack.appendChild(card);
      const ttl = Math.max(1200, Number(payload.expiresMs || (Date.now() + 9000)) - Date.now());
      setTimeout(() => card.remove(), ttl);
    }
    function clearNws() { nwsStack.innerHTML = ''; }

    closeBtn.addEventListener('click', closeUi);
    backdrop.addEventListener('click', closeUi);
    window.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeUi(); });

    window.addEventListener('message', (e) => {
      const msg = e.data || {};
      if (msg.t === 'weather') {
        if (msg.action === 'open') applyPayload(msg.payload || msg.data || {}, true);
        if (msg.action === 'set') applyPayload(msg.payload || msg.data || {}, root.classList.contains('hidden'));
        if (msg.action === 'close') hide();
      }
      if (msg.t === 'nws') {
        if (msg.action === 'push') pushNws(msg);
        if (msg.action === 'clear') clearNws();
      }
    });

    const LS_KEY = 'azwx.layout.v3';
    function applyLayout() {
      try {
        const raw = localStorage.getItem(LS_KEY);
        if (!raw) return;
        const v = JSON.parse(raw);
        if (!v) return;
        panel.style.left = `${clamp(v.left, 8, window.innerWidth - 260)}px`;
        panel.style.top = `${clamp(v.top, 8, window.innerHeight - 200)}px`;
        panel.style.transform = 'none';
        panel.style.width = `${clamp(v.width, 980, window.innerWidth - 16)}px`;
        panel.style.height = `${clamp(v.height, 660, window.innerHeight - 16)}px`;
      } catch {}
    }
    function saveLayout() {
      const rect = panel.getBoundingClientRect();
      localStorage.setItem(LS_KEY, JSON.stringify({ left: rect.left, top: rect.top, width: rect.width, height: rect.height }));
    }

    let drag = null;
    topbar.addEventListener('mousedown', (e) => {
      if (e.target.closest('button, input, select')) return;
      const rect = panel.getBoundingClientRect();
      drag = { x: e.clientX, y: e.clientY, left: rect.left, top: rect.top };
      topbar.classList.add('dragging');
    });

    let resizeDrag = null;
    resizeHandle.addEventListener('mousedown', (e) => {
      e.preventDefault();
      const rect = panel.getBoundingClientRect();
      resizeDrag = { x: e.clientX, y: e.clientY, width: rect.width, height: rect.height, left: rect.left, top: rect.top };
    });

    window.addEventListener('mousemove', (e) => {
      if (zoneDrag && draftZone) {
        const world = screenToWorld(e.clientX, e.clientY);
        draftZone.x = world.x;
        draftZone.y = world.y;
        updateMapCoordLabel(world);
        scheduleZoneOverlayUpdate(true);
      }
      if (mapPan && !mapPan.disabled) {
        const dx = e.clientX - mapPan.startX;
        const dy = e.clientY - mapPan.startY;
        if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
          mapPan.moved = true;
          suppressMapClick = true;
        }
        mapView.tx = mapPan.tx + dx;
        mapView.ty = mapPan.ty + dy;
        applyWorldTransform();
      }
      if (drag) {
        const left = clamp(drag.left + (e.clientX - drag.x), 8, window.innerWidth - panel.offsetWidth - 8);
        const top = clamp(drag.top + (e.clientY - drag.y), 8, window.innerHeight - panel.offsetHeight - 8);
        panel.style.left = `${left}px`;
        panel.style.top = `${top}px`;
        panel.style.transform = 'none';
      }
      if (resizeDrag) {
        const width = clamp(resizeDrag.width + (e.clientX - resizeDrag.x), 980, window.innerWidth - resizeDrag.left - 8);
        const height = clamp(resizeDrag.height + (e.clientY - resizeDrag.y), 660, window.innerHeight - resizeDrag.top - 8);
        panel.style.width = `${width}px`;
        panel.style.height = `${height}px`;
        if (leafletMap) { applyWorldTransform(); }
      }
    });

    window.addEventListener('mouseup', () => {
      if (zoneDrag) {
        zoneDrag = null;
        scheduleZoneOverlayUpdate(true);
      }
      if (mapPan) {
        zoneMapCanvasEl.classList.remove('draggingMap');
        mapPan = null;
      }
      if (drag) { drag = null; topbar.classList.remove('dragging'); saveLayout(); }
      if (resizeDrag) { resizeDrag = null; saveLayout(); requestAnimationFrame(() => renderMap(true, true)); }
    });
    window.addEventListener('resize', () => { applyLayout(); renderMap(true, true); });

    (function boot() {
      applyLayout();
      setTab('overview');
      radiusOutEl.textContent = `${Math.round(Number(zoneRadiusEl.value))}m`;
      intensityOutEl.textContent = `${Math.round(Number(zoneIntensityEl.value) * 100)}%`;
      post('azwx_nws_ready', { ok: true });
      post('weather_ready', { ok: true });
      setMapStatus('Embedded map ready. Open Regional Zones to edit.', 'ok');
    })();