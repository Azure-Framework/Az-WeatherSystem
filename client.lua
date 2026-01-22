// File: no-comments-pasted.lua

local RESOURCE = GetCurrentResourceName()

Config = Config or {}
local DEBUG = (Config.Debug ~= false)

local function dprint(...)
  if not DEBUG then return end
  print("^3[az_weatherfronts]^7", ...)
end

AZW = AZW or {}

if not AZW.clamp then
  function AZW.clamp(v, a, b)
    v = tonumber(v) or a
    if v < a then return a end
    if v > b then return b end
    return v
  end
end

if not AZW.lerp then
  function AZW.lerp(a, b, t)
    t = tonumber(t) or 0.0
    return a + (b - a) * t
  end
end

if not AZW.dist2 then
  function AZW.dist2(x1, y1, x2, y2)
    local dx = (tonumber(x1) or 0.0) - (tonumber(x2) or 0.0)
    local dy = (tonumber(y1) or 0.0) - (tonumber(y2) or 0.0)
    return dx * dx + dy * dy
  end
end

if not AZW.headingDeg then
  function AZW.headingDeg(x1, y1, x2, y2)
    local dx = (tonumber(x2) or 0.0) - (tonumber(x1) or 0.0)
    local dy = (tonumber(y2) or 0.0) - (tonumber(y1) or 0.0)
    local h = math.deg(math.atan2(dy, dx))
    if h < 0.0 then h = h + 360.0 end
    return h
  end
end

local function bool(v, default)
  if v == nil then return default end
  return v == true
end

local function safeCmd(name, fallback)
  name = tostring(name or "")
  name = name:gsub("^%s+",""):gsub("%s+$","")
  name = name:gsub("^/","")
  if name == "" or name == "nil" then name = fallback end
  return name
end

local function clamp(v, a, b)
  v = tonumber(v) or a
  if v < a then return a end
  if v > b then return b end
  return v
end

local function wrap(v, minV, maxV)
  local span = (maxV - minV)
  if span <= 0.0 then return minV end
  while v < minV do v = v + span end
  while v > maxV do v = v - span end
  return v
end

local function clamp01(v)
  v = tonumber(v) or 0.0
  if v < 0.0 then return 0.0 end
  if v > 1.0 then return 1.0 end
  return v
end

local W = Config.World or { minX=-4200.0, maxX=4500.0, minY=-4200.0, maxY=8000.0 }
local KINDS = Config.Kinds or {}
Config.Commands = Config.Commands or {}
Config.PauseMap = Config.PauseMap or {}
Config.Alerts = Config.Alerts or {}
Config.Smoothing = Config.Smoothing or {}
Config.Base = Config.Base or {
  weather="CLEAR",
  rain=0.0, snow=0.0,
  windSpeed=0.0, windDirDeg=0.0,
  temperatureC=20.0
}

local fronts = {}
local paused = false
local seed = 0
local serverTime = { freeze=false, hour=nil, minute=0 }
local forecastSteps = (Config.Forecast and Config.Forecast.steps) or {30,60,120,180,300}

local overlayEnabled = false
local blips = {}
local banner = { active=false, untilMs=0, title="", msg="", sev=3 }
local gustActive = {}

local cur = {
  weather = Config.Base.weather,
  rain = Config.Base.rain,
  snow = Config.Base.snow,
  windSpeed = Config.Base.windSpeed,
  windDirDeg = Config.Base.windDirDeg,
  tempC = Config.Base.temperatureC,
  timecycle = nil,
}

local lastAlertAt = 0
local lastAlertFront = nil
local lastFrontHash = 0
local entered = {}

local nuiReady = false
local nuiQueue = {}

RegisterNUICallback("azwx_nws_ready", function(_, cb)
  nuiReady = true
  if cb then cb({ ok = true }) end
  dprint("^2NUI ready handshake received (azwx_nws_ready)^7")
end)

local function alertsUiEnabledReason()
  local a = Config.Alerts or {}
  local ui = a.ui or {}
  if bool(a.enabled, true) == false then return false, "Config.Alerts.enabled == false" end
  if bool(a.showBanner, true) == false then return false, "Config.Alerts.showBanner == false" end
  if bool(ui.enabled, true) == false then return false, "Config.Alerts.ui.enabled == false" end
  return true, "ok"
end

