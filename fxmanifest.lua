fx_version "cerulean"
game "gta5"

name "az_weatherfronts"
author "Azure"
description "Moving weather fronts + storm chasing + gusts (synced) + naming/severity/forecast/alerts/biomes"
version "1.2.2"

shared_scripts {
  "config.lua",
  "shared.lua"
}

server_script "server.lua"
client_script "client.lua"



ui_page 'html/index.html'

files {
  'html/index.html',
  'html/index.js',
  'html/map-road.jpg',
  'html/map-atlas.jpg',
  'html/leaflet.js',
  'html/leaflet.css'
}


