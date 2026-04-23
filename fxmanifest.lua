fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'faesslich_pedmanager'
author 'Faesslich'
description 'Ped manager with React NUI for FiveM ESX/QBCore'
version '0.0.1'

shared_scripts {
    '@ox_lib/init.lua',
    'locales/*.lua',
    'config/config.lua',
    'config/peds.lua',
    'bridge/shared.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'web/dist/index.html'

files {
    'web/dist/*.html',
    'web/dist/assets/**',
    'web/dist/assets/**/*',
}
