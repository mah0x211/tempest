--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/eval.lua
  tempest
  Created by Masatoshi Fukunaga on 18/03/19

--]]

local loadchunk = require('loadchunk')
local normalize = require('path').normalize
local tofile = require('path').tofile
local strformat = string.format
-- constants
local ENV = require('tempest.env')


--- realpath
-- @param pathname
-- @return str
-- @return err
local function realpath( pathname )
    return tofile( normalize( pathname ) )
end


--- eval
-- @param pathname
-- @return fn
-- @return err
local function eval( pathname )
    local fullpath, err = realpath( pathname )

    if err then
        return nil, err
    elseif not fullpath then
        return nil, strformat( '%q not found', pathname )
    end

    return loadchunk.file( fullpath, ENV )
end


return eval

