--[[

    Copyright (C) 2018 Masatoshi Fukunaga

    lib/getopts.lua
    tempest
    Created by Masatoshi Fukunaga on 18/03/12

--]]
--- file-scope variables
local isa = require('isa')
local logger = require('tempest.logger')
local EchoHandler = require('tempest.handler.echo')
local compileFunc = require('tempest.script').compileFunc
local compileFile = require('tempest.script').compileFile
local strsplit = require('string.split')
local error = error
local pairs = pairs
local print = print
local select = select
local strfind = string.find
local strformat = string.format
local strmatch = string.match
local strsub = string.sub
local toupper = string.upper
local tonumber = tonumber
local tostring = tostring
local unpack = unpack or table.unpack


--- parseOptargs
-- @param optargs
-- @return opts
-- @return longopts
local function parseOptargs( optargs )
    local opts = {}
    local longopts = {}

    if optargs then
        for k, v in pairs( optargs ) do
            local sname, name, noarg

            -- long-name
            if isa.number( k ) then
                name, noarg = unpack( strsplit( v, ':', 1 ) )
            -- invalid type
            elseif not isa.string( k ) then
                error( strformat( 'invalid type of optargs %q', tostring( k ) ) )
            -- long-name
            elseif #k > 1 then
                name = k
                noarg = v
            -- short-name
            else
                sname = '-' .. k
                name, noarg = unpack( strsplit( v, ':', 1 ) )
            end

            longopts[name] = noarg and noarg == 'true' or false
            if sname then
                opts[sname] = name
            end
        end
    end

    return opts, longopts
end


--- getargs
-- @param optargs
-- @param ...
-- @return args
-- @return err
local function getargs( optargs, ... )
    local args = {}
    local argv = {...}
    local narg = select( '#', ... )
    local idx = 1
    local shortnames, longnames = parseOptargs( optargs )

    while idx <= narg do
        local arg = argv[idx]
        local head, tail = strfind( arg, '^-+' )

        idx = idx + 1
        -- not found hyphen(-) prefixed
        if not head then
            args[#args + 1] = arg
        -- found short-name '-o'
        elseif tail == 1 then
            -- unknown option
            if shortnames[arg] == nil then
                return nil, strformat( 'unknown option %q', arg )
            else
                local name = shortnames[arg]
                local noarg = longnames[name]

                if noarg then
                    args[name] = true
                -- use following argument as value
                else
                    args[name] = argv[idx]
                    idx = idx + 1
                end
            end
        -- found long-name '--opt'
        elseif tail == 2 then
            local name, val = unpack(
                strsplit( strsub( arg, tail + 1 ), '=', 1 )
            )

            -- unknown option
            if longnames[name] == nil then
                return nil, strformat( 'unknown option %q', arg )
            -- this option cannot have a value
            elseif longnames[name] then
                if val then
                    return nil, strformat( 'invalid option %q', name )
                end
                val = true
            end

            args[name] = val
        end
    end

    return args
end


--- printUsage
-- @param err
local function printUsage( msg )
    if not msg then
        msg = 'tempest - load testing tool'
    end

    print( msg )
    print([[

Usage:
    tempest [options] address

Options:
    -?                      : show help (this page)
    -w, --worker=<N>        : number of workers (default `1`)
    -c, --client=<N>        : number of clients (default `1`)
    -d, --duration=<time>   : duration (default `5s`)
    -t, --timeout=<time>    : send and recv timeout (default `5s`)
    --rcvtimeo=<time>       : recv timeout  (default same as `-t` value)
    --sndtimeo=<time>       : send timeout  (default same as `-t` value)
    --loglevel=<level>      : set output log-level (default: `debug`)
    -s, --script=<pathname> : scenario script
    address                 : specify target address in the following format;
                              `[host]:port`

NOTE:
    please specify the value of <time> in millisecond(s).
    the value must be greater than or equal to `1000`.

    <time> value supports the following units;

        s                   : second(s), 1s equal to 1000
        m                   : minute(s), 1440m equal to 86400s
        h                   : hour(s), 24h equal to 1440m
        d                   : day(s), 1d equal to 24h

    <level> value supports the followings;

        debug               : output debug log and logs of following levels
        verbose             : output verbose log and logs of following levels
        notice              : output notice log and logs of following levels
        warning             : output warning log and logs of following levels
        info                : output info log and logs of following levels
        error               : output error log
]])
    os.exit()
end


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


local function getopts( ... )
    local opts, err = getargs({
        -- <short-name> = "<long-name>[:<noarg>]"
        -- short-name   : 1 char
        -- long-name    : 1< char
        -- noarg      : true or false (default: false)
        ['?'] = 'help:true',
        w = 'worker',
        c = 'client',
        d = 'duration',
        t = 'timeout',
        s = 'script',
        'rcvtimeo',
        'sndtimeo',
        'loglevel',
    }, ... )
    local raws = {}

    if err then
        printUsage( err )
    -- show help
    elseif opts.help then
        printUsage()
    end

    -- check worker
    opts.worker, err = touint( opts.worker, 1 )
    if err then
        printUsage( 'invalid worker option: ' .. err )
    end
    raws.worker = opts.worker

    -- check client
    opts.client, err = touint( opts.client, 1, 1 )
    if err then
        printUsage( 'invalid client option: ' .. err )
    end
    raws.client = opts.client

    -- check duration
    raws.duration = opts.duration or '5s'
    opts.duration, err = tomsec( opts.duration, 1000 * 5, 1000 * 1 )
    if err then
        printUsage( 'invalid duration option: ' .. err )
    end

    -- check timeout
    raws.timeout = opts.timeout or '1s'
    opts.timeout, err = tomsec( opts.timeout, 1000 * 1, 1000 * 1 )
    if err then
        printUsage( 'invalid timeout option: ' .. err )
    end

    -- check rcvtimeo
    raws.rcvtimeo = opts.rcvtimeo or raws.timeout
    opts.rcvtimeo, err = tomsec( opts.rcvtimeo, opts.timeout, 1000 * 1 )
    if err then
        printUsage( 'invalid rcvtimeo option: ' .. err )
    end

    -- check sndtimeo
    raws.sndtimeo = opts.sndtimeo or raws.timeout
    opts.sndtimeo, err = tomsec( opts.sndtimeo, opts.timeout, 1000 * 1 )
    if err then
        printUsage( 'invalid sndtimeo option: ' .. err )
    end

    -- check loglevel
    raws.loglevel = opts.loglevel or 'debug'
    if opts.loglevel ~= nil then
        local lv = logger[toupper(opts.loglevel)]

        if not isa.uint( lv ) then
            printUsage(strformat(
                'invalid loglevel option: unknown loglevel %q', opts.loglevel
            ))
        end

        opts.loglevel = lv
    end

    -- check addr
    raws.addr = opts[1]
    opts.port, opts.host, err = toaddr( opts[1] )
    if err then
        printUsage( 'invalid address: ' .. err )
    end

    -- check script
    if opts.script then
        opts.chunk, err = compileFile( opts.script )
    -- specify default handler
    else
        opts.script = '<USE BUILT-IN HANDLER>'
        opts.chunk, err = compileFunc( EchoHandler )
    end

    if err then
        printUsage( 'invalid script: ' .. err )
    end

    raws.script = opts.script

    opts[-1] = raws

    return opts
end


return getopts
