--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/tempest.lua
  tempest
  Created by Masatoshi Fukunaga on 18/03/09

--]]
--- file scope variables
require('tempest.bootstrap')
local killpg = require('signal').killpg
local Stats = require('tempest.stats')
local Worker = require('tempest.worker')
local strformat = string.format
--- constants
local KILO = 1000
local MEGA = KILO * 1000
local GIGA = MEGA * 1000
local TERA = GIGA * 1000
local PETA = TERA * 1000
local EXA = PETA * 1000
local UNIT_SYMBOL = {
    [KILO] = 'k',
    [MEGA] = 'M',
    [GIGA] = 'G',
    [TERA] = 'T',
    [PETA] = 'P',
    [EXA] = 'E',
}
local WIDTH = 0.5
local NGRAF = 100 * WIDTH
local HYPHENS = ''
local GRAPH = {
    [0] = ''
}

for _ = 1, NGRAF do
    HYPHENS = HYPHENS .. '-'
end

for i = 0, NGRAF do
    local mark = ''

    for _ = 1, i do
        mark = mark .. '*'
    end

    for _ = i + 1, NGRAF do
        mark = mark .. ' '
    end

    GRAPH[i] = mark
end


local function printf( fmt, ... )
    print( strformat( fmt, ... ) )
end


--- toReadable
local function toReadable( n )
    assert( type( n ) == 'number', 'invalid argument' )
    -- GB
    if n > 1000000000 then
        return n / 1000000000, 'GB'
    -- MB
    elseif n > 1000000 then
        return n / 1000000, 'MB'
    -- KB
    elseif n > 1000 then
        return n / 1000, 'KB'
    end

    return n, 'B'
end


--- printStats
-- @param stats
local function printStats( stats )
    local sbyte, sunit = toReadable( stats.bytesSent )
    local rbyte, runit = toReadable( stats.bytesRecv )
    local sbyte_sec, sunit_sec = toReadable( stats.bytesSent / stats.elapsed )
    local rbyte_sec, runit_sec = toReadable( stats.bytesRecv / stats.elapsed )

    printf([[

[Requests]
 total reqs: %d success and %d failure in %f sec
       reqs: %f/s

[Transfer]
 total send: %.4f %s
 total recv: %.4f %s
       send: %.4f %s/s
       recv: %.4f %s/s

[Errors]
    connect: %d
       recv: %d
       send: %d
 recv timeo: %d
 send timeo: %d
   internal: %d
]],
        stats.success, stats.failure, stats.elapsed,
        stats.success / stats.elapsed,
        sbyte, sunit,
        rbyte, runit,
        sbyte_sec, sunit_sec,
        rbyte_sec, runit_sec,
        stats.econnect,
        stats.erecv,
        stats.esend,
        stats.erecvTimeo,
        stats.esendTimeo,
        stats.einternal
    )

    printf([[
[Latency]
    minimum: %.2f ms
    maximum: %.2f ms
    average: %.2f ms

[Histogram]
    latency   #reqs  %s  percentage    time-range
------------+-------+%s+-------------+-----------------]],
        stats.latency_msec[1],
        stats.latency_msec[#stats.latency_msec],
        stats.latency_msec.avg,
        GRAPH[0], HYPHENS
    )

    -- histogram
    for i = 1, #stats.latency_msec_grp do
        local mgrp = stats.latency_msec_grp[i]
        local nreq = mgrp.nreq
        local ratio = nreq / stats.success
        local unit = 1

        if nreq >= EXA then
            unit = EXA
        elseif nreq >= PETA then
            unit = PETA
        elseif nreq >= TERA then
            unit = TERA
        elseif nreq >= GIGA then
            unit = GIGA
        elseif nreq >= MEGA then
            unit = MEGA
        elseif nreq >= KILO then
            unit = KILO
        end

        printf(
            '%8d ms | %3d %s |%s| %9.5f %% | %.2f-%.2f ms',
            mgrp.msec,
            nreq / unit,
            UNIT_SYMBOL[unit] or ' ',
            GRAPH[math.floor(ratio * 100 * WIDTH)],
            ratio * 100,
            mgrp.min, mgrp.max
        )
    end
    print('')
end


--- collectStats
-- @param stats
-- @param workers
-- @param msec
-- @return stats
local function collectStats( stats, workers, msec )
    stats.started = 0
    stats.stopped = 0
    for i = 1, #workers do
        local stat, err, timeout  = workers[i]:stat( msec )

        stats[workers[i].pid] = {
            stat = stat,
            err = err,
            timeout = timeout
        }
        if stat then
            if stats.started == 0 or stats.started > stat.started then
                stats.started = stat.started
            end
            if stats.stopped == 0 or stats.stopped < stat.stopped then
                stats.stopped = stat.stopped
            end
        end
    end

    stats.elapsed = stats.stopped - stats.started

    return stats
end


--- closeWorkers
-- @param workers
local function closeWorkers( workers )
    for i = 1, #workers do
        workers[i]:close()
    end
end


--- class
local Tempest = {}


--- execute
-- @param opts
-- @param msec
-- @return stats
-- @return err
-- @return timeout
function Tempest:execute( opts, msec )
    local workers = {}
    local client = opts.client
    local surplus = client % self.nworker
    local nclient = ( client - surplus ) / self.nworker

    for i = 1, self.nworker do
        -- manipulate number of clients
        if surplus > 0 then
            surplus = surplus - 1
            opts.nclient = nclient + 1
        else
            opts.nclient = nclient
        end

        -- create worker
        local w, err, again = Worker.new( self.stats, opts )

        if not w then
            closeWorkers( workers )
            if again then
                return nil, 'cannot create worker'
            end

            return nil, err
        end
        workers[i] = w
    end

    -- start all workers
    sleep(500)
    local ok, err = killpg( SIGUSR1 )
    if not ok then
        closeWorkers( workers )
        return nil, err
    end

    -- wait
    local _, serr, timeout = sigwait( opts.duration, SIGINT )

    if serr then
        closeWorkers( workers )
        return nil, err
    elseif not timeout then
        closeWorkers( workers )
        return nil, 'aborted'
    end

    -- collect stats
    local stats = collectStats( self.stats:data(), workers, msec )
    closeWorkers( workers )

    return stats
end


--- new
-- @param nworker
-- @param msec
-- @return tempest
-- @return err
local function new( nworker, msec )
    local stats, err = Stats.new( msec )

    if err then
        return nil, err
    end

    return setmetatable({
        stats = stats,
        nworker = nworker
    }, {
        __index = Tempest
    })
end


return {
    new = new,
    printStats = printStats,
}

