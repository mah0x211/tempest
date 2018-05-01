--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/ipc.lua
  Created by Masatoshi Fukunaga on 18/04/26

--]]
--- file scope variables
local NewPipe = require('act.pipe').new
local encode = require('act.aux.syscall').encode
local decode = require('act.aux.syscall').decode


--- class IPC
local IPC = {}


--- read
-- @return val
-- @return err
-- @return timeout
function IPC:read( msec )
    local buf = self.buf

    while true do
        local val, use, err, again = decode( buf )

        if val then
            self.buf = buf:sub( use + 1 )
            return val
        elseif not again then
            return nil, err
        else
            local data, rerr, timeout = self.pipe:read( msec )

            if data then
                buf = buf .. data
            else
                return nil, rerr, timeout
            end
        end
    end
end


--- write
-- @param val
-- @return ok
-- @return err
-- @return timeout
function IPC:write( val )
    local data, err = encode( val )

    if data then
        local len, werr = self.pipe:write( data )

        if werr then
            return false, werr
        end

        return len ~= nil
    end

    return false, err
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
