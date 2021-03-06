--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/ipc.lua
  Created by Masatoshi Fukunaga on 18/04/26

--]]
--- file scope variables
local isa = require('isa')
local NewPipe = require('act.pipe').new
local encode = require('act.aux.syscall').encode
local decode = require('act.aux.syscall').decode
--- constants
local M_ERROR = -1
local M_OK = 0
local M_PING = 1
local M_PONG = 2
local M_REQUEST = 3
local M_STAT = 4


--- class IPC
local IPC = {}


--- close
function IPC:close()
    self.pipe:close()
end


--- read
-- @param msec
-- @return val
-- @return err
-- @return timeout
function IPC:read( msec )
    local buf = self.buf

    while true do
        local val, use, err, again = decode( buf )

        if again then
            local data, rerr, timeout = self.pipe:read( msec )

            if not data then
                return nil, rerr, timeout
            end

            buf = buf .. data
        elseif err then
            -- reset buffer
            self.buf = ''
            return nil, err
        else
            self.buf = buf:sub( use + 1 )
            return val
        end
    end
end


--- write
-- @param val
-- @return ok
-- @return err
-- @return timeout
function IPC:write( val, msec )
    local data, err = encode( val )

    if data then
        local len, werr, timeout = self.pipe:write( data, msec )

        if len then
            if len == #data then
                return true
            end

            werr = 'UNEXPECTED-ERROR'
        end

        return false, werr, timeout
    end

    return false, err
end


--- readStat
-- @param msec
-- @return stat
-- @return err
function IPC:readStat( msec )
    -- wait a request
    local stat, err, timeout = self:read( msec )

    if stat ~= nil then
        if not isa.table( stat ) then
            err = 'UNEXPECTED-STAT-MESSAGE'
        elseif stat.IPC_MSG == M_STAT then
            stat.IPC_MSG = nil
            return stat
        elseif stat.IPC_MSG == M_ERROR then
            err = stat.message
        else
            err = 'UNEXPECTED-STAT-MESSAGE'
        end
    end

    return nil, err, timeout
end


--- writeStat
-- @param msg
-- @param msec
-- @return ok
-- @return err
-- @return timeout
function IPC:writeStat( msg, msec )
    if not isa.table( msg ) then
        return nil, 'msg must be table'
    end
    msg.IPC_MSG = M_STAT
    return self:write( msg, msec )
end


--- accept
-- @return req
-- @return err
function IPC:accept()
    while true do
        -- wait a request
        local req, err = self:read()

        if err then
            return nil, err
        -- closed by peer
        elseif req == nil then
            return nil
        elseif not isa.table( req ) then
            return nil, 'UNEXPECTED-REQUEST-MESSAGE'
        elseif req.IPC_MSG == M_REQUEST then
            req.IPC_MSG = nil
            return req
        elseif req.IPC_MSG == M_PING then
            local ok, perr, timeout = self:pong( 1000 )

            if timeout then
                return nil, 'timeout'
            elseif perr then
                return nil, perr
            -- closed by peer
            elseif not ok then
                return nil
            end
        end
    end
end


--- request
-- @param msg
-- @param msec
-- @return ok
-- @return err
-- @return timeout
function IPC:request( msg, msec )
    if not isa.table( msg ) then
        return nil, 'msg must be table'
    end
    msg.IPC_MSG = M_REQUEST

    local ok, err, timeout = self:write( msg, msec )
    if ok then
        local res

        -- wait a response from worker
        res, err, timeout = self:read( msec )
        if res ~= nil then
            if not isa.table( res ) then
                err = 'UNEXPECTED-RESPONSE-MESSAGE'
            elseif res.IPC_MSG == M_OK then
                return true
            elseif res.IPC_MSG == M_ERROR then
                err = res.message
            else
                err = 'UNEXPECTED-RESPONSE-MESSAGE'
            end
        end
    end

    return false, err, timeout
end


--- ping
-- @param msec
-- @return ok
-- @return err
-- @return timeout
function IPC:ping( msec )
    local ok, err, timeout = self:write({
        IPC_MSG = M_PING,
    }, msec )

    if ok then
        local res

        res, err, timeout = self:read( msec )
        if res ~= nil then
            if not isa.table( res ) then
                err = 'UNEXPECTED-RESPONSE-MESSAGE'
            elseif res.IPC_MSG == M_PONG then
                return true
            elseif res.IPC_MSG == M_ERROR then
                err = res.message
            else
                err = 'UNEXPECTED-RESPONSE-MESSAGE'
            end
        end
    end

    return false, err, timeout
end


--- pong
-- @param msec
-- @return ok
-- @return err
-- @return timeout
function IPC:pong( msec )
    return self:write({
        IPC_MSG = M_PONG,
    }, msec )
end


--- error
-- @param msg
-- @param msec
-- @return ok
-- @return err
-- @return timeout
function IPC:error( msg, msec )
    if not isa.string( msg ) then
        return nil, 'msg must be string'
    end

    return self:write({
        IPC_MSG = M_ERROR,
        message = msg
    }, msec )
end


--- ok
-- @param msec
-- @return ok
-- @return err
-- @return timeout
function IPC:ok( msec )
    return self:write({
        IPC_MSG = M_OK,
    }, msec )
end


--- new
-- @return ipc1
-- @return ipc2
-- @return err
local function new()
    local pipe1, err = NewPipe()
    local pipe2

    if err then
        return nil, nil, err
    end

    pipe2, err = NewPipe()
    if err then
        return nil, nil, err
    end

    -- exchange
    pipe1.reader, pipe2.reader = pipe2.reader, pipe1.reader

    return setmetatable({
        pipe = pipe1,
        buf = ''
    }, {
        __index = IPC
    }), setmetatable({
        pipe = pipe2,
        buf = ''
    }, {
        __index = IPC
    })
end


return {
    new = new
}
