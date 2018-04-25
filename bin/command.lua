--[[

    Copyright (C) 2018 Masatoshi Fukunaga

    bin/command.lua
    tempest
    Created by Masatoshi Fukunaga on 18/03/09

--]]
--- define log global variable
require('tempest.logger')

-- export act functions to global except 'run' function
for k, v in pairs( require('act') ) do
    if type( k ) == 'string' and k ~= 'run' and type( v ) == 'function' then
        _G[k] = v
    end
end

-- export signal numbers to global
for k, v in pairs( require('signal') ) do
    if type( k ) == 'string' and k:find('^SIG') then
        _G[k] = v
    end
end

_G.dump = require('dump')
require('signal').blockAll()
assert(
    require('act').run(
        require('tempest'), ...
    )
)
