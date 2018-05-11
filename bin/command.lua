--[[

    Copyright (C) 2018 Masatoshi Fukunaga

    bin/command.lua
    tempest
    Created by Masatoshi Fukunaga on 18/03/09

--]]
require('signal').blockAll()
local Tempest = require('tempest')
local Script = require('tempest.script')
local getopts = require('tempest.getopts')
local strformat = string.format
local opts = getopts(...)


-- print execution parameters
print(strformat([[
tempest run with following options;
-----------------------------------
    address: %q
     worker: %s
     client: %s
   duration: %s
   rcvtimeo: %s
   sndtimeo: %s
     script: %q
   loglevel: %s
-----------------------------------]],
    opts[-1].addr, opts[-1].worker, opts[-1].client, opts[-1].duration,
    opts[-1].rcvtimeo, opts[-1].sndtimeo, opts[-1].script,
    opts[-1].loglevel
))


-- set loglevel
if opts.loglevel then
    require('tempest.logger').setlevel( opts.loglevel )
end


-- compile scriptFile
if opts.scriptFile then
    local chunk, err = Script.compileFile( opts.script )
    if err then
        log.err( strformat('failed to compile script %q:', opts.script ), err )
        return
    end

    opts.chunk = chunk
end


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


