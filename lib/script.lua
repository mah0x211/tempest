--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/script.lua
  tempest
  Created by Masatoshi Fukunaga on 18/03/19

--]]

local loadchunk = require('loadchunk')
local normalize = require('path').normalize
local tofile = require('path').tofile
local getcwd = require('process').getcwd
local strformat = string.format
local strsub = string.sub
local strdump = string.dump
-- constants
local ENV = require('tempest.env')


--- realpath
-- @param pathname
-- @return str
-- @return err
local function realpath( pathname )
    if strsub( pathname, 1, 1 ) ~= '/' then
        return tofile( normalize( getcwd(), pathname ) )
    end

    return tofile( normalize( pathname ) )
end


--- compileFile
-- @param pathname
-- @return chunk
-- @return err
local function compileFile( pathname )
    local fullpath, err = realpath( pathname )
    local fn

    if err then
        return nil, err
    elseif not fullpath then
        return nil, strformat( '%q not found', pathname )
    end

    fn, err = loadchunk.file( fullpath )
    if err then
        return nil, err
    end

    return strdump( fn )
end


return {
    compileFile = compileFile,
}

