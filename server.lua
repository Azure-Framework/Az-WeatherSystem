// File: no-comments-pasted.lua

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
  enabled = false,
  freeze = false,
  realtime = true,
  hour = nil,
  minute = 0,
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

Config.RealWeather = Config.RealWeather or {
  enabled = false,
  lat = 34.0522,
  lon = -118.2437,
  refreshMinutes = 10,
  userAgent = "FiveM-az_weatherfronts (admin@yourdomain.tld)",
}

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
local fronts = {}
local nextFrontId = 1

local gusts = {}
local nextGustId = 1

local lastBroadcastAt = 0
local BROADCAST_MIN_MS = 500

local function buildTimeState()
  if not (Config.Time and Config.Time.enabled) then
    return { freeze=false, hour=nil, minute=0 }
  end

  local t = { freeze = (Config.Time.freeze == true), hour = nil, minute = 0 }

  if Config.Time.hour ~= nil then
    t.hour = clamp(Config.Time.hour, 0, 23)
    t.minute = clamp(Config.Time.minute or 0, 0, 59)
    return t
  end

  if Config.Time.realtime then
    local lt = os.date("*t")
    t.hour = clamp(lt.hour or 12, 0, 23)
    t.minute = clamp(lt.min or 0, 0, 59)
  end

  return t
end

local function snapshotGusts()
  local arr = {}
  for _,g in pairs(gusts) do
    arr[#arr+1] = g
  end
  return arr
end

local function broadcastState(target)
  local s = {
    paused = paused,
    seed = seed,
    fronts = fronts,
    time = buildTimeState(),
    forecastSteps = (Config.Forecast and Config.Forecast.steps) or {30,60,120,180,300},
    gusts = snapshotGusts(),
  }

  if target then
    TriggerClientEvent("az_weatherfronts:state", target, s)
  else
    TriggerClientEvent("az_weatherfronts:state", -1, s)
  end
end

local function broadcastStateThrottled()
  local t = nowMs()
  if (t - lastBroadcastAt) < BROADCAST_MIN_MS then return end
  lastBroadcastAt = t
  broadcastState(nil)
end

local function addFront(kind, x, y, radius, intensity, speed, name)
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

local real = {
  nextRefreshAt = 0,
  office = nil,
  forecast = nil,
}

local function httpGet(url, headers, cb)
  PerformHttpRequest(url, function(code, body, respHeaders)
    cb(code, body, respHeaders)
  end, "GET", "", headers or {})
end

local function jsonDecodeSafe(s)
  local ok, val = pcall(function() return json.decode(s) end)
  if ok then return val end
  return nil
end

local function refreshRealWeather()
  if not (Config.RealWeather and Config.RealWeather.enabled) then return end

  local t = nowMs()
  if t < (real.nextRefreshAt or 0) then return end

  local refreshMs = math.max(60, tonumber(Config.RealWeather.refreshMinutes) or 10) * 60000
  real.nextRefreshAt = t + refreshMs

  local lat = tonumber(Config.RealWeather.lat) or 34.0522
  local lon = tonumber(Config.RealWeather.lon) or -118.2437
  local ua = tostring(Config.RealWeather.userAgent or "FiveM-az_weatherfronts")

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

      if real.office then
        TriggerClientEvent("az_weatherfronts:nwsOffice", -1, tostring(real.office))
      end

      dprint("^2RealWeather updated^7 office=", real.office, "periods=", #real.forecast)
    end)
  end)
end

CreateThread(function()
  math.randomseed(seed + nowMs())

  Wait(500)
  broadcastState(nil)

  while true do
    Wait(Config.ServerTickMs)

    refreshRealWeather()
    pruneGusts()

    if paused then

      broadcastStateThrottled()
      goto continue
    end

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

RegisterNetEvent("az_weatherfronts:nwsOffice", function(_) end)

dprint("^2server.lua loaded^7 seed=", seed)