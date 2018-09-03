--[[

    Copyright (C) 2018 Masatoshi Fukunaga

    lib/util.lua
    tempest
    Created by Masatoshi Fukunaga on 18/09/03

--]]
--- file-scope variables
local isa = require('isa')
local select = select
local strfind = string.find
local strformat = string.format
local strmatch = string.match
local strsub = string.sub
local tonumber = tonumber
local tostring = tostring
--- constants
local KILO = 1000
local MEGA = KILO * 1000
local GIGA = MEGA * 1000
local TERA = GIGA * 1000
local PETA = TERA * 1000
local EXA = PETA * 1000



--- touint
-- @param str
-- @param def
-- @param min
-- @param max
-- @return val
-- @return err
local function touint( v, def, min, max )
    if v then
        v = tonumber( v, 10 )
        if not v or not isa.uint(v) then
            return nil, 'must be unsigned integer'
        elseif min and v < min then
            return nil, strformat( 'must be greater than or equal to %d', min )
        elseif max and v > max then
            return nil, strformat( 'must be less than or equal to %d', max )
        end

        return v
    end

    return def
end


--- tomsec
-- @param str
-- @param def
-- @param min
-- @param max
-- @return val
-- @return err
local function tomsec( v, def, min, max )
    if v then
        local num, unit = strmatch( v, '^(%d+)([^%d].*)$' )
        local err
        local mul = 1

        if unit then
            -- check time-unit
            if unit == 's' then
                mul = 1000
            elseif unit == 'm' then
                mul = 60 * 1000
            elseif unit == 'h' then
                mul = 60 * 60 * 1000
            elseif unit == 'd' then
                mul = 60 * 60 * 24 * 1000
            else
                return nil, 'time-unit must be uint[s / m / h / d]'
            end
        end

        -- check numeric value
        v, err = touint( num or v, 10 )
        if err then
            return nil, err
        end

        -- multiply
        v, err = touint( v * mul, def, min, max )
        if err then
            return nil, err
        end

        return v
    end

    return def
end


--- toaddr
-- @param str
-- @return port
-- @return host
-- @return err
local function toaddr( v )
    if v then
        local head = strfind( v, ':', 1, true )
        local host = '127.0.0.1'
        local port, err

        if not head then
            return nil, nil, 'port-number must be defined'
        end

        -- check port-number
        port, err = touint( strsub( v, head + 1 ), nil, 1, 65535 )
        if err then
            return nil, nil, 'port-number ' .. err
        elseif head > 1 then
            -- extract host
            host = strsub( v, 1, head - 1 )
        end

        return port, host
    end

    return nil, nil, 'must be defined'
end


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


--- tosiunit
-- @param n
-- @return n
-- @return siname
local function tosiunit( n )
    if n >= EXA then
        return n / EXA, 'E'
    elseif n >= PETA then
        return n / PETA, 'P'
    elseif n >= TERA then
        return n / TERA, 'T'
    elseif n >= GIGA then
        return n / GIGA, 'G'
    elseif n >= MEGA then
        return n / MEGA, 'M'
    elseif n >= KILO then
        return n / KILO, 'k'
    end

    return n, ' '
end


return {
    touint = touint,
    tomsec = tomsec,
    toaddr = toaddr,
    tostrv = tostrv,
    tosiunit = tosiunit,
}
