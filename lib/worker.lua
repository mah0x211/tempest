--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/worker.lua
  tempest
  Created by Masatoshi Fukunaga on 18/04/25

--]]
--- file scope variables
local gettimeofday = require('process').gettimeofday
local handleClient = require('tempest.client')


--- createClients
-- @param nclient
-- @param stat
-- @return cids
local function createClients( nclient, stat )
    local cids = {}

    log.verbose( 'create', nclient, 'client' )
    for i = 1, nclient do
        local cid, err = spawn( handleClient, stat )

        if err then
            log.err( 'failed to createClients():', err )
            return nil
        end
        cids[i] = cid
    end

    return cids
end


--- worker
-- @param ipc
-- @param opt
--  .host
--  .port
--  .rcvtimeo
--  .sndtimeo
-- @param nclient
local function handleWorker( _, opts, nclient )
    local stat = {
        done = false,
        host = opts.host,
        port = opts.port,
        rcvtimeo = opts.rcvtimeo,
        sndtimeo = opts.sndtimeo,
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
    local cids = createClients( nclient, stat )

    if cids then
        local signo, err = sigwait( nil, SIGUSR1, SIGUSR2 )

        if err then
            stat.failure = true
            log.err( 'abort handleWorker():', err )
        elseif signo ~= SIGUSR1 then
            stat.abort = true
            log.notice( 'abort handleWorker()' )
        -- start
        else
            local sec

            -- resume clients
            log.verbose( 'start load testing' )
            for i = 1, #cids do
                resume( cids[i] )
            end

            -- wait signal
            sec = gettimeofday()
            signo, err = sigwait( opts.duration, SIGUSR2 )
            -- calcs the number of completed requests
            stat.elapsed = gettimeofday() - sec
            stat.nreq = stat.nsend - (stat.nsend - stat.nrecv);
            stat.RPS = stat.nreq / stat.elapsed

            if err then
                stat.failure = true
                log.err( 'failed to handleWorker(): stopped by error -', err )
            elseif signo == SIGUSR2 then
                stat.abort = true
                log.notice( 'abort handleWorker(): stopped by signal' )
            else
                log.verbose( 'stopped', stat.elapsed, 'sec' )
            end
        end

        --- TODO: send stat to parent
        log(stat)
        -- print(dump(stat))
    end
end


return handleWorker
