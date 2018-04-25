--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/eval.lua
  tempest
  Created by Masatoshi Fukunaga on 18/03/19

--]]

local dump = require('dump')
local loadchunk = require('loadchunk')
local normalize = require('path').normalize
local basename = require('path').basename
local dirname = require('path').dirname
local toDir = require('path').toDir
local toReg = require('path').toReg
local getcwd = require('process').getcwd
local tonumber = tonumber
local tostring = tostring
local error = error
local strformat = string.format
-- constants
local ENV = {}
local ENV_INDEX = {
    dump = dump,
    error = error,
    ipairs = ipairs,
    math = math,
    next = next,
    pairs = pairs,
    print = print,
    require = require,
    select = select,
    string = {},
    table = table,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
}
-- add string functions except dump function
for k, fn in pairs( string ) do
    ENV_INDEX.string[k] = fn
end
ENV_INDEX.string.dump = nil

local ENV_MT = {
    __metatable = 1,
    __index = ENV_INDEX,
    __newindex = function( _, k )
        error(
            ('attempt to create global variable: %q'):format( tostring(k) ), 2
        )
    end
}
local CWD



--- realpath
-- @param pathname
-- @return str
-- @return err
local function realpath( pathname )
    -- resolve CWD
    if not CWD then
        local err

        CWD, err = dirname( pathname )
        if err then
            return nil, err
        end

        CWD, err = toDir( getcwd() .. normalize( CWD ) )
        if err then
            return nil, err
        elseif not CWD then
            return nil, strformat( '%q not found', pathname )
        end

        -- remove dirname(current working dir)
        pathname, err = basename( pathname )
        if err then
            return nil, err
        end
    end

    -- resolve pathname
    return toReg( CWD .. normalize( pathname ) )
end


--- compile
-- @param pathname
-- @return fn
-- @return err
local function compile( pathname )
    local fullpath, err = realpath( pathname )

    if err then
        return nil, err
    elseif not fullpath then
        return nil, strformat( '%q not found', pathname )
    end

    return loadchunk.file( fullpath, ENV )
end


--- eval
-- @param str
-- @param ident
-- @return script
-- @return err
local function eval( pathname, describer )
    local fn, err = compile( pathname )

    if err then
        return nil, err
    end

    -- evaluate
    local old = ENV_INDEX.describe
    ENV_INDEX.describe = describer
    local ok, res = pcall( fn )
    ENV_INDEX.describe = old

    if not ok then
        return nil, res
    -- define describer
    elseif describer then
        return true
    end

    return res
end


--- import
-- @param pathname
-- @return res
local function import( pathname )
    local res, err = eval( pathname )

    if err then
        error( err, 2 )
    end

    return res
end
-- define import function
ENV_INDEX.import = import
-- lock global environment
setmetatable( ENV, ENV_MT )


return eval

