fx_version "cerulean"
game "gta5"

name "Az-WeatherSystem"
author "Azure"
description "Moving weather fronts + storm chasing + gusts (synced) + naming/severity/forecast/alerts/biomes"
version "1.2.1"

shared_scripts {
  "config.lua",
  "shared.lua"
}

server_script "server.lua"
client_script "client.lua"


ui_page 'html/index.html'

files {
  'html/index.html',
  'html/map.png'
}
