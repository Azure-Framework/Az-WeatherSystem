Config = Config or {}
-- vector2 fallback (server-safe)
if not vector2 then
  function vector2(x,y) return {x=x, y=y} end
end


Config.Debug = false

-- Disable other weather sync resources or they will fight this.

Config.World = {
  minX = -4200.0,
  maxX =  4600.0,
  minY = -5200.0,
  maxY =  8200.0,
}

Config.ServerTickMs  = 500
Config.BroadcastMs   = 1000
Config.ClientApplyMs = 750

-- Hard cap on simultaneously active fronts.
-- (Default lowered so you don't end up with 7-10 storms at once.)
Config.MaxFronts = 5

-- Optional per-kind caps so you don't get a pile of the same extreme front.
-- Set to nil to disable a cap.
Config.KindCaps = {
  STORM = 2,
  BLIZZARD = 1,
  SUPER_WIND = 2,
  SUPER_HEAT = 1,
  SUPER_COLD = 1,
}

Config.RandomEvents = {
  enabled = true,
  -- Less spammy by default.
  checkEveryMs = 90000,
  spawnChance = 0.35,
  preferEdges = true,
  -- Avoid stacking new fronts on top of existing ones.
  -- If a new spawn point is within this distance of any existing front center, it's skipped.
  minSeparationMeters = 2200.0,
}

-- Make wind *feel* like wind. GTA wind visuals can be subtle; this adds mild vehicle drift
-- in strong wind (and extra kick during gusts). Disable if you don't want physics influence.
Config.WindPhysics = {
  enabled = true,
  minWindSpeed = 5.5,          -- m/s before any drift starts
  maxWindSpeed = 12.0,
  maxForce = 0.42,             -- overall force scale (tune carefully)
  gustMultiplier = 1.8,
  onlyWhenDriving = true,
  ignoreClasses = { 15, 16, 21 }, -- heli, plane, train
}

Config.Forecast = {
  -- Seconds into the future to draw projected path points on the map.
  steps = { 30, 60, 120, 180, 300 },
}

Config.Naming = {
  enabled = true,
  -- Names are assigned automatically (unique among active fronts).
  names = {
    "Astra","Borealis","Cinder","Dahlia","Ember","Frost","Gale","Harbor","Ion","Juno",
    "Kestrel","Lumen","Mistral","Nova","Onyx","Peregrine","Quill","Raven","Sirocco","Tundra",
    "Umbra","Vesper","Warden","Xylo","Yonder","Zephyr","Atlas","Sable","Solstice","Tempest"
  }
}

Config.Severity = {
  -- Base severity (1-5) by kind; final severity also scales with intensity.
  base = {
    CLEAR=1,
    RAIN=2,
    STORM=3,
    SNOW=2,
    BLIZZARD=4,
    SUPER_WIND=3,
    SUPER_HEAT=3,
    SUPER_COLD=3,
  },
  labels = { [1]="Minor", [2]="Moderate", [3]="Severe", [4]="Extreme", [5]="Catastrophic" }
}

Config.Gusts = {
  enabled = true,
  chancePerTick = 0.12,
  minDurationMs = 2200,
  maxDurationMs = 5200,
  minExtraWind  = 2.0,
  maxExtraWind  = 7.5,
  dirJitterDeg  = 35.0,
  camShake = true,
  camShakeName = "LARGE_EXPLOSION_SHAKE",
  camShakeAmp = 0.18,
}

Config.Smoothing = {
  weatherChangeSeconds = 8.0,
  rainLerp = 0.10,
  snowLerp = 0.08,
  windLerp = 0.12,
  tempLerp = 0.08,
}

Config.Kinds = {
  CLEAR = {
    label = "Clear",
    baseWeather = "CLEAR",
    rain = 0.0,
    snow = 0.0,
    windAdd = 0.0,
    tempAdd = 0.0,
    lightningChance = 0.00,
    timecycle = nil,
  },

  STORM = {
    label = "Storm",
    baseWeather = "THUNDER",
    rain = 0.50,
    snow = 0.0,
    windAdd = 4.5,
    tempAdd = -2.0,
    lightningChance = 0.14,
    timecycle = "thunder",
  },

  RAIN = {
    label = "Rain",
    baseWeather = "RAIN",
    rain = 0.35,
    snow = 0.0,
    windAdd = 2.0,
    tempAdd = -1.0,
    lightningChance = 0.03,
    timecycle = nil,
  },

  BLIZZARD = {
    label = "Blizzard",
    baseWeather = "XMAS",
    rain = 0.0,
    snow = 0.85,
    windAdd = 6.0,
    tempAdd = -10.0,
    lightningChance = 0.00,
    timecycle = "xmas",
  },

  SNOW = {
    label = "Snow",
    baseWeather = "XMAS",
    rain = 0.0,
    snow = 0.55,
    windAdd = 2.5,
    tempAdd = -6.0,
    lightningChance = 0.00,
    timecycle = nil,
  },

  SUPER_HEAT = {
    label = "Super Heat",
    baseWeather = "EXTRASUNNY",
    rain = 0.0,
    snow = 0.0,
    windAdd = 1.0,
    tempAdd = 12.0,
    lightningChance = 0.00,
    timecycle = "heat",
  },

  SUPER_COLD = {
    label = "Super Cold",
    baseWeather = "OVERCAST",
    rain = 0.0,
    snow = 0.20,
    windAdd = 3.0,
    tempAdd = -14.0,
    lightningChance = 0.00,
    timecycle = "micheal",
  },

  SUPER_WIND = {
    label = "Super Wind",
    baseWeather = "CLOUDS",
    rain = 0.0,
    snow = 0.0,
    windAdd = 8.0,
    tempAdd = -1.0,
    lightningChance = 0.00,
    timecycle = nil,
  },
}

Config.Base = {
  weather = "CLEAR",
  rain = 0.0,
  snow = 0.0,
  windSpeed = 1.5,
  windDirDeg = 190.0,
  temperatureC = 18.0,
}

-- Biome bias modifies LOCAL output to feel more realistic.
-- Shapes are circles for simplicity.
Config.Biomes = {
  enabled = true,
  zones = {
    {
      id = "mountains",
      label = "Mountains",
      center = vector2(-500.0, 5500.0),
      radius = 2600.0,
      tempAdd = -6.0,
      rainMul = 0.90,
      snowMul = 1.25,
      windMul = 1.10,
      -- For random spawns inside this zone:
      spawnWeights = { BLIZZARD=3, SNOW=3, STORM=2, RAIN=1, SUPER_COLD=2, CLEAR=1 }
    },
    {
      id = "desert",
      label = "Desert",
      center = vector2(1750.0, 3500.0),
      radius = 2200.0,
      tempAdd = 5.0,
      rainMul = 0.85,
      snowMul = 0.50,
      windMul = 1.10,
      spawnWeights = { SUPER_HEAT=3, SUPER_WIND=2, STORM=1, RAIN=1, CLEAR=2 }
    },
    {
      id = "city",
      label = "City",
      center = vector2(150.0, -900.0),
      radius = 1800.0,
      tempAdd = 1.0,
      rainMul = 1.05,
      snowMul = 0.80,
      windMul = 0.95,
      spawnWeights = { RAIN=3, STORM=2, CLEAR=2, SUPER_WIND=1 }
    },
  }
}

Config.Alerts = {
  enabled = true,
  -- Alert UI (NWS-style). Uses NUI so it works even while the pause menu map is open.
  ui = {
    enabled = true,
    office = "Los Santos",
  },

  -- Optional legacy draw banner (2D draws) if you want it too.
  drawBanner = false,
  -- When a front of severity >= minSeverity is within (radius + buffer) => warning.
  minSeverity = 3,
  bufferMeters = 550.0,
  cooldownMs = 15000,
  showChat = true,
  showBanner = true,
  sound = {
    enabled = true,
    -- Best-effort GTA frontend sound; if it fails, you still get banner/chat.
    name = "5_SEC_WARNING",
    set = "HUD_MINI_GAME_SOUNDSET",
  }
}

-- Pause-map overlay (no NUI): fronts are rendered as radius + center + forecast dot blips.
Config.PauseMap = {
  command = "wxmap",
  -- When toggled ON, open the pause menu so you immediately see the map.
  openPauseMenu = true,

  -- If false, blips show only on the big pause-map (not the minimap).
  showOnRadar = false,

  showRadius = true,
  showCenter = true,
  showForecastDots = true,

  -- Blip visuals
  radiusAlpha = 70,
  centerAlpha = 220,
  forecastAlpha = 120,
  centerScale = 0.75,
  forecastScale = 0.35,

  -- Per-kind blip colors (GTA blip color IDs)
  colors = {
    CLEAR = 25,
    RAIN = 3,
    STORM = 1,
    SNOW = 2,
    BLIZZARD = 0,
    SUPER_WIND = 5,
    SUPER_HEAT = 47,
    SUPER_COLD = 38,
  },

  -- Optional: per-kind center sprites (set nil to use default 1)
  sprites = {
    -- STORM = 310,
    -- BLIZZARD = 512,
  },
}

Config.Commands = {
  help      = "wxhelp",
  status    = "wx",
  list      = "wxfronts",
  track     = "wxtrack",
  pos       = "wxpos",
  spawn     = "wxspawn",
  clear     = "wxclear",
  pause     = "wxpause",
  resume    = "wxresume",
  seed      = "wxseed",
  time      = "wxtime",
  freezeTime= "wxfreezetime",
}
