
local RESOURCE = GetCurrentResourceName()

Config = Config or {}




Config.Debug = (Config.Debug ~= false)

Config.World = Config.World or {
  
  minX = -4200.0,
  maxX =  4500.0,
  minY = -4200.0,
  maxY =  8000.0,
}

Config.Forecast = Config.Forecast or {}
Config.Forecast.steps = Config.Forecast.steps or { 30, 60, 120, 180, 300 } 

Config.ServerTickMs = tonumber(Config.ServerTickMs) or 1000
Config.MaxFronts = tonumber(Config.MaxFronts) or 12

Config.SpawnLimits = Config.SpawnLimits or {
  allowPlayers = true,
  allowConsole = true,
  maxRadius = 6500.0,
  minRadius = 250.0,
  maxIntensity = 1.0,
  minIntensity = 0.10,
  maxSpeed = 60.0,
  minSpeed = 0.0,
}


Config.Time = Config.Time or {
  enabled = true,
  freeze = false,
  realtime = true,
  useSystemTime = true,
  hour = nil,
  minute = 0,
  timezoneOffsetMinutes = nil,
}
Config.Time.useSystemTime = (Config.Time.useSystemTime ~= false)
if Config.Time.realtime == nil then
  Config.Time.realtime = Config.Time.useSystemTime
end

Config.Sync = Config.Sync or {
  time = true,
  weather = true,
  weatherMode = "global",
  clearFrontsInGlobalMode = true,
}


Config.Kinds = Config.Kinds or {
  STORM      = { label="Storm",      defaultRadius=2600.0 },
  RAIN       = { label="Heavy Rain", defaultRadius=2400.0 },
  BLIZZARD   = { label="Blizzard",   defaultRadius=2800.0 },
  SNOW       = { label="Snow",       defaultRadius=2400.0 },
  SUPER_WIND = { label="High Wind",  defaultRadius=3000.0 },
  SUPER_HEAT = { label="Heat",       defaultRadius=3000.0 },
  SUPER_COLD = { label="Cold",       defaultRadius=3000.0 },
}




Config.SystemWeather = Config.SystemWeather or Config.RealWeather or {
  enabled = true,
  provider = "nws",
  lat = 34.0522,
  lon = -118.2437,
  refreshMinutes = 10,
  userAgent = "FiveM-az_weatherfronts (admin@yourdomain.tld)",
}
Config.RealWeather = Config.SystemWeather

local fronts, gusts, serverWeatherState, real


local function dprint(...)
  if not Config.Debug then return end
  print(("^3[%s]^7"):format(RESOURCE), ...)
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

local function safeCmd(name, fallback)
  name = tostring(name or "")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  name = name:gsub("^/", "")
  if name == "" or name == "nil" then name = fallback end
  return name
end


local function bool(v, default)
  if v == nil then return default end
  return v == true
end

local function syncCfg()
  return Config.Sync or {}
end

local function syncTimeEnabled()
  return bool(syncCfg().time, true)
end

local function syncWeatherEnabled()
  return bool(syncCfg().weather, true)
end

local function regionalWeatherEnabled()
  return bool((Config.RegionalWeather or {}).enabled, true)
end

local function systemWeatherEnabled()
  return bool((Config.SystemWeather or Config.RealWeather or {}).enabled, false)
end

local function weatherMode()
  return tostring(syncCfg().weatherMode or "global"):lower()
end

local function isGlobalWeatherMode()
  return weatherMode() == "global"
end

local function canUseSystemWeather()
  return syncWeatherEnabled() and isGlobalWeatherMode() and systemWeatherEnabled()
end

local function clearWeatherRuntimeState()
  serverWeatherState = nil
  real.nextRefreshAt = 0
  if #fronts > 0 then fronts = {} end
  gusts = {}
end

local function getSystemTimeParts()
  local tcfg = Config.Time or {}
  local tz = tcfg.timezoneOffsetMinutes
  local clock
  if tz ~= nil then
    clock = os.date("!*t", os.time() + (tonumber(tz) or 0) * 60)
  else
    clock = os.date("*t")
  end
  return clamp(clock.hour or 12, 0, 23), clamp(clock.min or 0, 0, 59)
end

local function cardinalToDeg(s)
  s = tostring(s or ""):upper():gsub("[^NSEW]", "")
  local map = {
    N=0, NNE=22.5, NE=45, ENE=67.5,
    E=90, ESE=112.5, SE=135, SSE=157.5,
    S=180, SSW=202.5, SW=225, WSW=247.5,
    W=270, WNW=292.5, NW=315, NNW=337.5,
  }
  return map[s] or 180.0
end

