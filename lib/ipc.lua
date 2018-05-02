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
function IPC:read( msec )
    local buf = self.buf

    while true do
        local val, use, err, again = decode( buf )

        if again then
            local data, rerr, timeout = self.pipe:read( msec )

            if timeout then
                log.err( 'failed to IPC:read(): timeout' )
                return
            elseif rerr then
                log.err( 'failed to IPC:read():', rerr )
                return
            end
            buf = buf .. data
        elseif err then
            log.err( 'failed to IPC:read():', err )
            return
        else
            self.buf = buf:sub( use + 1 )
            return val
        end
    end
end


--- write
-- @param val
-- @return ok
function IPC:write( val, msec )
    local data, err = encode( val )

    if err then
        log.err( 'failed to IPC:write():', err )
    else
        local bytes = #data
        local len, werr, timeout = self.pipe:write( data, msec )

        if timeout then
            log.err( 'failed to IPC:write(): timeout' )
        elseif werr then
            log.err( 'failed to IPC:write():', err )
        elseif len ~= bytes then
            log.err( 'failed to IPC:write(): UNEXPECTED-IMPLEMENTATION' )
        else
            return true
        end
    end

    return false
end


--- new
-- @return ipc
local function new()
    local pipe, err = NewPipe()

    if pipe then
        return setmetatable({
            pipe = pipe,
            buf = ''
        }, {
            __index = IPC
        })
    end

    log.err( 'failed to IPC.new()', err )
end


return {
    new = new
}
