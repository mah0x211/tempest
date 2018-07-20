--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/handler.lua
  tempest
  Created by Masatoshi Fukunaga on 18/04/26

--]]

--- handleConnection
-- @param conn
-- @param script
local function handleConnection( conn, script )
    local stat = conn.stat
    local proxy = {
        --- measure
        measure = function()
            conn:measure()
        end,

        --- send
        -- @param str
        -- @return len
        -- @return err
        -- @return timeout
        send = function( _, str )
            return conn:send( str )
        end,

        --- writev
        -- @param iov
        -- @return sock
        -- @return len
        -- @return err
        -- @return timeout
        writev = function ( _, iov )
            return conn:writev( iov )
        end,

        --- recv
        -- @return data
        -- @return err
        -- @return timeout
        recv = function()
            return conn:recv()
        end
    }

    assert( suspend() )
    while conn:connect() do
        repeat
            if script( proxy ) == true then
                stat.success = stat.success + 1
            else
                stat.failure = stat.failure + 1
            end
        until conn.sock == nil
    end
end


return handleConnection
