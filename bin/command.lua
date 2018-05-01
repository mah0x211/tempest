--[[

    Copyright (C) 2018 Masatoshi Fukunaga

    bin/command.lua
    tempest
    Created by Masatoshi Fukunaga on 18/03/09

--]]
require('signal').blockAll()
local tempest = require('tempest')
local getopts = require('tempest.getopts')
local opts = getopts(...)

log('start')

local ok, err = require('act').run( tempest, opts )
if not ok then
    log.err( err )
end

log('done')


