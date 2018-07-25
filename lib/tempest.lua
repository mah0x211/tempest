--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/tempest.lua
  tempest
  Created by Masatoshi Fukunaga on 18/03/09

--]]
--- file scope variables
require('tempest.bootstrap')
local killpg = require('signal').killpg
local Worker = require('tempest.worker')
local Array = require('tempest.array')
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
    local sbyte, sunit = toReadable( stats.bytes_sent )
    local rbyte, runit = toReadable( stats.bytes_recv )
    local sbyte_sec, sunit_sec = toReadable( stats.bytes_sent / stats.elapsed )
    local rbyte_sec, runit_sec = toReadable( stats.bytes_recv / stats.elapsed )

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
        stats.erecvtimeo,
        stats.esendtimeo,
        stats.einternal
    )

    if stats.latency then
        local data, head, tail = stats.latency:data()
        local latencies = {}
        local idx = 0
        local avg = 0
        local nth = 0
        local max = 0

        -- collect
        for i = head, tail do
            local nreq = data[i]

            if nreq then
                local msec = i / 100
                local msecf = math.floor( msec )
                local unit = 1

                avg = avg + i
                nth = nth + 1
                if latencies[idx] and latencies[idx].msec == msecf then
                    unit = latencies[idx].unit
                    nreq = latencies[idx].nreq + nreq
                    latencies[idx].nreq = nreq
                    latencies[idx].max = msec
                else
                    idx = idx + 1
                    latencies[idx] = {
                        nreq = nreq,
                        msec = msecf,
                        min = msec,
                        max = msec,
                    }
                end

                if nreq > max then
                    max = nreq
                end

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
                latencies[idx].unit = unit
            end
        end

        printf([[
[Latency]
    minimum: %.2f ms
    maximum: %.2f ms
    average: %.2f ms

[Histogram]
    latency   #reqs  %s  percentage    time-range
------------+-------+%s+-------------+-----------------]],
            latencies[1].min, latencies[idx].max, avg / nth / 100,
            GRAPH[0], HYPHENS
        )

        -- histogram
        local padding = stats.success/ max

        for i = 1, idx do
            local latency = latencies[i]
            local ratio = latency.nreq / stats.success

            printf(
                '%8d ms | %3d %s |%s| %9.5f %% | %.2f-%.2f ms',
                latency.msec,
                latency.nreq / latency.unit,
                UNIT_SYMBOL[latency.unit] or ' ',
                GRAPH[math.floor(ratio * padding * NGRAF)],
                ratio * 100,
                latency.min, latency.max
            )
        end
        print('')
    end
end


--- collectStats
-- @param workers
-- @param msec
-- @return stats
local function collectStats( workers, msec )
    local stats = {
        started = 0,
        stopped = 0,
        success = 0,
        failure = 0,
        bytes_sent = 0,
        bytes_recv = 0,
        nsend = 0,
        nrecv = 0,
        econnect = 0,
        einternal = 0,
        esend = 0,
        erecv = 0,
        esendtimeo = 0,
        erecvtimeo = 0,
    }

    for i = 1, #workers do
        local stat, err, timeout  = workers[i]:stat( msec )

        stats[workers[i].pid] = {
            stat = stat,
            err = err,
            timeout = timeout
        }

        if stat then
            if stat.latency then
                local latency = Array.decode( stat.latency )

                if stats.latency then
                    stats.latency:merge( latency )
                else
                    stats.latency = latency
                end
            end

            stats.success = stats.success + stat.success
            stats.failure = stats.failure + stat.failure
            stats.bytes_recv = stats.bytes_recv + stat.bytes_recv
            stats.bytes_sent = stats.bytes_sent + stat.bytes_sent
            stats.econnect = stats.econnect + stat.econnect
            stats.einternal = stats.einternal + stat.einternal
            stats.erecv = stats.erecv + stat.erecv
            stats.erecvtimeo = stats.erecvtimeo + stat.erecvtimeo
            stats.esend = stats.esend + stat.esend
            stats.esendtimeo = stats.esendtimeo + stat.esendtimeo
            stats.nrecv = stats.nrecv + stat.nrecv
            stats.nsend = stats.nsend + stat.nsend
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
-- @param req
-- @param msec
-- @return stats
-- @return err
-- @return timeout
function Tempest:execute( req, msec )
    local workers = {}
    local client = req.client
    local surplus = client % self.nworker
    local nclient = ( client - surplus ) / self.nworker

    for i = 1, self.nworker do
        -- manipulate number of clients
        if surplus > 0 then
            surplus = surplus - 1
            req.nclient = nclient + 1
        else
            req.nclient = nclient
        end

        -- create worker
        local w, err, again = Worker.new( req )

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
    local _, serr, timeout = sigwait( req.duration, SIGINT )

    if serr then
        closeWorkers( workers )
        return nil, err
    elseif not timeout then
        closeWorkers( workers )
        return nil, 'aborted'
    end

    -- collect stats
    local stats = collectStats( workers, msec )
    closeWorkers( workers )

    return stats
end


--- new
-- @param nworker
-- @return tempest
-- @return err
local function new( nworker )
    return setmetatable({
        nworker = nworker
    }, {
        __index = Tempest
    })
end


return {
    new = new,
    printStats = printStats,
}

