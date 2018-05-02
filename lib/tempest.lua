--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/tempest.lua
  tempest
  Created by Masatoshi Fukunaga on 18/03/09

--]]
--- file scope variables
require('tempest.bootstrap')
local kill = require('signal').kill
local killpg = require('signal').killpg
local pipe = require('act.pipe')
local handleWorker = require('tempest.worker')


--- stopWorkers
-- @param pids
local function stopWorkers( pids, abort )
    if #pids == 0 then
        return
    elseif abort == true then
        local ok, err = killpg( SIGUSR2 )

        if not ok then
            log.err( 'failed to stopWorkers():', err )
            -- killpg remaining child-processes
            for i = 1, #pids do
                kill( SIGKILL, pids[i] )
            end
        end
    end

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
            end
        end

        -- all child processes terminated
        pids = remain
        if #pids == 0 then
            return
        end
        log(remain)
    end

    -- kill remaining child-processes
    for i = 1, #pids do
        log.warn( '[main] kill( SIGKILL,', pids[i], ')' )
        kill( SIGKILL, pids[i] )
    end
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
    -- calc a number of clients per worker
    local nworker = opts.worker
    local nclient = opts.client
    local pids = {}
    local ipc, perr = pipe.new()

    if perr then
        log.err( 'failed createWorkers():', perr )
        return
    end

    for _ = 1, nworker do
        -- create child-process
        local pid, err, again = fork()

        if err then
            log.err( 'failed createWorkers():', err )
            ipc:close()
            stopWorkers( pids, true )
            return
        elseif again then
            log.err(
                'failed createWorkers(): number of process limits exceeded'
            )
            ipc:close()
            stopWorkers( pids, true )
            return
        -- run in child process
        elseif pid == 0 then
            handleWorker( ipc, opts, nclient )
            return
        end

        -- save child-pid
        pids[#pids + 1] = pid
        log.verbose( 'spawn worker', pid )
    end

    return pids, ipc
end


--- tempest
-- @param opts
local function tempest( opts )
    local pids, ipc = createWorkers( opts )

    if pids then
        local abort = not startWorkers( ipc )

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

        stopWorkers( pids, abort )
    else
        log.verbose( 'done worker' )
    end
end


return tempest
