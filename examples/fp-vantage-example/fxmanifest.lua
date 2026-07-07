fx_version 'cerulean'
game 'gta5'

author 'Flarepoint'
name 'fp-vantage-example'
description 'Example showing how to call the Vantage FiveM resource exports'
version '0.1.0'

-- fp-vantage must start before this resource so its exports exist.
dependency 'fp-vantage'

server_script 'server.lua'
