--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/ipc.lua
  Created by Masatoshi Fukunaga on 18/04/26

--]]
--- file scope variables
local NewPipe = require('act.pipe').new
local encode = require('act.aux.syscall').encode
local decode = require('act.aux.syscall').decode
--- constants
local M_OK = 0


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
