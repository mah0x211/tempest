--[[

    Copyright (C) 2018 Masatoshi Fukunaga

    bin/command.lua
    tempest
    Created by Masatoshi Fukunaga on 18/03/09

--]]
require('signal').blockAll()
local Tempest = require('tempest')
local getopts = require('tempest.getopts')
local opts = getopts(...)

if opts.loglevel then
    require('tempest.logger').setlevel( opts.loglevel )
end
log('start')

local ok, err = require('act').run(function()
    local t = Tempest.new( opts.worker )
    local stats, err, timeout = t:execute( opts, 1000 )

    if err then
        log.err( err )
    elseif timeout then
        log.err( 'timeout' )
    else
        Tempest.printStats( stats )
    end
end)
if not ok then
    log.err( err )
end


