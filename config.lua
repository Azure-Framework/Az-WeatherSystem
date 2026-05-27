Config = Config or {}

if not vector2 then
  function vector2(x,y) return {x=x, y=y} end
end


Config.Debug = false


Config.Sync = {
  
  
  
  time = false,
  weather = false,
  weatherMode = "regional",
  clearFrontsInGlobalMode = true,
}

Config.Time = {
  enabled = false,
  freeze = false,
  
  useSystemTime = false,
  
  realtime = false,
  
  
  hour = nil,
  minute = 0,
  
  
  timezoneOffsetMinutes = nil,
}

Config.SystemWeather = {
  enabled = false,
  provider = "nws",
  lat = 34.0522,
  lon = -118.2437,
  refreshMinutes = 10,
  userAgent = "Az-WeatherSystem (MadebyAzure.com)",
}


Config.RealWeather = Config.RealWeather or Config.SystemWeather



Config.World = {
  minX = -4200.0,
  maxX =  4600.0,
  minY = -4200.0,
  maxY =  8200.0,
}

Config.ServerTickMs  = 500
Config.BroadcastMs   = 1000
Config.ClientApplyMs = 750



Config.MaxFronts = 5



Config.KindCaps = {
  STORM = 1,
  BLIZZARD = 1,
  SUPER_WIND = 1,
  SUPER_HEAT = 1,
  SUPER_COLD = 1,
}

Config.RandomEvents = {
  enabled = false,
  
  checkEveryMs = 90000,
  spawnChance = 0.15,
  preferEdges = true,
  
  
  minSeparationMeters = 4200.0,
}



Config.WindPhysics = {
  enabled = false,
  minWindSpeed = 5.5,          
  maxWindSpeed = 12.0,
  maxForce = 0.42,             
  gustMultiplier = 1.8,
  onlyWhenDriving = true,
  ignoreClasses = { 15, 16, 21 }, 
}

Config.Forecast = {
  
  steps = { 30, 60, 120, 180, 300 },
}

Config.Naming = {
  enabled = false,
  
  names = {
    "Astra","Borealis","Cinder","Dahlia","Ember","Frost","Gale","Harbor","Ion","Juno",
    "Kestrel","Lumen","Mistral","Nova","Onyx","Peregrine","Quill","Raven","Sirocco","Tundra",
    "Umbra","Vesper","Warden","Xylo","Yonder","Zephyr","Atlas","Sable","Solstice","Tempest"
  }
}

