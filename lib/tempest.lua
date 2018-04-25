--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/tempest.lua
  tempest
  Created by Masatoshi Fukunaga on 18/03/09

--]]
--- file scope variables
local getopts = require('tempest.getopts')

--- main
-- @param arg, ...
local function main(...)
    local opts = getopts(...)

    log( 'start' )
    log( opts )
    log( 'done' )
end


return main
