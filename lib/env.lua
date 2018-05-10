--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/env.lua
  tempest
  Created by Masatoshi Fukunaga on 18/05/10

--]]
local strformat = string.format
local tostring = tostring
local GLOBALIDX = {
    -- standard libs
    _VERSION = _VERSION,
    assert = assert,
    error = error,
    ipairs = ipairs,
    math = math,
    next = next,
    pairs = pairs,
    pcall = pcall,
    print = print,
    select = select,
    string = string,
    table = table,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    unpack = unpack,
    xpcall = xpcall,
    -- custom libs
    dump = require('dump'),
}
GLOBALIDX._G = GLOBALIDX

return setmetatable({}, {
    __metatable = 1,
    __newindex = function( _, k )
        error( strformat(
            'attempt to create global variable: %q', tostring( k )
        ), 2 )
    end,
    __index = GLOBALIDX
})

