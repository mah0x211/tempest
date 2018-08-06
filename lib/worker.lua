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
local Connection = require('tempest.connection')
local Handler = require('tempest.handler')


--- spawnHandler
-- @param stats
-- @param opts
-- @return cids
-- @return err
local function spawnHandler( stats, opts )
    local cids = {}

    -- create clients
    for i = 1, opts.nclient do
        local conn = Connection.new( stats, opts )
        local cid, err = spawn( Handler, conn, opts.script )

        if err then
            return nil, err
        end
        cids[i] = {
            cid = cid,
            conn = conn,
        }
    end

    return cids
end


--- handleRequest
-- @param ipc
-- @param stats
-- @param opts
-- @return err
local function handleRequest( ipc, stats, opts )
    local cids, err = spawnHandler( stats, opts )
    local wstat = {}

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

    -- resume all handlers
    for i = 1, #cids do
        resume( cids[i].cid )
    end

    wstat.started = gettimeofday()
    signo, err = sigwait( opts.duration, SIGQUIT )
    wstat.stopped = gettimeofday()
    wstat.elapsed = wstat.stopped - wstat.started

    -- abort all connections
    for i = 1, #cids do
        cids[i].conn:abort()
    end

    if err then
        return err
    -- aborted by SIGQUIT
    elseif signo == SIGQUIT then
        return 'aborted by signal'
    end

    -- send stat to parent
    local timeout
    ok, err, timeout = ipc:writeStat( wstat, 1000 )
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
-- @param stats
-- @param opts
local function handleWorker( ipc, stats, opts )
    local err

    opts.script, err = eval( opts.chunk )
    if not err then
        err = handleRequest( ipc, stats, opts )
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
-- @param stats
-- @param opts
-- @return worker
-- @return err
-- @return again
local function new( stats, opts )
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
        err = handleWorker( ipc2, stats, opts )
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
