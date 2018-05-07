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
local M_REQUEST = 1


--- class IPC
local IPC = {}


--- close
function IPC:close()
    self.pipe:close()
end


--- read
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
        res, err, timeout = self.ipc:read( msec )
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
-- @return ipc
-- @return err
local function new()
    local pipe, err = NewPipe()

    if err then
        return nil, err
    end

    return setmetatable({
        pipe = pipe,
        buf = ''
    }, {
        __index = IPC
    })
end


return {
    new = new
}