Config.Severity = {
  
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
  enabled = false,
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



Config.Biomes = {
  enabled = false,
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
  enabled = false,
  
  ui = {
    enabled = false,
    office = "Los Santos",
  },

  
  drawBanner = false,
  
  minSeverity = 3,
  bufferMeters = 550.0,
  cooldownMs = 15000,
  bannerDurationMs = 15000,
  showChat = true,
  showBanner = true,
  sound = {
    enabled = false,
    
    name = "5_SEC_WARNING",
    set = "HUD_MINI_GAME_SOUNDSET",
  }
}

Config.PauseMap = {
  command = "wxmap",
  openPauseMenu = true,
  showOnRadar = false,

  showRadius = true,
  showCenter = true,
  showForecast = true,
  showDirection = true,

  radiusAlpha = 170,
  centerAlpha = 255,
  centerScale = 0.85,

  forecastAlpha = 190,
  forecastScale = 0.60,

  dirAlpha = 220,
  dirScale = 0.55,
  dirCount = 3,
  dirSpacingMul = 0.22,

  maxForecast = 4,
  forecastStepsAreMinutes = true,

  colorsDefault = 1,
  colors = {
    STORM = 1,
    RAIN = 3,
    BLIZZARD = 3,
    SNOW = 3,
    SUPER_WIND = 5
  },

  sprites = {
    STORM = 75,
    RAIN = 75,
    BLIZZARD = 75,
    SNOW = 75,
    SUPER_WIND = 75
  }
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


Config.WeatherApp = {
  locationName = "Los Santos",
}

Config.RegionalWeather = {
  enabled = false,
  allowClientEditing = true,
  persistFile = "data/zones.json",
  defaultRadius = 1450.0,
  minRadius = 350.0,
  maxRadius = 4200.0,
  transitionFalloff = 0.18,
  profiles = {
    CITY = {
      label = "City",
      kind = "RAIN",
      baseWeather = "CLOUDS",
      rain = 0.10,
      snow = 0.0,
      windAdd = 0.9,
      tempAdd = 0.6,
      lightningChance = 0.01,
      timecycle = nil,
      windDirDeg = 205.0,
      description = "Dense urban coverage with cooler overcast periods and fast-moving city showers."
    },
    DESERT = {
      label = "Desert",
      kind = "SUPER_HEAT",
      baseWeather = "EXTRASUNNY",
      rain = 0.01,
      snow = 0.0,
      windAdd = 1.7,
      tempAdd = 5.6,
      lightningChance = 0.00,
      timecycle = "heat",
      windDirDeg = 95.0,
      description = "Dry heat, brighter skies, and stronger crosswinds across the open desert."
    },
    COAST = {
      label = "Coast",
      kind = "RAIN",
      baseWeather = "OVERCAST",
      rain = 0.12,
      snow = 0.0,
      windAdd = 2.3,
      tempAdd = -1.7,
      lightningChance = 0.01,
      timecycle = nil,
      windDirDeg = 255.0,
      description = "Marine layer, sea breeze, and moodier shoreline weather near the Pacific."
    },
    COUNTRYSIDE = {
      label = "Countryside",
      kind = "CLEAR",
      baseWeather = "CLOUDS",
      rain = 0.05,
      snow = 0.0,
      windAdd = 1.0,
      tempAdd = -0.2,
      lightningChance = 0.00,
      timecycle = nil,
      windDirDeg = 180.0,
      description = "Balanced inland weather with gentle winds and slower-moving regional changes."
    },
    MOUNTAINS = {
      label = "Mountains",
      kind = "SNOW",
      baseWeather = "OVERCAST",
      rain = 0.06,
      snow = 0.12,
      windAdd = 2.8,
      tempAdd = -4.8,
      lightningChance = 0.00,
      timecycle = "micheal",
      windDirDeg = 315.0,
      description = "Higher elevations stay colder, windier, and flip to snow far sooner than the lowlands."
    },
    CUSTOM = {
      label = "Custom",
      kind = "CLEAR",
      baseWeather = "CLEAR",
      rain = 0.0,
      snow = 0.0,
      windAdd = 0.0,
      tempAdd = 0.0,
      lightningChance = 0.00,
      timecycle = nil,
      description = "Custom regional zone."
    },
  },
  defaultZones = {
    {
      label = "Los Santos Core",
      profile = "CITY",
      x = 220.0,
      y = -860.0,
      r = 1450.0,
      intensity = 0.92,
      priority = 4,
    },
    {
      label = "South LS & Port",
      profile = "COAST",
      x = 620.0,
      y = -1910.0,
      r = 1125.0,
      intensity = 0.86,
      priority = 3,
    },
    {
      label = "Del Perro Coast",
      profile = "COAST",
      x = -1510.0,
      y = -780.0,
      r = 1525.0,
      intensity = 0.90,
      priority = 3,
    },
    {
      label = "Great Chaparral",
      profile = "COUNTRYSIDE",
      x = -820.0,
      y = 1180.0,
      r = 1450.0,
      intensity = 0.76,
      priority = 2,
    },
    {
      label = "Alamo Foothills",
      profile = "COUNTRYSIDE",
      x = 980.0,
      y = 2050.0,
      r = 1125.0,
      intensity = 0.74,
      priority = 2,
    },
    {
      label = "Grand Senora Basin",
      profile = "DESERT",
      x = 1640.0,
      y = 3190.0,
      r = 1525.0,
      intensity = 0.93,
      priority = 4,
    },
    {
      label = "Grapeseed Flats",
      profile = "COUNTRYSIDE",
      x = 1765.0,
      y = 4680.0,
      r = 1160.0,
      intensity = 0.72,
      priority = 2,
    },
    {
      label = "Mount Chiliad",
      profile = "MOUNTAINS",
      x = -560.0,
      y = 5180.0,
      r = 1480.0,
      intensity = 0.95,
      priority = 4,
    },
    {
      label = "Paleto Coast",
      profile = "COAST",
      x = -90.0,
      y = 6260.0,
      r = 1180.0,
      intensity = 0.82,
      priority = 3,
    },
  }
}
