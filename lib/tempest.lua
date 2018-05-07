--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/tempest.lua
  tempest
  Created by Masatoshi Fukunaga on 18/03/09

--]]
--- file scope variables
require('tempest.bootstrap')
local isa = require('isa')
local kill = require('signal').kill
local killpg = require('signal').killpg
local handleWorker = require('tempest.worker')
local IPC = require('tempest.ipc')
local strformat = string.format


--- collectStats
-- @param ipc
-- @param nstat
-- @return stats
local function collectStats( ipc, nstat )
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

    for i = 1, nstat do
        local stat = ipc:read( 1000 )

        if stat then
            stats[i] = stat
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


--- stopWorkers
-- @param pids
-- @param abort
-- @return nterm
local function stopWorkers( pids, abort )
    if #pids == 0 then
        return 0
    elseif abort == true then
        local ok, err = killpg( SIGUSR2 )

        if not ok then
            log.err( 'failed to stopWorkers():', err )
            -- killpg remaining child-processes
            for i = 1, #pids do
                kill( SIGKILL, pids[i] )
            end

            return 0
        end
    end

    local nterm = 0

    log.verbose( 'waitpid:', pids )
    for _ = 1, 10 do
        local remain = {}

        sleep(500)
        -- waiting child-process exit
        for i = 1, #pids do
            local pid = pids[i]
            local stat, err = waitpid( pid )

            if err then
                log.err( 'failed to stopWorkers():', err )
            -- child-process is not terminated
            elseif not stat or not stat.exit and not stat.termsig and
                   not stat.nochild then
                remain[#remain + 1] = pid
            else
                nterm = nterm + 1
            end
        end

        -- all child processes terminated
        pids = remain
        if #pids == 0 then
            return nterm
        end
    end

    -- kill remaining child-processes
    for i = 1, #pids do
        log.verbose( 'kill( SIGKILL,', pids[i], ')' )
        kill( SIGKILL, pids[i] )
    end

    return nterm
end


--- startWorkers
-- @return ok
local function startWorkers()
    local ok, err = killpg( SIGUSR1 )

    if not ok then
        log.err( 'failed to startWorkers():', err )
        return false
    end

    return true
end


--- createWorkers
-- @param opts
-- @return pids
-- @return ipc
local function createWorkers( opts )
    local ipc = IPC.new()

    if ipc then
        local nworker = opts.worker
        local nclient = opts.client
        local pids = {}

        for i = 1, nworker do
            -- create child-process
            local pid, err, again = fork()

            if err then
                log.err( 'failed createWorkers():', err )
                ipc:close()
                stopWorkers( pids, true )
                break
            elseif again then
                log.err(
                    'failed createWorkers(): number of process limits exceeded'
                )
                ipc:close()
                stopWorkers( pids, true )
                break
            -- run in child process
            elseif pid == 0 then
                handleWorker( ipc, opts, nclient )
                break
            else
                local msg

                -- save child-pid
                pids[#pids + 1] = pid
                log.verbose( 'spawn worker', pid )

                -- wait a ready-message from worker
                msg = ipc:read(1000)
                if not msg then
                    ipc:close()
                    stopWorkers( pids, true )
                    break
                elseif not isa.string( msg ) or msg ~= 'ready' then
                    log.err(
                        'failed to createWorkers(): unknown ipc message - ', msg
                    )
                    ipc:close()
                    stopWorkers( pids, true )
                    break
                end

                -- nworker has been created
                if i == nworker then
                    return pids, ipc
                end
            end
        end
    end
end


--- tempest
-- @param opts
local function tempest( opts )
    local pids, ipc = createWorkers( opts )

    if pids then
        local abort = not startWorkers( ipc )
        local nterm

        if not abort then
            local signo, serr = sigwait( opts.duration, SIGINT )

            if serr then
                abort = true
                log.err( 'failed to sigwait()', serr )
            elseif signo then
                abort = true
                log.notice( 'abort by SIGINT' )
            end
        end

        nterm = stopWorkers( pids, abort )
        if not abort then
            printStats( collectStats( ipc, nterm ) )
        end
    else
        log.verbose( 'done worker' )
    end
end


return tempest
