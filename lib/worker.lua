--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/worker.lua
  tempest
  Created by Masatoshi Fukunaga on 18/04/25

--]]
--- file scope variables
local kill = require('signal').kill
local gettimeofday = require('process').gettimeofday
local eval = require('tempest.script').eval
local IPC = require('tempest.ipc')
local handleConnection = require('tempest.connection')


--- createClient
-- @param nclient
-- @param handler
-- @param stat
-- @return cids
-- @return err
local function createClient( nclient, handler, stat )
    local cids = {}

    -- create clients
    for i = 1, nclient do
        local cid, err = spawn( handleConnection, handler, stat )

        if err then
            return nil, err
        end
        cids[i] = cid
    end

    return cids
end


--- handleRequest
-- @param ipc
-- @param req
-- @param handler
-- @return err
local function handleRequest( ipc, req, handler )
    local stat = {
        host = req.host,
        port = req.port,
        rcvtimeo = req.rcvtimeo,
        sndtimeo = req.sndtimeo,
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
    local cids, err = createClient( req.nclient, handler, stat )

    if err then
        return err
    end

    local ok
    ok, err = ipc:pong()
    if not ok then
        return err
    end

    -- wait signal
    local signo
    signo, err = sigwait( nil, SIGUSR1, SIGQUIT )
    if err then
        return err
    -- aborted by SIGQUIT
    elseif signo == SIGQUIT then
        return 'aborted by signal'
    end

    -- make stress
    for i = 1, #cids do
        resume( cids[i] )
    end
    stat.started = gettimeofday()
    signo, err = sigwait( req.duration, SIGQUIT )
    stat.stopped = gettimeofday()
    stat.elapsed = stat.stopped - stat.started

    if err then
        return err
    -- aborted by SIGQUIT
    elseif signo == SIGQUIT then
        return 'aborted by signal'
    end

    -- send stat to parent
    local timeout
    ok, err, timeout = ipc:writeStat( stat, 1000 )
    if err then
        err = 'failed to send a stat to parent: ' .. err
    elseif timeout then
        err = 'failed to send a stat to parent: timeout'
    elseif not ok then
        err = 'failed to send a stat to parent: closed by peer'
    end

    return err
end


--- handleWorker
-- @param ipc
-- @param req
local function handleWorker( ipc, req )
    local handler, err

    if req.chunk then
        handler, err = eval( req.chunk )
    else
        handler = req.defaultHandler
    end

    if not err then
        err = handleRequest( ipc, req, handler )
    end

    if err then
        ipc:error( err )
    end
end



--- class
local Worker = {}


--- close
function Worker:close()
    local pid = self.pid

    self.ipc:close()
    kill( SIGQUIT, pid )
    for _ = 1, 10 do
        local stat = waitpid( pid )

        -- child-process has already terminated
        if stat and ( stat.exit or stat.termsig or stat.nochild ) then
            return
        end
        sleep(100)
    end
    kill( SIGKILL, pid )
end


--- stat
-- @param msec
-- @return stat
-- @return err
-- @return timeout
function Worker:stat( msec )
    return self.ipc:readStat( msec )
end


--- request
-- @param req
-- @param msec
-- @return ok
-- @return err
-- @return timeout
function Worker:request( req, msec )
    return self.ipc:request( req, msec )
end


--- ping
-- @param msec
-- @return ok
-- @return err
-- @return timeout
function Worker:ping( msec )
    return self.ipc:ping( msec )
end


--- new
-- @param req
-- @return worker
-- @return err
-- @return again
local function new( req )
    local ipc1, ipc2, err = IPC.new()
    local ok, pid, again, timeout

    if err then
        return nil, err
    end

    -- create child-process
    pid, err, again = fork()
    if not pid then
        ipc1:close()
        ipc2:close()
        return nil, err, again
    -- run in child process
    elseif pid == 0 then
        ipc1:close()
        err = handleWorker( ipc2, req )
        ipc2:close()
        if err then
            log.err( 'failed to handleWorker():', err )
        end

        exit()
    end
    ipc2:close()

    -- wait a pong from worker
    ok, err, timeout = ipc1:ping( 1000 )
    if not ok then
        ipc1:close()
        kill( SIGKILL, pid )
        if err then
            return nil, err
        elseif timeout then
            return nil, 'timeout'
        end

        return nil, 'UNEXPECTED-ERROR'
    end

    return setmetatable({
        ipc = ipc1,
        pid = pid,
    }, {
        __index = Worker
    })
end


return {
    new = new
}