local function parseWindMph(textValue)
  local nums = {}
  for n in tostring(textValue or ""):gmatch("(%d+)") do
    nums[#nums+1] = tonumber(n)
  end
  if #nums == 0 then return 0.0 end
  if #nums == 1 then return nums[1] end
  return (nums[1] + nums[#nums]) / 2.0
end

local function mphToGameWind(mph)
  mph = tonumber(mph) or 0.0
  return clamp(mph / 5.0, 0.0, 12.0)
end

local function fToC(f)
  return ((tonumber(f) or 32.0) - 32.0) * (5.0 / 9.0)
end

local function kindState(kind, intensity)
  local base = Config.Base or {}
  local k = (Config.Kinds or {})[tostring(kind or "CLEAR"):upper()] or {}
  intensity = clamp(intensity or 1.0, 0.0, 1.0)
  return {
    weather = tostring(k.baseWeather or base.weather or "CLEAR"):upper(),
    rain = clamp((tonumber(k.rain) or 0.0) * intensity, 0.0, 1.0),
    snow = clamp((tonumber(k.snow) or 0.0) * intensity, 0.0, 1.0),
    windSpeed = clamp((tonumber(base.windSpeed) or 0.0) + ((tonumber(k.windAdd) or 0.0) * intensity), 0.0, 12.0),
    windDirDeg = tonumber(base.windDirDeg) or 180.0,
    temperatureC = (tonumber(base.temperatureC) or 18.0) + ((tonumber(k.tempAdd) or 0.0) * intensity),
    lightningChance = clamp((tonumber(k.lightningChance) or 0.0) * intensity, 0.0, 1.0),
    timecycle = k.timecycle,
    kind = tostring(kind or "CLEAR"):upper(),
  }
end

local function mapForecastToWeather(period)
  local short = tostring(period and (period.shortForecast or period.name) or "")
  local text = short:lower()
  local isDay = not not (period and period.isDaytime)
  local temp = tonumber(period and period.temperature) or 64
  local tempUnit = tostring(period and period.temperatureUnit or "F"):upper()
  local windMph = parseWindMph(period and period.windSpeed)
  local windDirDeg = cardinalToDeg(period and period.windDirection)

  local state
  if text:find("thunder") then
    state = kindState("STORM", text:find("severe") and 1.0 or 0.90)
  elseif text:find("blizzard") then
    state = kindState("BLIZZARD", 1.0)
  elseif text:find("snow") or text:find("flurr") or text:find("sleet") or text:find("wintry") or text:find("ice") then
    state = kindState("SNOW", text:find("heavy") and 0.95 or 0.75)
  elseif text:find("rain") or text:find("shower") or text:find("drizzle") then
    state = kindState("RAIN", text:find("heavy") and 0.90 or 0.70)
  elseif text:find("fog") or text:find("mist") or text:find("haze") or text:find("smoke") then
    state = kindState("CLEAR", 0.0)
    state.weather = "FOGGY"
    state.kind = "FOG"
  elseif text:find("overcast") or text:find("mostly cloudy") then
    state = kindState("CLEAR", 0.0)
    state.weather = "OVERCAST"
    state.kind = "CLOUDS"
  elseif text:find("cloud") then
    state = kindState("CLEAR", 0.0)
    state.weather = "CLOUDS"
    state.kind = "CLOUDS"
  elseif text:find("wind") and windMph >= 30 then
    state = kindState("SUPER_WIND", 0.85)
  else
    state = kindState("CLEAR", 0.0)
    state.weather = isDay and "EXTRASUNNY" or "CLEAR"
  end

  state.temperatureC = tempUnit == "F" and fToC(temp) or tonumber(temp) or state.temperatureC
  state.windSpeed = mphToGameWind(windMph)
  state.windDirDeg = windDirDeg
  state.sourceForecast = short
  return state
end

local function nowMs()
  return GetGameTimer()
end

local function kindSev(kind, intensity)
  kind = tostring(kind or "WX"):upper()
  intensity = tonumber(intensity) or 0.8

  if kind == "BLIZZARD" then return 4 end
  if kind == "SUPER_WIND" then return 4 end

  if kind == "STORM" then return (intensity >= 0.85) and 4 or 3 end
  if kind == "RAIN"  then return (intensity >= 0.85) and 4 or 3 end

  if kind == "SNOW" then return 3 end
  if kind == "SUPER_HEAT" then return 3 end
  if kind == "SUPER_COLD" then return 3 end

  return 3
end

local function sevLabel(sev)
  sev = tonumber(sev) or 3
  if sev <= 1 then return "Advisory" end
  if sev == 2 then return "Watch" end
  if sev == 3 then return "Warning" end
  if sev == 4 then return "Extreme" end
  return "Catastrophic"
end




local paused = false
local seed = tonumber(Config.Seed) or os.time()
fronts = {}       
local nextFrontId = 1

gusts = {}        
local nextGustId = 1

local lastBroadcastAt = 0
local BROADCAST_MIN_MS = math.max(250, tonumber(Config.BroadcastMs) or 500) 
local broadcastStateThrottled
local jsonDecodeSafe

local regionalZones = {}
local nextZoneId = 1
local lastRandomSpawnAt = 0
local addFront

local runtimeTime = {
  manualMode = nil,
  manualHour = nil,
  manualMinute = 0,
  freezeOverride = nil,
  frozenSnapshot = nil,
}

serverWeatherState = nil
local lastWeatherMode = weatherMode()

local function jsonEncodeSafe(val)
  local ok, out = pcall(function() return json.encode(val) end)
  if ok then return out end
  return nil
end

local function regionCfg()
  return Config.RegionalWeather or {}
end

local function regionProfiles()
  local rw = regionCfg()
  return rw.profiles or {}
end

local function zonePersistFile()
  local rw = regionCfg()
  return tostring(rw.persistFile or "data/zones.json")
end

local function profileExists(profile)
  profile = tostring(profile or "CUSTOM"):upper()
  return regionProfiles()[profile] ~= nil
end

local function sanitizeZone(zone, keepId)
  local rw = regionCfg()
  local W = Config.World or {}
  zone = zone or {}

  local profile = tostring(zone.profile or "CUSTOM"):upper()
  if not profileExists(profile) then profile = "CUSTOM" end

  local out = {
    id = keepId and tonumber(zone.id or 0) or nil,
    label = tostring(zone.label or "Regional Zone"),
    profile = profile,
    x = clamp(zone.x or 0.0, tonumber(W.minX) or -4200.0, tonumber(W.maxX) or 4500.0),
    y = clamp(zone.y or 0.0, tonumber(W.minY) or -4200.0, tonumber(W.maxY) or 8000.0),
    r = clamp(zone.r or rw.defaultRadius or 1650.0, tonumber(rw.minRadius) or 350.0, tonumber(rw.maxRadius) or 4800.0),
    intensity = clamp(zone.intensity or 0.85, 0.10, 1.0),
    priority = clamp(zone.priority or 1, 0, 10),
  }

  out.label = out.label:gsub("^%s+", ""):gsub("%s+$", "")
  if out.label == "" then out.label = "Regional Zone" end
  return out
end

local function saveRegionalZones()
  local payload = jsonEncodeSafe({ zones = regionalZones })
  if not payload then
    dprint("^1saveRegionalZones failed: json encode error^7")
    return false
  end

  local ok = SaveResourceFile(RESOURCE, zonePersistFile(), payload, -1)
  if ok == false then
    dprint("^1saveRegionalZones failed writing^7", zonePersistFile())
    return false
  end
  return true
end

local function seedDefaultZones()
  regionalZones = {}
  nextZoneId = 1

  local rw = regionCfg()
  for _,zone in ipairs(rw.defaultZones or {}) do
    local z = sanitizeZone(zone, false)
    z.id = nextZoneId
    nextZoneId = nextZoneId + 1
    regionalZones[#regionalZones+1] = z
  end
end

local function loadRegionalZones()
  local rw = regionCfg()
  if rw.enabled == false then
    regionalZones = {}
    return
  end

  local raw = LoadResourceFile(RESOURCE, zonePersistFile())
  if raw and raw ~= "" then
    local decoded = jsonDecodeSafe(raw)
    if decoded and type(decoded.zones) == "table" then
      regionalZones = {}
      nextZoneId = 1
      for _,zone in ipairs(decoded.zones) do
        local z = sanitizeZone(zone, true)
        z.id = tonumber(zone.id or nextZoneId) or nextZoneId
        if z.id >= nextZoneId then nextZoneId = z.id + 1 end
        regionalZones[#regionalZones+1] = z
      end
      if #regionalZones > 0 then
        dprint("^2Loaded regional weather zones:^7", #regionalZones)
        return
      end
    end
  end

  seedDefaultZones()
  saveRegionalZones()
  dprint("^3Seeded default regional weather zones:^7", #regionalZones)
end

local function biomeForPoint(x, y)
  local biomes = Config.Biomes
  if not (biomes and biomes.enabled and type(biomes.zones) == "table") then return nil end
  for _,zone in ipairs(biomes.zones) do
    if zone and zone.center and zone.radius then
      local dx = (tonumber(x) or 0.0) - (tonumber(zone.center.x) or 0.0)
      local dy = (tonumber(y) or 0.0) - (tonumber(zone.center.y) or 0.0)
      local r = tonumber(zone.radius) or 0.0
      if (dx * dx + dy * dy) <= (r * r) then
        return zone
      end
    end
  end
  return nil
end

local function weightedPick(weights, fallback)
  if type(weights) ~= "table" then return fallback end
  local total = 0.0
  for kind, weight in pairs(weights) do
    if tonumber(weight) and tonumber(weight) > 0 and Config.Kinds[tostring(kind):upper()] then
      total = total + tonumber(weight)
    end
  end
  if total <= 0.0 then return fallback end

  local roll = math.random() * total
  local acc = 0.0
  for kind, weight in pairs(weights) do
    weight = tonumber(weight) or 0.0
    kind = tostring(kind):upper()
    if weight > 0 and Config.Kinds[kind] then
      acc = acc + weight
      if roll <= acc then return kind end
    end
  end

  return fallback
end

local function randomWorldPoint(preferEdges)
  local W = Config.World
  if preferEdges then
    local edge = math.random(1, 4)
    if edge == 1 then
      return W.minX + math.random() * (W.maxX - W.minX), W.minY + math.random() * 350.0
    elseif edge == 2 then
      return W.minX + math.random() * (W.maxX - W.minX), W.maxY - math.random() * 350.0
    elseif edge == 3 then
      return W.minX + math.random() * 350.0, W.minY + math.random() * (W.maxY - W.minY)
    else
      return W.maxX - math.random() * 350.0, W.minY + math.random() * (W.maxY - W.minY)
    end
  end
  return W.minX + math.random() * (W.maxX - W.minX), W.minY + math.random() * (W.maxY - W.minY)
end

local function randomPointInBiome(zone)
  if not zone or not zone.center or not zone.radius then return randomWorldPoint(false) end
  local ang = math.random() * math.pi * 2.0
  local dist = math.sqrt(math.random()) * (tonumber(zone.radius) or 1200.0) * 0.85
  return (tonumber(zone.center.x) or 0.0) + math.cos(ang) * dist, (tonumber(zone.center.y) or 0.0) + math.sin(ang) * dist
end

local function isFarEnoughFromFronts(x, y, minSeparation)
  minSeparation = tonumber(minSeparation) or 0.0
  if minSeparation <= 0.0 then return true end
  local minD2 = minSeparation * minSeparation
  for i=1, #fronts do
    local f = fronts[i]
    local dx = (tonumber(x) or 0.0) - (tonumber(f.x) or 0.0)
    local dy = (tonumber(y) or 0.0) - (tonumber(f.y) or 0.0)
    if (dx * dx + dy * dy) < minD2 then
      return false
    end
  end
  return true
end

local function randomFrontSpecAt(x, y)
  local biome = biomeForPoint(x, y)
  local fallbackKinds = { "STORM", "RAIN", "SUPER_WIND", "SUPER_HEAT", "SUPER_COLD", "SNOW" }
  local fallback = fallbackKinds[math.random(1, #fallbackKinds)]
  local kind = weightedPick(biome and biome.spawnWeights or nil, fallback)
  kind = tostring(kind or fallback):upper()
  if kind == "CLEAR" then kind = "RAIN" end

  local radiusMin, radiusMax = 1600.0, 3200.0
  local intensityMin, intensityMax = 0.52, 0.95
  local speedMin, speedMax = 5.5, 18.0

  if kind == "STORM" then
    radiusMin, radiusMax = 1800.0, 2800.0
    intensityMin, intensityMax = 0.68, 1.0
    speedMin, speedMax = 8.0, 20.0
  elseif kind == "RAIN" then
    radiusMin, radiusMax = 1600.0, 2600.0
    intensityMin, intensityMax = 0.45, 0.82
    speedMin, speedMax = 5.0, 13.0
  elseif kind == "SNOW" then
    radiusMin, radiusMax = 1800.0, 2800.0
    intensityMin, intensityMax = 0.50, 0.86
    speedMin, speedMax = 4.0, 11.0
  elseif kind == "BLIZZARD" then
    radiusMin, radiusMax = 2200.0, 3200.0
    intensityMin, intensityMax = 0.72, 1.0
    speedMin, speedMax = 6.0, 14.0
  elseif kind == "SUPER_WIND" then
    radiusMin, radiusMax = 2200.0, 3400.0
    intensityMin, intensityMax = 0.58, 0.96
    speedMin, speedMax = 10.0, 24.0
  elseif kind == "SUPER_HEAT" or kind == "SUPER_COLD" then
    radiusMin, radiusMax = 2400.0, 3600.0
    intensityMin, intensityMax = 0.50, 0.90
    speedMin, speedMax = 4.0, 10.0
  end

  return {
    kind = kind,
    radius = radiusMin + math.random() * (radiusMax - radiusMin),
    intensity = intensityMin + math.random() * (intensityMax - intensityMin),
    speed = speedMin + math.random() * (speedMax - speedMin),
  }
end

local function maybeSpawnRandomFront(force)
  local re = Config.RandomEvents or {}
  if re.enabled == false then return nil end
  if #fronts >= (tonumber(Config.MaxFronts) or 5) then return nil end

  if not force then
    local now = nowMs()
    local every = math.max(15000, tonumber(re.checkEveryMs) or 90000)
    if now < (lastRandomSpawnAt + every) then return nil end
    lastRandomSpawnAt = now
    if math.random() > (tonumber(re.spawnChance) or 0.35) then return nil end
  end

  for _=1, 10 do
    local x, y
    local biome = nil
    if Config.Biomes and Config.Biomes.enabled and type(Config.Biomes.zones) == "table" and #Config.Biomes.zones > 0 and math.random() < 0.7 then
      biome = Config.Biomes.zones[math.random(1, #Config.Biomes.zones)]
      x, y = randomPointInBiome(biome)
    else
      x, y = randomWorldPoint(re.preferEdges ~= false)
      biome = biomeForPoint(x, y)
    end

    if isFarEnoughFromFronts(x, y, re.minSeparationMeters) then
      local spec = randomFrontSpecAt(x, y)
      local front = addFront(spec.kind, x, y, spec.radius, spec.intensity, spec.speed, nil)
      if front then
        dprint("^2random front spawned^7", ("kind=%s x=%.0f y=%.0f biome=%s"):format(front.kind, front.x, front.y, biome and tostring(biome.label or biome.id or "?") or "none"))
        return front
      end
    end
  end

  return nil
end

local function upsertRegionalZone(zone)
  local z = sanitizeZone(zone, true)

  if z.id and z.id > 0 then
    for i=1, #regionalZones do
      if tonumber(regionalZones[i].id) == tonumber(z.id) then
        regionalZones[i] = z
        saveRegionalZones()
        broadcastStateThrottled()
        return z, false
      end
    end
  end

  z.id = nextZoneId
  nextZoneId = nextZoneId + 1
  regionalZones[#regionalZones+1] = z
  saveRegionalZones()
  broadcastStateThrottled()
  return z, true
end

local function deleteRegionalZone(id)
  id = tonumber(id or 0) or 0
  if id <= 0 then return false end
  for i=1, #regionalZones do
    if tonumber(regionalZones[i].id) == id then
      table.remove(regionalZones, i)
      saveRegionalZones()
      broadcastStateThrottled()
      return true
    end
  end
  return false
end

local function buildTimeState()
  if not (Config.Time and Config.Time.enabled) or not syncTimeEnabled() then
    return { freeze=false, hour=nil, minute=0 }
  end

  local cfg = Config.Time or {}
  local freeze = runtimeTime.freezeOverride
  if freeze == nil then freeze = (cfg.freeze == true) end

  local hour = nil
  local minute = 0

  if runtimeTime.manualMode == true then
    hour = clamp(runtimeTime.manualHour, 0, 23)
    minute = clamp(runtimeTime.manualMinute or 0, 0, 59)
  elseif runtimeTime.manualMode == nil and cfg.hour ~= nil then
    hour = clamp(cfg.hour, 0, 23)
    minute = clamp(cfg.minute or 0, 0, 59)
  end

  local useSystemTime = (cfg.useSystemTime == true) or (cfg.realtime == true)

  if hour ~= nil then
    runtimeTime.frozenSnapshot = nil
    return { freeze = freeze, hour = hour, minute = minute }
  end

  if useSystemTime then
    if freeze then
      if not runtimeTime.frozenSnapshot then
        local h, m = getSystemTimeParts()
        runtimeTime.frozenSnapshot = { hour = h, minute = m }
      end
      return { freeze = true, hour = runtimeTime.frozenSnapshot.hour, minute = runtimeTime.frozenSnapshot.minute }
    end

    runtimeTime.frozenSnapshot = nil
    local h, m = getSystemTimeParts()
    return { freeze = false, hour = h, minute = m }
  end

  if not freeze then
    runtimeTime.frozenSnapshot = nil
  end

  return { freeze = freeze, hour = nil, minute = 0 }
end

local function buildGlobalWeatherState()
  if not syncWeatherEnabled() or not isGlobalWeatherMode() then
    return nil
  end

  local state = serverWeatherState or {
    weather = tostring((Config.Base and Config.Base.weather) or "CLEAR"):upper(),
    rain = tonumber(Config.Base and Config.Base.rain) or 0.0,
    snow = tonumber(Config.Base and Config.Base.snow) or 0.0,
    windSpeed = tonumber(Config.Base and Config.Base.windSpeed) or 0.0,
    windDirDeg = tonumber(Config.Base and Config.Base.windDirDeg) or 180.0,
    temperatureC = tonumber(Config.Base and Config.Base.temperatureC) or 18.0,
    lightningChance = 0.0,
    timecycle = nil,
    kind = "CLEAR",
    source = "base",
  }

  return {
    weather = tostring(state.weather or "CLEAR"):upper(),
    rain = clamp(state.rain or 0.0, 0.0, 1.0),
    snow = clamp(state.snow or 0.0, 0.0, 1.0),
    windSpeed = clamp(state.windSpeed or 0.0, 0.0, 12.0),
    windDirDeg = tonumber(state.windDirDeg) or 180.0,
    tempC = tonumber(state.temperatureC) or tonumber(state.tempC) or 18.0,
    temperatureC = tonumber(state.temperatureC) or tonumber(state.tempC) or 18.0,
    lightningChance = clamp(state.lightningChance or 0.0, 0.0, 1.0),
    timecycle = state.timecycle,
    kind = tostring(state.kind or "CLEAR"):upper(),
    source = tostring(state.source or "base"),
    office = state.office,
    sourceForecast = state.sourceForecast,
  }
end

local function snapshotGusts()
  local arr = {}
  for _,g in pairs(gusts) do
    arr[#arr+1] = g
  end
  return arr
end

local function broadcastState(target)
  local weatherSync = syncWeatherEnabled()
  local s = {
    paused = paused,
    seed = seed,
    fronts = weatherSync and fronts or {},
    time = buildTimeState(),
    weather = buildGlobalWeatherState(),
    sync = {
      time = syncTimeEnabled(),
      weather = weatherSync,
      weatherMode = weatherMode(),
    },
    forecastSteps = (Config.Forecast and Config.Forecast.steps) or {30,60,120,180,300},
    gusts = weatherSync and snapshotGusts() or {},
    zones = (weatherSync and regionalWeatherEnabled()) and regionalZones or {},
  }

  if target then
    TriggerClientEvent("az_weatherfronts:state", target, s)
  else
    TriggerClientEvent("az_weatherfronts:state", -1, s)
  end
end

broadcastStateThrottled = function()
  local t = nowMs()
  if (t - lastBroadcastAt) < BROADCAST_MIN_MS then return end
  lastBroadcastAt = t
  broadcastState(nil)
end




addFront = function(kind, x, y, radius, intensity, speed, name)
  kind = tostring(kind or "STORM"):upper()
  local k = Config.Kinds[kind]
  if not k then
    dprint("^1addFront unknown kind^7", kind)
    return nil
  end

  local W = Config.World

  radius = clamp(radius or k.defaultRadius or 2200.0, Config.SpawnLimits.minRadius, Config.SpawnLimits.maxRadius)
  intensity = clamp(intensity or 0.9, Config.SpawnLimits.minIntensity, Config.SpawnLimits.maxIntensity)
  speed = clamp(speed or 12.0, Config.SpawnLimits.minSpeed, Config.SpawnLimits.maxSpeed)

  x = tonumber(x) or 0.0
  y = tonumber(y) or 0.0
  x = clamp(x, W.minX, W.maxX)
  y = clamp(y, W.minY, W.maxY)

  
  math.randomseed(seed + nextFrontId * 97 + nowMs())
  local ang = math.random() * math.pi * 2.0
  local vx = math.cos(ang) * speed
  local vy = math.sin(ang) * speed

  local sev = kindSev(kind, intensity)
  local f = {
    id = nextFrontId,
    kind = kind,
    name = (name ~= nil and tostring(name) ~= "" and tostring(name)) or (k.label or kind),
    x = x,
    y = y,
    r = radius,
    i = intensity,
    vx = vx,
    vy = vy,
    sev = sev,
    sevLabel = sevLabel(sev),
    createdAt = nowMs(),
  }

  nextFrontId = nextFrontId + 1
  fronts[#fronts+1] = f
  dprint("^2addFront^7", ("id=%d kind=%s x=%.1f y=%.1f r=%.0f i=%.2f v=%.1f"):format(f.id, f.kind, f.x, f.y, f.r, f.i, speed))

  broadcastStateThrottled()
  return f
end

local function removeFrontById(id)
  id = tonumber(id or 0) or 0
  if id <= 0 then return false end
  for i=1, #fronts do
    if tonumber(fronts[i].id) == id then
      dprint("^3removeFront^7", id)
      table.remove(fronts, i)
      broadcastStateThrottled()
      return true
    end
  end
  return false
end

local function clearFronts()
  fronts = {}
  dprint("^3clearFronts^7")
  broadcastStateThrottled()
end




local function emitGustNearFront(f)
  if not f then return end

  local id = nextGustId
  nextGustId = nextGustId + 1

  local t = nowMs()
  local dur = math.random(4500, 10000)
  local rr = clamp((tonumber(f.r) or 2200.0) * (0.25 + math.random()*0.25), 200.0, 1800.0)

  local extra = clamp((tonumber(f.i) or 0.8) * (2.0 + math.random()*2.0), 1.2, 6.0)
  local dir = math.random(0, 359)

  local gx = wrap((tonumber(f.x) or 0.0) + math.random(-800, 800), Config.World.minX, Config.World.maxX)
  local gy = wrap((tonumber(f.y) or 0.0) + math.random(-800, 800), Config.World.minY, Config.World.maxY)

  local g = {
    id = id,
    x = gx,
    y = gy,
    r = rr,
    extra = extra,
    dir = dir,
    t = t,
    dur = dur,
  }

  gusts[id] = g
  TriggerClientEvent("az_weatherfronts:gust", -1, g)

  dprint("^5gust^7", ("id=%d x=%.1f y=%.1f r=%.0f extra=%.2f dur=%dms"):format(id, gx, gy, rr, extra, dur))
end

local function pruneGusts()
  local t = nowMs()
  for id,g in pairs(gusts) do
    if t >= (tonumber(g.t) + tonumber(g.dur)) then
      gusts[id] = nil
    end
  end
end




RegisterNetEvent("az_weatherfronts:request", function()
  local src = source
  dprint("state request from", src)
  broadcastState(src)
end)


RegisterNetEvent("az_weatherfronts:spawnHere", function(kind, x, y, radius, intensity, speed, name)
  local src = source

  if not (Config.SpawnLimits and Config.SpawnLimits.allowPlayers) then
    dprint("^1spawnHere blocked (allowPlayers=false)^7 src=", src)
    return
  end

  kind = tostring(kind or "STORM"):upper()
  if not Config.Kinds[kind] then
    dprint("^1spawnHere invalid kind^7", kind, "src=", src)
    return
  end

  radius = clamp(radius, Config.SpawnLimits.minRadius, Config.SpawnLimits.maxRadius)
  intensity = clamp(intensity, Config.SpawnLimits.minIntensity, Config.SpawnLimits.maxIntensity)
  speed = clamp(speed, Config.SpawnLimits.minSpeed, Config.SpawnLimits.maxSpeed)

  addFront(kind, x, y, radius, intensity, speed, name)
end)



local function sendSpawnAtMe(src, args)
  TriggerClientEvent("az_weatherfronts:spawnAtMe", src, args)
end





RegisterCommand(safeCmd((Config.Commands and Config.Commands.spawn), "wxspawn"), function(src, args)
  
  if src and src > 0 then
    sendSpawnAtMe(src, args or {})
    return
  end

  
  if not (Config.SpawnLimits and Config.SpawnLimits.allowConsole) then
    dprint("^1wxspawn blocked (allowConsole=false)^7")
    return
  end

  local kind = tostring((args and args[1]) or "STORM"):upper()
  local radius = tonumber(args and args[2]) or nil
  local intensity = tonumber(args and args[3]) or nil
  local speed = tonumber(args and args[4]) or nil

  local name = nil
  if args and args[5] then
    name = table.concat(args, " ", 5)
  end

  
  local x = 0.0
  local y = 0.0
  if args and #args >= 7 then
    x = tonumber(args[#args-1]) or x
    y = tonumber(args[#args]) or y
  end

  addFront(kind, x, y, radius, intensity, speed, name)
end, true)


RegisterCommand(safeCmd((Config.Commands and Config.Commands.clear), "wxclear"), function(src)
  if src and src > 0 then
    
  end
  clearFronts()
end, true)


RegisterCommand(safeCmd((Config.Commands and Config.Commands.remove), "wxremove"), function(src, args)
  local id = tonumber(args and args[1] or 0) or 0
  if id <= 0 then
    if src > 0 then
      TriggerClientEvent("chat:addMessage", src, { args = { "^2wx^7", "Usage: /wxremove <id>" } })
    else
      print("Usage: wxremove <id>")
    end
    return
  end
  local ok = removeFrontById(id)
  if src > 0 then
    TriggerClientEvent("chat:addMessage", src, { args = { "^2wx^7", ok and ("Removed front "..id) or ("Front not found: "..id) } })
  end
end, true)


RegisterCommand(safeCmd((Config.Commands and Config.Commands.pause), "wxpause"), function(src)
  paused = not paused
  dprint("^3paused toggled^7", paused)
  broadcastStateThrottled()
  if src and src > 0 then
    TriggerClientEvent("chat:addMessage", src, { args = { "^2wx^7", paused and "Weather simulation: PAUSED" or "Weather simulation: RUNNING" } })
  end
end, true)




real = {
  nextRefreshAt = 0,
  office = nil,
  forecast = nil, 
}

local function httpGet(url, headers, cb)
  PerformHttpRequest(url, function(code, body, respHeaders)
    cb(code, body, respHeaders)
  end, "GET", "", headers or {})
end

jsonDecodeSafe = function(s)
  local ok, val = pcall(function() return json.decode(s) end)
  if ok then return val end
  return nil
end

local function refreshRealWeather()
  if not canUseSystemWeather() then
    serverWeatherState = nil
    real.nextRefreshAt = 0
    return
  end

  local t = nowMs()
  if t < (real.nextRefreshAt or 0) then return end

  local refreshMs = math.max(1, tonumber(Config.SystemWeather.refreshMinutes) or 10) * 60000
  real.nextRefreshAt = t + refreshMs

  local lat = tonumber(Config.SystemWeather.lat) or 34.0522
  local lon = tonumber(Config.SystemWeather.lon) or -118.2437
  local ua = tostring(Config.SystemWeather.userAgent or "FiveM-az_weatherfronts")

  local pointUrl = ("https://api.weather.gov/points/%.4f,%.4f"):format(lat, lon)
  httpGet(pointUrl, { ["User-Agent"] = ua, ["Accept"] = "application/geo+json" }, function(code, body)
    if code ~= 200 or not body or body == "" then
      dprint("^1RealWeather points failed^7 code=", code)
      return
    end

    local data = jsonDecodeSafe(body)
    if not data or not data.properties then
      dprint("^1RealWeather points invalid payload^7")
      return
    end

    local props = data.properties
    real.office = props.cwa or real.office

    local forecastUrl = props.forecast
    if not forecastUrl or forecastUrl == "" then
      dprint("^1RealWeather missing forecast url^7")
      return
    end

    httpGet(forecastUrl, { ["User-Agent"] = ua, ["Accept"] = "application/geo+json" }, function(code2, body2)
      if code2 ~= 200 or not body2 or body2 == "" then
        dprint("^1RealWeather forecast failed^7 code=", code2)
        return
      end
      local data2 = jsonDecodeSafe(body2)
      if not data2 or not data2.properties or not data2.properties.periods then
        dprint("^1RealWeather forecast invalid payload^7")
        return
      end

      real.forecast = data2.properties.periods

      local currentPeriod = real.forecast and real.forecast[1] or nil
      if currentPeriod then
        serverWeatherState = mapForecastToWeather(currentPeriod)
        serverWeatherState.source = "system_weather"
        serverWeatherState.office = real.office
      end

      if real.office then
        TriggerClientEvent("az_weatherfronts:nwsOffice", -1, tostring(real.office))
      end

      broadcastStateThrottled()
      dprint("^2RealWeather updated^7 office=", real.office, "periods=", #real.forecast)
    end)
  end)
end



RegisterCommand(safeCmd((Config.Commands and Config.Commands.resume), "wxresume"), function(src)
  paused = false
  broadcastStateThrottled()
  if src and src > 0 then
    TriggerClientEvent("chat:addMessage", src, { args = { "^2wx^7", "Weather simulation: RUNNING" } })
  end
end, true)

RegisterCommand(safeCmd((Config.Commands and Config.Commands.seed), "wxseed"), function(src, args)
  local newSeed = tonumber(args and args[1])
  if not newSeed then
    if src and src > 0 then
      TriggerClientEvent("chat:addMessage", src, { args = { "^2wx^7", "Usage: /wxseed <number>" } })
    else
      print("Usage: wxseed <number>")
    end
    return
  end
  seed = newSeed
  math.randomseed(seed + nowMs())
  broadcastStateThrottled()
  if src and src > 0 then
    TriggerClientEvent("chat:addMessage", src, { args = { "^2wx^7", "Weather seed set to " .. tostring(seed) } })
  end
end, true)

RegisterCommand(safeCmd((Config.Commands and Config.Commands.time), "wxtime"), function(src, args)
  local hh = tonumber(args and args[1])
  local mm = tonumber(args and args[2]) or 0

  if hh == nil then
    runtimeTime.manualMode = false
    runtimeTime.manualHour = nil
    runtimeTime.manualMinute = 0
    runtimeTime.frozenSnapshot = nil
    broadcastStateThrottled()
    local msg = ((Config.Time and ((Config.Time.useSystemTime == true) or (Config.Time.realtime == true))) and "Manual time override cleared; using system time." or "Manual time override cleared.")
    if src and src > 0 then
      TriggerClientEvent("chat:addMessage", src, { args = { "^2wx^7", msg } })
    else
      print(msg)
    end
    return
  end

  runtimeTime.manualMode = true
  runtimeTime.manualHour = clamp(hh, 0, 23)
  runtimeTime.manualMinute = clamp(mm, 0, 59)
  runtimeTime.frozenSnapshot = nil
  broadcastStateThrottled()
  local msg = ("Time override set to %02d:%02d"):format(runtimeTime.manualHour, runtimeTime.manualMinute)
  if src and src > 0 then
    TriggerClientEvent("chat:addMessage", src, { args = { "^2wx^7", msg } })
  else
    print(msg)
  end
end, true)

RegisterCommand(safeCmd((Config.Commands and Config.Commands.freezeTime), "wxfreezetime"), function(src)
  local current = runtimeTime.freezeOverride
  if current == nil then current = (Config.Time and Config.Time.freeze == true) end
  runtimeTime.freezeOverride = not current

  if runtimeTime.freezeOverride and runtimeTime.manualMode ~= true and not (Config.Time and Config.Time.hour ~= nil) and ((Config.Time and Config.Time.useSystemTime == true) or (Config.Time and Config.Time.realtime == true)) then
    local h, m = getSystemTimeParts()
    runtimeTime.frozenSnapshot = { hour = h, minute = m }
  else
    runtimeTime.frozenSnapshot = nil
  end

  broadcastStateThrottled()
  local msg = runtimeTime.freezeOverride and "System time frozen." or "System time unfrozen."
  if src and src > 0 then
    TriggerClientEvent("chat:addMessage", src, { args = { "^2wx^7", msg } })
  else
    print(msg)
  end
end, true)

loadRegionalZones()

CreateThread(function()
  math.randomseed(seed + nowMs())

  
  Wait(500)
  if syncWeatherEnabled() then
    refreshRealWeather()
    if not isGlobalWeatherMode() and (Config.RandomEvents and Config.RandomEvents.enabled) and #fronts == 0 then
      maybeSpawnRandomFront(true)
      maybeSpawnRandomFront(true)
    elseif isGlobalWeatherMode() and bool((syncCfg() or {}).clearFrontsInGlobalMode, true) and #fronts > 0 then
      fronts = {}
    end
  else
    clearWeatherRuntimeState()
  end
  broadcastState(nil)

  while true do
    Wait(Config.ServerTickMs)

    refreshRealWeather()
    pruneGusts()

    local currentMode = weatherMode()
    if currentMode ~= lastWeatherMode then
      lastWeatherMode = currentMode
      if isGlobalWeatherMode() and bool((syncCfg() or {}).clearFrontsInGlobalMode, true) and #fronts > 0 then
        fronts = {}
      end
    end

    if not syncWeatherEnabled() then
      clearWeatherRuntimeState()
      broadcastStateThrottled()
      goto continue
    end

    if paused then
      
      broadcastStateThrottled()
      goto continue
    end

    if isGlobalWeatherMode() then
      broadcastStateThrottled()
      goto continue
    end

    maybeSpawnRandomFront(false)

    local W = Config.World
    local dt = (Config.ServerTickMs / 1000.0)

    
    for i=1, #fronts do
      local f = fronts[i]
      f.x = wrap((tonumber(f.x) or 0.0) + (tonumber(f.vx) or 0.0) * dt, W.minX, W.maxX)
      f.y = wrap((tonumber(f.y) or 0.0) + (tonumber(f.vy) or 0.0) * dt, W.minY, W.maxY)

      
      local drift = ((math.random() * 2.0) - 1.0) * 0.01
      f.i = clamp((tonumber(f.i) or 0.8) + drift, 0.10, 1.0)

      local sev = kindSev(f.kind, f.i)
      f.sev = sev
      f.sevLabel = sevLabel(sev)

      
      local gustChance = 0.010
      if f.kind == "SUPER_WIND" then gustChance = 0.030 end
      if f.kind == "STORM" then gustChance = 0.020 end
      if f.kind == "BLIZZARD" then gustChance = 0.018 end

      if math.random() < gustChance then
        emitGustNearFront(f)
      end
    end

    
    if #fronts > Config.MaxFronts then
      while #fronts > Config.MaxFronts do
        table.remove(fronts, 1)
      end
    end

    broadcastStateThrottled()
    ::continue::
  end
end)


RegisterNetEvent("az_weatherfronts:zone:save", function(zone)
  local src = source
  local rw = regionCfg()
  if rw.enabled == false or rw.allowClientEditing == false then
    dprint("^1zone save blocked^7 src=", src)
    return
  end

  local saved, created = upsertRegionalZone(zone)
  dprint(created and "^2zone created^7" or "^2zone updated^7", ("src=%s id=%s label=%s profile=%s"):format(src, saved.id, saved.label, saved.profile))
end)

RegisterNetEvent("az_weatherfronts:zone:delete", function(id)
  local src = source
  local rw = regionCfg()
  if rw.enabled == false or rw.allowClientEditing == false then
    dprint("^1zone delete blocked^7 src=", src)
    return
  end

  if deleteRegionalZone(id) then
    dprint("^3zone deleted^7", ("src=%s id=%s"):format(src, id))
  end
end)





RegisterNetEvent("az_weatherfronts:nwsOffice", function(_) end) 

dprint("^2server.lua loaded^7 seed=", seed)
