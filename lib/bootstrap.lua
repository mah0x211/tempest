--[[

    Copyright (C) 2018 Masatoshi Fukunaga

    lib/bootstrap.lua
    tempest
    Created by Masatoshi Fukunaga on 18/05/01

--]]
--- export log
require('tempest.logger')

-- export signal numbers
for k, v in pairs( require('signal') ) do
    if type( k ) == 'string' and k:find('^SIG') then
        _G[k] = v
    end
end

-- export signal numbers to global
_G.dump = require('dump')

-- export act functions except 'run' function
for k, v in pairs( require('act') ) do
    if type( k ) == 'string' and k ~= 'run' and type( v ) == 'function' then
        _G[k] = v
    end
end
