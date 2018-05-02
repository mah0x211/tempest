--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/log.lua
  tempest
  Created by Masatoshi Fukunaga on 18/03/15

--]]

local getpid = require('process').getpid
local dump = require('dump')
local select = select
local type = type
local tostring = tostring
local write = io.write
local date = os.date;
local format = string.format
local concat = table.concat
local getinfo = debug.getinfo
--- constants
local EMPTY_INFO = {}
local ERROR = 0
local INFO = 1
local WARNING = 2
local NOTICE = 3
local VERBOSE = 4
local DEBUG = 5
local ISO8601_FMT = '%FT%T%z'
local LOG_LEVEL_FMT = {
    [ERROR]     = '%s [%d:error] ',
    [INFO]      = '%s [%d:info] ',
    [WARNING]   = '%s [%d:warn] ',
    [NOTICE]    = '%s [%d:notice] ',
    [VERBOSE]   = '%s [%d:verbose] ',
    [DEBUG]     = '%s [%d:debug:%s:%d] ',
}
--- file-scope variables
local OUPUT_LOG_LEVEL = DEBUG


--- tostrv - returns a string-vector
-- @param ...
-- @return strv
local function tostrv( ... )
    local argv = {...}
    local narg = select( '#', ... )
    local strv = {}
    local t, v

    -- convert to string
    for i = 1, narg do
        v = argv[i]
        t = type( v )
        if t == 'string' then
            strv[i] = v
        elseif t == 'table' then
            strv[i] = dump( v, 0 )
        else
            strv[i] = tostring( v )
        end
    end

    return strv
end


--- output
-- @param lv
-- @param info
-- @param ...
local function output( lv, info, ... )
    if lv <= OUPUT_LOG_LEVEL then
        write( format( LOG_LEVEL_FMT[lv],
            date( ISO8601_FMT ), getpid(), info.short_src, info.currentline
        ), concat( tostrv( ... ), ' ' ), '\n' )
    end
end


local function err( ... )
    output( ERROR, EMPTY_INFO, ... )
end

local function info( ... )
    output( INFO, EMPTY_INFO, ... )
end

local function warn( ... )
    output( WARNING, EMPTY_INFO, ... )
end

local function notice( ... )
    output( NOTICE, EMPTY_INFO, ... )
end

local function verbose( ... )
    output( VERBOSE, EMPTY_INFO, ... )
end

local function debug( ... )
    output( DEBUG, getinfo( 2, 'Sl' ), ... )
end


--- create logger to global
_G.log = setmetatable({
    err = err,
    info = info,
    warn = warn,
    notice = notice,
    verbose = verbose,
    debug = debug,
},{
    __call = function( _, ... )
        info( ... )
    end
})


--- setlevel
-- @param lv
-- @return ok
local function setlevel( lv )
    if LOG_LEVEL_FMT[lv] then
        OUPUT_LOG_LEVEL = lv
        return true
    end

    log.err('failed to setlevel(): invalid log-level')
    return false
end


return {
    ERROR = ERROR,
    INFO = INFO,
    WARNING = WARNING,
    NOTICE = NOTICE,
    VERBOSE = VERBOSE,
    DEBUG = DEBUG,
    setlevel = setlevel,
}
