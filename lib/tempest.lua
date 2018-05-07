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
local strformat = string.format


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

    print(strformat([[

Requests:
  total requests: %d in %f sec
    requests/sec: %f
Transfer
      total send: %.4f %s
      total recv: %.4f %s
        send/sec: %.4f %s
        recv/sec: %.4f %s
Errors
         connect: %d
            recv: %d
            send: %d
    recv timeout: %d
    send timeout: %d
        internal: %d
]],
        stats.nrecv, stats.elapsed,
        stats.nrecv / stats.elapsed,
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
    ))
end


--- collectStats
-- @param workers
-- @param msec
-- @return stats
local function collectStats( workers, msec )
    local stats = {
        started = 0,
        stopped = 0,
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

    for i = 1, self.nworker do
        local w, err, again = Worker.new()

        -- failed to create worker
        if not w then
            closeWorkers( workers )
            if again then
                return nil, 'cannot create worker'
            end

            return nil, err
        end
        workers[i] = w

        local ok, timeout
        ok, err, timeout = w:request( req, msec )
        if not ok then
            closeWorkers( workers )
            return nil, err, timeout
        end
    end

    -- start all workers
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