local function nwsSend(payload)
  local ok, why = alertsUiEnabledReason()
  if not ok then
    dprint("^1NUI blocked:^7", why)
    return
  end

  if not nuiReady then
    nuiQueue[#nuiQueue+1] = payload
    if DEBUG then dprint("^3NUI not ready; queued^7", payload and payload.action) end
  end

  pcall(function()
    SendNUIMessage(payload)
  end)
end

local function nwsInit()
  local ok = alertsUiEnabledReason()
  if not ok then return end
  nwsSend({ t="nws", action="clear" })
  nwsSend({ t="nws", action="ping" })
end

local function nwsPush(id, sev, event, headline, body, durMs, source)
  local ok = alertsUiEnabledReason()
  if not ok then return end

  sev = tonumber(sev) or 3
  durMs = tonumber(durMs) or (Config.Alerts.bannerDurationMs or 9000)
  local issued = GetGameTimer()
  local expires = issued + durMs

  nwsSend({
    t="nws",
    action="push",
    id = id or ("front_" .. tostring(GetGameTimer())),
    sev = sev,
    event = event or "Severe Weather Statement",
    headline = headline or "",
    body = body or "",
    issuedMs = issued,
    expiresMs = expires,
    source = source or ("NWS " .. ((Config.Alerts.ui and Config.Alerts.ui.office) or "Los Santos") .. " / AZWX"),
  })
end

local function nwsClear()
  local ok = alertsUiEnabledReason()
  if not ok then return end
  nwsSend({ t="nws", action="clear" })
end

CreateThread(function()
  while true do
    Wait(250)
    if nuiReady and #nuiQueue > 0 then
      if DEBUG then dprint("^2Flushing NUI queue^7 size=", #nuiQueue) end
      for i=1, #nuiQueue do
        pcall(function() SendNUIMessage(nuiQueue[i]) end)
      end
      nuiQueue = {}
    end
  end
end)

RegisterNetEvent("az_weatherfronts:nwsOffice", function(office)
  office = tostring(office or "")
  if office ~= "" then
    nwsSend({ t="nws", action="office", office = office })
  end
end)

local weatherUiOpen = false
local weatherToggleAt = 0
local WEATHER_TOGGLE_LOCK = 350

local weatherNuiReady = false
local weatherQueue = {}

RegisterNUICallback("weather_ready", function(_, cb)
  weatherNuiReady = true
  if cb then cb({ ok = true }) end
  dprint("^2NUI ready handshake received (weather_ready)^7")
end)

RegisterNUICallback("azwx_weather_close", function(_, cb)
  weatherUiOpen = false
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  if cb then cb({ ok = true }) end
  dprint("^3NUI closed (azwx_weather_close)^7")
end)

local function weatherSend(action, payload)
  local msg = { t="weather", action=action, payload=payload, data=payload }

  if not weatherNuiReady then
    weatherQueue[#weatherQueue+1] = msg
    if DEBUG then dprint("^3Weather NUI not ready; queued^7", action) end
  end

  pcall(function()
    SendNUIMessage(msg)
  end)
end

CreateThread(function()
  while true do
    Wait(200)
    if weatherNuiReady and #weatherQueue > 0 then
      if DEBUG then dprint("^2Flushing Weather NUI queue^7 size=", #weatherQueue) end
      for i=1, #weatherQueue do
        pcall(function() SendNUIMessage(weatherQueue[i]) end)
      end
      weatherQueue = {}
    end
  end
end)

local function openWeatherUi(payload)
  weatherUiOpen = true
  SetNuiFocus(true, true)
  SetNuiFocusKeepInput(false)
  weatherSend("open", payload)
  weatherSend("set", payload)
  dprint("^2Weather UI open^7")
end

local function closeWeatherUi()
  weatherUiOpen = false
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  weatherSend("close")
  dprint("^3Weather UI close^7")
end

local function biomeAt(x, y)
  if not (Config.Biomes and Config.Biomes.enabled) then return nil end
  local zones = Config.Biomes.zones or {}
  for i=1, #zones do
    local z = zones[i]
    if z and z.center and z.radius then
      local cx, cy = z.center.x, z.center.y
      local r = tonumber(z.radius) or 0.0
      if AZW.dist2(x, y, cx, cy) <= (r*r) then
        return z
      end
    end
  end
  return nil
end

local function setWeatherTypeSmooth(w)
  w = tostring(w or "CLEAR"):upper()
  if w == "" then w = "CLEAR" end
  if w == cur.weather then return end
  cur.weather = w
  SetWeatherTypeOvertimePersist(w, Config.Smoothing.weatherChangeSeconds or 8.0)
  SetWeatherTypeNowPersist(w)
  SetOverrideWeather(w)
end

local function applyTime()
  if serverTime.hour ~= nil then
    NetworkOverrideClockTime(serverTime.hour, serverTime.minute or 0, 0)
  end
end

local function setTimecycle(tc)
  if tc == cur.timecycle then return end
  cur.timecycle = tc
  if not tc then
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
  else
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    SetTimecycleModifier(tc)
    SetTimecycleModifierStrength(0.65)
  end
end

local function smooth(curv, target, t) return AZW.lerp(curv, target, t) end

local function angleLerp(a, b, t)
  local diff = (b - a + 540.0) % 360.0 - 180.0
  return a + diff * t
end

local function degToRad(d) return math.rad(d or 0.0) end

local function computeLocal(px, py, frontsOverride)
  local base = Config.Base
  local list = frontsOverride or fronts

  local bestKind = base.weather
  local bestScore = 0.0

  local rainT = base.rain
  local snowT = base.snow
  local windAddT = 0.0
  local tempT = base.temperatureC
  local lightningChance = 0.0
  local chosenTimecycle = nil
  local bestFront = nil

  for i=1, #list do
    local f = list[i]
    local k = KINDS[f.kind]
    if k then
      local d2 = AZW.dist2(px, py, f.x, f.y)
      local r = tonumber(f.r) or 2000.0
      local r2 = r * r
      if d2 <= r2 then
        local d = math.sqrt(d2)
        local t = (1.0 - (d / r))
        local intensity = AZW.clamp(f.i, 0.1, 1.0)
        local score = t * intensity

        rainT = rainT + (k.rain or 0.0) * score
        snowT = snowT + (k.snow or 0.0) * score
        windAddT = windAddT + (k.windAdd or 0.0) * score
        tempT = tempT + (k.tempAdd or 0.0) * score
        lightningChance = math.max(lightningChance, (k.lightningChance or 0.0) * score)

        if score > bestScore then
          bestScore = score
          bestKind = f.kind
          chosenTimecycle = k.timecycle
          bestFront = f
        end
      end
    end
  end

  local bio = biomeAt(px, py)
  local rainMul, snowMul, windMul = 1.0, 1.0, 1.0
  if bio then
    tempT = tempT + (tonumber(bio.tempAdd) or 0.0)
    rainMul = tonumber(bio.rainMul) or 1.0
    snowMul = tonumber(bio.snowMul) or 1.0
    windMul = tonumber(bio.windMul) or 1.0
  end

  rainT = clamp01(rainT * rainMul)
  snowT = clamp01(snowT * snowMul)

  local weather = (KINDS[bestKind] and KINDS[bestKind].baseWeather) or base.weather
  local windSpeed = AZW.clamp((base.windSpeed + windAddT) * windMul, 0.0, 12.0)

  local windDir = base.windDirDeg
  if bestFront and bestScore > 0.10 then
    local dir = math.deg(math.atan2(bestFront.vy or 0.0, bestFront.vx or 0.0))
    if dir == dir then windDir = dir end
  end

  local gExtra = 0.0
  local gDir = nil
  local inGust = false
  local now = GetGameTimer()

  for id, g in pairs(gustActive) do
    local t0 = g.t
    local t1 = g.t + g.dur
    if now >= t1 then
      gustActive[id] = nil
    else
      local dx, dy = px - g.x, py - g.y
      if (dx*dx + dy*dy) <= (g.r*g.r) then
        local p = (now - t0) / g.dur
        local amp = math.sin(p * math.pi)
        gExtra = gExtra + (g.extra * amp)
        gDir = g.dir
        inGust = true
      end
    end
  end

  if gExtra > 0.0 then
    windSpeed = AZW.clamp(windSpeed + gExtra, 0.0, 12.0)
    if gDir then windDir = gDir end
  end

  return {
    weather = weather,
    rain = rainT,
    snow = snowT,
    windSpeed = windSpeed,
    windDirDeg = windDir,
    tempC = tempT,
    lightningChance = lightningChance,
    timecycle = chosenTimecycle,
    biome = bio,
    inGust = inGust,
  }
end

local function applyLocal(target)
  setWeatherTypeSmooth(target.weather)

  cur.rain = smooth(cur.rain, target.rain, Config.Smoothing.rainLerp or 0.10)
  cur.snow = smooth(cur.snow, target.snow, Config.Smoothing.snowLerp or 0.08)
  cur.windSpeed = smooth(cur.windSpeed, target.windSpeed, Config.Smoothing.windLerp or 0.12)
  cur.windDirDeg = angleLerp(cur.windDirDeg, target.windDirDeg, Config.Smoothing.windLerp or 0.12)
  cur.tempC = smooth(cur.tempC, target.tempC, Config.Smoothing.tempLerp or 0.08)

  SetRainLevel(cur.rain)
  SetSnowLevel(cur.snow)

  SetWindSpeed(cur.windSpeed)
  SetWindDirection(degToRad(cur.windDirDeg))
  SetWind(AZW.clamp(cur.windSpeed / 12.0, 0.0, 1.0))

  if target.timecycle then setTimecycle(target.timecycle) else setTimecycle(nil) end

  SetForceVehicleTrails(cur.rain > 0.12 or cur.snow > 0.12)
  SetForcePedFootstepsTracks(cur.rain > 0.12 or cur.snow > 0.12)

  if target.lightningChance and target.lightningChance > 0.02 then
    if math.random() < target.lightningChance then
      ForceLightningFlash()
    end
  end
end

local function isNightHour(h)
  h = tonumber(h)
  if h == nil then
    h = GetClockHours()
  end
  return (h < 6 or h >= 20)
end

local function iconForWx(wx, hour)
  local rain = clamp01(wx.rain or 0.0)
  local snow = clamp01(wx.snow or 0.0)
  local wind = tonumber(wx.windSpeed or 0.0) or 0.0
  local lightning = tonumber(wx.lightningChance or 0.0) or 0.0
  local w = tostring(wx.weather or "CLEAR"):upper()

  if snow >= 0.18 then return "snow", "Snow" end
  if rain >= 0.22 and lightning >= 0.05 then return "thunder", "Thunderstorms" end
  if rain >= 0.22 then return "rain", "Rain" end
  if wind >= 9.0 then return "wind", "Windy" end

  if w == "FOGGY" or w == "SMOG" or (w == "CLOUDS" and rain < 0.10) then
    return "fog", "Fog"
  end

  if w == "OVERCAST" or w == "CLOUDS" or w == "CLOUDY" then
    return "cloudy", "Cloudy"
  end

  if rain > 0.08 then
    return "partly-day", "Scattered showers"
  end

  if isNightHour(hour) then
    return "clear-night", "Clear night"
  end
  return "clear-day", "Clear"
end

local function windToMph(ws)
  ws = tonumber(ws) or 0.0
  return math.floor((ws / 12.0) * 60.0 + 0.5)
end

local function fmtClock()
  local h = serverTime.hour
  local m = serverTime.minute or 0
  if h == nil then
    h = GetClockHours()
    m = GetClockMinutes()
  end
  return string.format("%02d:%02d", tonumber(h) or 0, tonumber(m) or 0)
end

local function projectFrontsAt(tSec)
  local minX, maxX, minY, maxY = W.minX, W.maxX, W.minY, W.maxY
  local proj = {}
  for i=1, #fronts do
    local f = fronts[i]
    local fx = (tonumber(f.x) or 0.0) + (tonumber(f.vx) or 0.0) * tSec
    local fy = (tonumber(f.y) or 0.0) + (tonumber(f.vy) or 0.0) * tSec
    fx = wrap(fx, minX, maxX)
    fy = wrap(fy, minY, maxY)

    proj[#proj+1] = {
      id = f.id, kind = f.kind, name = f.name,
      x = fx, y = fy,
      r = f.r, i = f.i,
      vx = f.vx, vy = f.vy,
      sev = f.sev, sevLabel = f.sevLabel
    }
  end
  return proj
end

local function buildWeeklyForecastPayload(px, py)
  local days = {}
  local hourSec = 3600.0

  local baseHour = serverTime.hour
  if baseHour == nil then baseHour = GetClockHours() end

  local hiAll, loAll = -1e9, 1e9

  for i=0, 6 do
    local tSec = i * hourSec
    local proj = projectFrontsAt(tSec)
    local wx = computeLocal(px, py, proj)

    local icon, cond = iconForWx(wx, (baseHour + (i * 3)) % 24)
    local tempC = tonumber(wx.tempC or 0.0) or 0.0
    local hi = math.floor(tempC + 1.6 + 0.5)
    local lo = math.floor(tempC - 2.4 + 0.5)

    if hi > hiAll then hiAll = hi end
    if lo < loAll then loAll = lo end

    local rainP = clamp01(wx.rain or 0.0)
    local snowP = clamp01(wx.snow or 0.0)

    days[#days+1] = {
      label = ("Day %d"):format(i+1),
      icon = icon,
      condition = cond,
      detail = (rainP >= 0.20 and "Likely rain") or (snowP >= 0.18 and "Likely snow") or (tonumber(wx.windSpeed or 0) >= 9.0 and "Strong winds") or "Stable",
      tempC = tempC,
      temp = ("%.1f"):format(tempC),
      hi = tostring(hi),
      lo = tostring(lo),
      rain = rainP,
      snow = snowP,
      windMph = windToMph(wx.windSpeed),
      windDirDeg = math.floor((tonumber(wx.windDirDeg or 0.0) or 0.0) + 0.5),
      note = "Storm zones evolve as fronts move."
    }
  end

  local nowWx = computeLocal(px, py, fronts)
  local icon, cond = iconForWx(nowWx, baseHour)
  local tempC = tonumber(nowWx.tempC or 0.0) or 0.0
  local now = {
    icon = icon,
    condition = cond,
    summary = "Forecast at your current position",
    tempC = tempC,
    rain = clamp01(nowWx.rain or 0.0),
    snow = clamp01(nowWx.snow or 0.0),
    windMph = windToMph(nowWx.windSpeed),
    windDirDeg = math.floor((tonumber(nowWx.windDirDeg or 0.0) or 0.0) + 0.5),
  }

  local location = (Config.WeatherApp and Config.WeatherApp.locationName) or "Los Santos"
  local model = "Dynamic fronts"

  return {
    location = location,
    subtitle = "Weekly forecast • 1 hour = 24 hours",
    clock = fmtClock(),
    model = model,
    now = now,
    days = days,
    weekly = { hi=tostring(hiAll), lo=tostring(loAll) }
  }
end

local function findNearestAlertable(px, py)
  local minSev = (Config.Alerts and Config.Alerts.minSeverity) or 3
  local best, bestD2, bestInside = nil, 1e18, false

  for i=1, #fronts do
    local f = fronts[i]
    local r = tonumber(f.r) or 0.0
    local d2 = AZW.dist2(px, py, f.x, f.y)
    local inside = (r > 0.0) and (d2 <= (r*r))
    local sevOk = (tonumber(f.sev) or 1) >= minSev

    if inside or sevOk then
      if d2 < bestD2 then
        best = f
        bestD2 = d2
        bestInside = inside
      end
    end
  end

  return best, bestD2, bestInside
end

local function kindSpawnSev(kind, intensity)
  kind = tostring(kind or "WX"):upper()
  intensity = tonumber(intensity) or 0.8
  if kind == "BLIZZARD" then return 4 end
  if kind == "STORM" then return intensity >= 0.85 and 4 or 3 end
  if kind == "RAIN" then return intensity >= 0.85 and 4 or 3 end
  if kind == "SUPER_WIND" then return 4 end
  if kind == "SUPER_HEAT" then return 3 end
  if kind == "SUPER_COLD" then return 3 end
  if kind == "SNOW" then return 3 end
  return 3
end

local function eventTitleFromKind(kind, sev)
  kind = tostring(kind or "WX"):upper()
  sev = tonumber(sev) or 3
  if kind == "BLIZZARD" then return "BLIZZARD WARNING" end
  if kind == "SNOW" then return sev >= 3 and "WINTER WEATHER ADVISORY" or "WINTER WEATHER STATEMENT" end
  if kind == "STORM" then return sev >= 4 and "SEVERE THUNDERSTORM WARNING" or "SEVERE THUNDERSTORM WATCH" end
  if kind == "RAIN" then return sev >= 4 and "FLASH FLOOD WARNING" or "FLOOD ADVISORY" end
  if kind == "SUPER_WIND" then return sev >= 4 and "HIGH WIND WARNING" or "WIND ADVISORY" end
  if kind == "SUPER_HEAT" then return sev >= 4 and "EXCESSIVE HEAT WARNING" or "HEAT ADVISORY" end
  if kind == "SUPER_COLD" then return sev >= 4 and "WIND CHILL WARNING" or "COLD WEATHER ADVISORY" end
  return "WEATHER ADVISORY"
end

local function resetGatesWhenSafe(px, py)
  local buffer = (Config.Alerts and Config.Alerts.bufferMeters) or 550.0
  for fid, g in pairs(entered) do
    local f = nil
    for i=1, #fronts do
      if tonumber(fronts[i].id) == tonumber(fid) then f = fronts[i] break end
    end
    if not f then
      entered[fid] = nil
    else
      local d2 = AZW.dist2(px, py, f.x, f.y)
      local dist = math.sqrt(d2)
      local r = tonumber(f.r) or 0.0
      local inside = (r > 0.0) and (dist <= r)
      local near = (dist <= (r + buffer))
      if not inside then g.inside = false end
      if not near then g.nearby = false end
    end
  end
end

local function showAlert(front, dist, inside)
  if not (Config.Alerts and bool(Config.Alerts.enabled, true)) then return end

  local fid = tonumber(front and front.id or 0) or 0
  if fid <= 0 then return end

  entered[fid] = entered[fid] or { inside=false, nearby=false }
  local gate = entered[fid]

  if inside then
    if gate.inside then return end
    gate.inside = true
  else
    if gate.nearby then return end
    gate.nearby = true
  end

  local now = GetGameTimer()
  local cooldown = (Config.Alerts and Config.Alerts.cooldownMs) or 15000
  if (now - lastAlertAt) < cooldown and lastAlertFront == fid then
    return
  end

  lastAlertAt = now
  lastAlertFront = fid

  local title = eventTitleFromKind(front.kind, front.sev)
  local msg = ("%s: %s (%s) %s • %.0fm away"):format(
    title,
    tostring(front.name or ("#"..tostring(front.id))),
    tostring(front.sevLabel or "Severe"),
    inside and "OVERHEAD" or "NEARBY",
    dist
  )

  if Config.Alerts.showChat then
    TriggerEvent("chat:addMessage", { args = { "^1WX ALERT^7", msg } })
  end

  if bool(Config.Alerts.showBanner, true) then
    local id = "front_" .. tostring(front.id or "0")
    local headline = ("%s • %s"):format(
      tostring(front.name or ("#"..tostring(front.id))),
      inside and "OVERHEAD" or "NEARBY"
    )

    local body = ("Type: %s\nSeverity: %s (%d)\nDistance: %.0fm\nRadius: %.0fm")
      :format(
        tostring(front.kind or "WX"),
        tostring(front.sevLabel or "Severe"),
        tonumber(front.sev) or 0,
        tonumber(dist) or 0,
        tonumber(front.r) or 0
      )

    nwsPush(
      id,
      tonumber(front.sev) or 3,
      title,
      headline,
      body,
      (Config.Alerts.bannerDurationMs or 9000),
      ("NWS " .. ((Config.Alerts.ui and Config.Alerts.ui.office) or "Los Santos") .. " / AZWX")
    )

    if Config.Alerts.drawBanner then
      banner.active = true
      banner.untilMs = now + (Config.Alerts.bannerDurationMs or 9000)
      banner.title = title
      banner.msg = headline
      banner.sev = tonumber(front.sev) or 3
    end
  end

  if Config.Alerts.sound and Config.Alerts.sound.enabled then
    pcall(function()
      PlaySoundFrontend(-1, Config.Alerts.sound.name or "5_SEC_WARNING", Config.Alerts.sound.set or "HUD_MINI_GAME_SOUNDSET", true)
    end)
  end
end

local function clearAlert()
  banner.active = false
  nwsClear()
end

local function openPauseMenu()
  if not (Config.PauseMap and Config.PauseMap.openPauseMenu) then return end
  pcall(function()
    ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_MP_PAUSE"), false, -1)
  end)
end

local function blipDisplayValue()
  local pm = Config.PauseMap or {}
  if pm.showOnRadar then return 2 end
  return 3
end

local function pmBool(pm, key, default)
  local v = pm[key]
  if v == nil then return default end
  return v == true
end

local function pmNum(pm, key, default)
  local v = tonumber(pm[key])
  if v == nil then return default end
  return v
end

local function isStormKind(kind)
  kind = tostring(kind or ""):upper()
  return (kind == "STORM" or kind == "RAIN" or kind == "BLIZZARD" or kind == "SNOW" or kind == "SUPER_WIND")
end

local function cleanupFrontBlips(frontId)
  local b = blips[frontId]
  if not b then return end

  if b.center and DoesBlipExist(b.center) then RemoveBlip(b.center) end
  if b.radius and DoesBlipExist(b.radius) then RemoveBlip(b.radius) end

  if b.forecast then
    for i=1, #b.forecast do
      local h = b.forecast[i]
      if h and DoesBlipExist(h) then RemoveBlip(h) end
    end
  end

  if b.dir then
    for i=1, #b.dir do
      local h = b.dir[i]
      if h and DoesBlipExist(h) then RemoveBlip(h) end
    end
  end

  blips[frontId] = nil
end

local function setBlipName(handle, text)
  if not (handle and DoesBlipExist(handle)) then return end
  BeginTextCommandSetBlipName("STRING")
  AddTextComponentString(tostring(text or ""))
  EndTextCommandSetBlipName(handle)
end

local function projectCoordForFront(f, tSec)
  local minX, maxX, minY, maxY = W.minX, W.maxX, W.minY, W.maxY
  local fx = (tonumber(f.x) or 0.0) + (tonumber(f.vx) or 0.0) * tSec
  local fy = (tonumber(f.y) or 0.0) + (tonumber(f.vy) or 0.0) * tSec
  fx = wrap(fx, minX, maxX)
  fy = wrap(fy, minY, maxY)
  return fx, fy
end

local function ensureFrontBlips(f)
  local pm = Config.PauseMap or {}
  blips[f.id] = blips[f.id] or { forecast = {}, dir = {} }
  local b = blips[f.id]

  local display = blipDisplayValue()

  local showRadius   = (pm.showRadius ~= false)
  local showCenter   = (pm.showCenter ~= false)
  local showForecast = (pm.showForecast ~= false)
  local showDir      = (pm.showDirection ~= false)

  local forecastOnlyStorms = pmBool(pm, "forecastOnlyStorms", false)
  if forecastOnlyStorms and not isStormKind(f.kind) then
    showForecast = false
    showDir = false
  end

  local color  = tonumber((pm.colors and pm.colors[f.kind]) or pm.colorsDefault or 1) or 1
  local sprite = tonumber((pm.sprites and pm.sprites[f.kind]) or pm.spriteDefault or 1) or 1

  local radiusAlpha   = pmNum(pm, "radiusAlpha", 120)
  local centerAlpha   = pmNum(pm, "centerAlpha", 255)
  local centerScale   = pmNum(pm, "centerScale", 0.80)

  local forecastAlpha  = pmNum(pm, "forecastAlpha", 180)
  local forecastScale  = pmNum(pm, "forecastScale", 0.55)
  local forecastSprite = tonumber(pm.forecastSprite) or sprite
  local stepsAreMinutes = (pm.forecastStepsAreMinutes ~= false)
  local maxForecast = math.floor(pmNum(pm, "maxForecast", 4))
  if maxForecast < 0 then maxForecast = 0 end

  local dirAlpha      = pmNum(pm, "dirAlpha", 210)
  local dirScale      = pmNum(pm, "dirScale", 0.50)
  local dirCount      = math.floor(pmNum(pm, "dirCount", 3))
  local dirSpacingMul = pmNum(pm, "dirSpacingMul", 0.20)

  local rMeters = tonumber(f.r) or 2000.0

  if showRadius then
    if not (b.radius and DoesBlipExist(b.radius)) then
      b.radius = AddBlipForRadius(f.x, f.y, 0.0, rMeters)
      SetBlipDisplay(b.radius, display)
      SetBlipColour(b.radius, color)
      SetBlipAlpha(b.radius, radiusAlpha)
      SetBlipHighDetail(b.radius, true)
    end
  else
    if b.radius and DoesBlipExist(b.radius) then RemoveBlip(b.radius) end
    b.radius = nil
  end

  if showCenter then
    if not (b.center and DoesBlipExist(b.center)) then
      b.center = AddBlipForCoord(f.x, f.y, 0.0)
      SetBlipDisplay(b.center, display)
      SetBlipSprite(b.center, sprite)
      SetBlipScale(b.center, centerScale)
      SetBlipColour(b.center, color)
      SetBlipAlpha(b.center, centerAlpha)
      SetBlipAsShortRange(b.center, not pm.showOnRadar)
      SetBlipHighDetail(b.center, true)
    end

    local label = (f.name or ("#"..tostring(f.id))) .. " · " .. tostring(f.kind) .. " · " .. tostring(f.sevLabel or "")
    setBlipName(b.center, label)
  else
    if b.center and DoesBlipExist(b.center) then RemoveBlip(b.center) end
    b.center = nil
  end

  if showForecast and maxForecast > 0 then
    local steps = forecastSteps or {}
    local made = 0

    for i=1, #steps do
      if made >= maxForecast then break end
      local step = tonumber(steps[i] or 0) or 0
      if step > 0 then
        made = made + 1
        local tSec = stepsAreMinutes and (step * 60.0) or step
        local fx, fy = projectCoordForFront(f, tSec)

        if not (b.forecast[made] and DoesBlipExist(b.forecast[made])) then
          b.forecast[made] = AddBlipForCoord(fx, fy, 0.0)
          SetBlipDisplay(b.forecast[made], display)
          SetBlipSprite(b.forecast[made], forecastSprite)
          SetBlipScale(b.forecast[made], forecastScale)
          SetBlipColour(b.forecast[made], color)
          SetBlipAlpha(b.forecast[made], forecastAlpha)
          SetBlipAsShortRange(b.forecast[made], not pm.showOnRadar)
          SetBlipHighDetail(b.forecast[made], true)
        else
          SetBlipCoords(b.forecast[made], fx, fy, 0.0)
        end

        setBlipName(b.forecast[made], ("+%sm"):format(tostring(step)))
      end
    end

    for j=made+1, #b.forecast do
      local h = b.forecast[j]
      if h and DoesBlipExist(h) then RemoveBlip(h) end
      b.forecast[j] = nil
    end
  else
    if b.forecast then
      for i=1, #b.forecast do
        local h = b.forecast[i]
        if h and DoesBlipExist(h) then RemoveBlip(h) end
      end
    end
    b.forecast = {}
  end

  if showDir and dirCount > 0 then
    local vx = tonumber(f.vx) or 0.0
    local vy = tonumber(f.vy) or 0.0
    local mag = math.sqrt(vx*vx + vy*vy)

    if mag > 0.001 then
      local ux, uy = vx / mag, vy / mag
      local spacing = rMeters * dirSpacingMul
      local made = 0

      for i=1, dirCount do
        local d = spacing * i
        local dx = f.x + ux * d
        local dy = f.y + uy * d
        made = made + 1

        if not (b.dir[made] and DoesBlipExist(b.dir[made])) then
          b.dir[made] = AddBlipForCoord(dx, dy, 0.0)
          SetBlipDisplay(b.dir[made], display)
          SetBlipSprite(b.dir[made], forecastSprite)
          SetBlipScale(b.dir[made], dirScale)
          SetBlipColour(b.dir[made], color)
          SetBlipAlpha(b.dir[made], dirAlpha)
          SetBlipAsShortRange(b.dir[made], not pm.showOnRadar)
          SetBlipHighDetail(b.dir[made], true)
        else
          SetBlipCoords(b.dir[made], dx, dy, 0.0)
        end

        setBlipName(b.dir[made], "Direction")
      end

      for j=made+1, #b.dir do
        local h = b.dir[j]
        if h and DoesBlipExist(h) then RemoveBlip(h) end
        b.dir[j] = nil
      end
    else
      if b.dir then
        for i=1, #b.dir do
          local h = b.dir[i]
          if h and DoesBlipExist(h) then RemoveBlip(h) end
        end
      end
      b.dir = {}
    end
  else
    if b.dir then
      for i=1, #b.dir do
        local h = b.dir[i]
        if h and DoesBlipExist(h) then RemoveBlip(h) end
      end
    end
    b.dir = {}
  end
end

local function updateFrontBlips(f)
  local b = blips[f.id]
  if not b then return end
  if b.center and DoesBlipExist(b.center) then SetBlipCoords(b.center, f.x, f.y, 0.0) end
  if b.radius and DoesBlipExist(b.radius) then SetBlipCoords(b.radius, f.x, f.y, 0.0) end
end

local function rebuildOverlayBlips()
  if not overlayEnabled then
    local keys = {}
    for id,_ in pairs(blips) do keys[#keys+1] = id end
    for i=1, #keys do cleanupFrontBlips(keys[i]) end
    return
  end

  local alive = {}
  for i=1, #fronts do
    local f = fronts[i]
    alive[f.id] = true
    ensureFrontBlips(f)
    updateFrontBlips(f)
  end

  local keys = {}
  for id,_ in pairs(blips) do keys[#keys+1] = id end
  for i=1, #keys do
    local id = keys[i]
    if not alive[id] then cleanupFrontBlips(id) end
  end
end

local CMD_WXMAP   = safeCmd((Config.PauseMap and Config.PauseMap.command) or Config.Commands.wxmap, "wxmap")
local CMD_TRACK   = safeCmd(Config.Commands.track,  "wxtrack")
local CMD_STATUS  = safeCmd(Config.Commands.status, "wxstatus")
local CMD_POS     = safeCmd(Config.Commands.pos,    "wxpos")
local CMD_WEATHER = safeCmd(Config.Commands.weather,"weather")
local CMD_TEST    = safeCmd(Config.Commands.testalert,"wxtestalert")

RegisterCommand(CMD_WXMAP, function()
  overlayEnabled = not overlayEnabled
  if overlayEnabled then openPauseMenu() end
  rebuildOverlayBlips()
  TriggerEvent("chat:addMessage", { args = { "^2wx^7", overlayEnabled and "Pause-map WX overlay: ON" or "Pause-map WX overlay: OFF" } })
end, false)

RegisterCommand(CMD_TRACK, function()
  local ped = PlayerPedId()
  local p = GetEntityCoords(ped)

  local best, bestD2 = nil, 1e18
  for i=1, #fronts do
    local f = fronts[i]
    local d2 = AZW.dist2(p.x, p.y, f.x, f.y)
    if d2 < bestD2 then bestD2 = d2; best = f end
  end

  if not best then
    TriggerEvent("chat:addMessage", { args = { "^2wx^7", "No fronts active." } })
    return
  end

  local d = math.sqrt(bestD2)
  local heading = AZW.headingDeg(p.x, p.y, best.x, best.y)
  local msg = ("Nearest: %s | %s | sev=%s (%d) | dist=%.0fm heading=%.0f° r=%.0f i=%.2f")
    :format(best.kind, best.name or ("#"..best.id), best.sevLabel or "?", best.sev or 0, d, heading, best.r, best.i)

  TriggerEvent("chat:addMessage", { args = { "^2wx^7", msg } })
end, false)

RegisterCommand(CMD_STATUS, function()
  local ped = PlayerPedId()
  local p = GetEntityCoords(ped)
  local localWx = computeLocal(p.x, p.y)
  local bio = localWx.biome and (" biome="..tostring(localWx.biome.label)) or ""
  local msg = ("fronts=%d local=%s rain=%.2f snow=%.2f wind=%.1f dir=%.0f temp=%.1fC%s")
    :format(#fronts, localWx.weather, localWx.rain, localWx.snow, localWx.windSpeed, localWx.windDirDeg, localWx.tempC, bio)
  TriggerEvent("chat:addMessage", { args = { "^2wx^7", msg } })
end, false)

RegisterCommand(CMD_POS, function()
  local ped = PlayerPedId()
  local p = GetEntityCoords(ped)
  local msg = ("Coords: x=%.1f y=%.1f z=%.1f"):format(p.x, p.y, p.z)
  TriggerEvent("chat:addMessage", { args = { "^2wx^7", msg } })
  print(("[az_weatherfronts] %s"):format(msg))
end, false)

RegisterCommand(CMD_TEST, function()
  nwsPush(
    "test_"..tostring(GetGameTimer()),
    4,
    "SEVERE THUNDERSTORM WARNING",
    "THIS IS A TEST • TOP CENTER • NWS STYLE",
    "If you see this, NUI is loaded and receiving messages.",
    10000,
    "NWS Los Santos / AZWX"
  )
end, false)

RegisterCommand(CMD_WEATHER, function()
  local now = GetGameTimer()
  if (now - weatherToggleAt) < WEATHER_TOGGLE_LOCK then return end
  weatherToggleAt = now

  dprint("^2/weather used^7 paused=", paused, " uiOpen=", weatherUiOpen, " nuiReady=", weatherNuiReady)

  if paused then
    TriggerEvent("chat:addMessage", { args = { "^2weather^7", "Weather is paused by server." } })
    return
  end

  if weatherUiOpen then
    closeWeatherUi()
    return
  end

  local ped = PlayerPedId()
  local p = GetEntityCoords(ped)
  local payload = buildWeeklyForecastPayload(p.x, p.y)
  openWeatherUi(payload)
end, false)

RegisterNetEvent("az_weatherfronts:state", function(s)
  paused = s.paused or false
  seed = s.seed or seed
  fronts = s.fronts or {}
  serverTime = s.time or serverTime
  forecastSteps = s.forecastSteps or forecastSteps

  if s.gusts then
    for _,g in ipairs(s.gusts) do
      gustActive[g.id] = g
    end
  end

  if overlayEnabled then rebuildOverlayBlips() end

  if Config.Alerts and bool(Config.Alerts.enabled, true) and (Config.Alerts.instantOnState ~= false) then
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)

    local hash = 0
    for i=1, #fronts do
      local f = fronts[i]
      hash = (hash + (tonumber(f.id) or 0) * 97 + math.floor((tonumber(f.x) or 0) * 0.1) + math.floor((tonumber(f.y) or 0) * 0.1)) % 2147483000
    end

    if hash ~= lastFrontHash then
      lastFrontHash = hash
      local f, d2, inside = findNearestAlertable(p.x, p.y)
      if f then
        local dist = math.sqrt(d2)
        local buffer = (Config.Alerts.bufferMeters or 550.0)
        local r = tonumber(f.r) or 0.0
        if inside or dist <= (r + buffer) then
          showAlert(f, dist, inside)
        end
      end
    end
  end

  if weatherUiOpen then
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local payload = buildWeeklyForecastPayload(p.x, p.y)
    weatherSend("set", payload)
  end
end)

RegisterNetEvent("az_weatherfronts:gust", function(g)
  gustActive[g.id] = g
  if Config.Gusts and Config.Gusts.camShake then
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local dx, dy = p.x - g.x, p.y - g.y
    if (dx*dx + dy*dy) <= (g.r*g.r) then
      ShakeGameplayCam(Config.Gusts.camShakeName, Config.Gusts.camShakeAmp)
    end
  end
end)

RegisterNetEvent("az_weatherfronts:spawnAtMe", function(args)
  local ped = PlayerPedId()
  local p = GetEntityCoords(ped)

  local kind = tostring(args[1] or "STORM"):upper()
  local radius = tonumber(args[2] or 2200) or 2200
  local intensity = tonumber(args[3] or 0.9) or 0.9
  local speed = tonumber(args[4] or 16.0) or 16.0
  local name = args[5]

  TriggerServerEvent("az_weatherfronts:spawnHere", kind, p.x, p.y, radius, intensity, speed, name)

  local sev = kindSpawnSev(kind, intensity)
  local title = eventTitleFromKind(kind, sev)
  local headline = ("New event spawned at your location • %s"):format(tostring(name or kind))
  local body = ("Type: %s\nIntensity: %.2f\nRadius: %.0fm\nMotion speed: %.1f")
    :format(kind, intensity, radius, speed)

  nwsPush(
    "spawn_" .. tostring(GetGameTimer()),
    sev,
    title,
    headline,
    body,
    (Config.Alerts and Config.Alerts.bannerDurationMs) or 9000,
    ("NWS " .. ((Config.Alerts and Config.Alerts.ui and Config.Alerts.ui.office) or "Los Santos") .. " / AZWX")
  )
end)

local function sevRgb(sev)
  sev = tonumber(sev) or 3
  if sev <= 1 then return 48, 209, 88 end
  if sev == 2 then return 255, 196, 0 end
  if sev == 3 then return 255, 128, 0 end
  if sev == 4 then return 255, 56, 56 end
  return 181, 62, 255
end

CreateThread(function()
  while true do
    Wait(0)
    if (Config.Alerts and Config.Alerts.drawBanner) and banner.active then
      local now = GetGameTimer()
      if now > (banner.untilMs or 0) then
        banner.active = false
      else
        local r,g,b = sevRgb(banner.sev)
        local x, y = 0.5, 0.035
        local w, h = 0.78, 0.06
        DrawRect(x, y, w, h, 10, 10, 10, 210)
        DrawRect(x, y - (h/2) + 0.004, w, 0.008, r, g, b, 220)

        SetTextFont(4)
        SetTextScale(0.0, 0.40)
        SetTextColour(255, 255, 255, 255)
        SetTextCentre(true)
        BeginTextCommandDisplayText("STRING")
        AddTextComponentString(banner.title or "WEATHER ALERT")
        EndTextCommandDisplayText(0.5, 0.018)

        SetTextFont(0)
        SetTextScale(0.0, 0.32)
        SetTextColour(220, 230, 240, 245)
        SetTextCentre(true)
        BeginTextCommandDisplayText("STRING")
        AddTextComponentString(banner.msg or "")
        EndTextCommandDisplayText(0.5, 0.042)
      end
    end
  end
end)

CreateThread(function()
  Wait(750)
  TriggerServerEvent("az_weatherfronts:request")
  nwsInit()
  math.randomseed(GetGameTimer())

  while true do
    Wait(tonumber(Config.ClientApplyMs) or 900)

    applyTime()

    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)

    if paused then
      clearAlert()
      if overlayEnabled then rebuildOverlayBlips() end
      goto continue
    end

    local target = computeLocal(p.x, p.y)
    applyLocal(target)

    if overlayEnabled then rebuildOverlayBlips() end

    if Config.Alerts and bool(Config.Alerts.enabled, true) then
      resetGatesWhenSafe(p.x, p.y)

      local f, d2, inside = findNearestAlertable(p.x, p.y)
      if f then
        local dist = math.sqrt(d2)
        local buffer = (Config.Alerts.bufferMeters or 550.0)
        local r = tonumber(f.r) or 0.0
        if inside or dist <= (r + buffer) then
          showAlert(f, dist, inside)
        else
          clearAlert()
        end
      else
        clearAlert()
      end
    end

    if weatherUiOpen then
      local payload = buildWeeklyForecastPayload(p.x, p.y)
      weatherSend("set", payload)
    end

    ::continue::
  end
end)