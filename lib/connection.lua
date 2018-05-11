--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/connection.lua
  tempest
  Created by Masatoshi Fukunaga on 18/04/26

--]]

--- file scope variables
local NewInetClient = require('net.stream.inet').client.new


--- handleConnection
-- @param handler
-- @param stat
--  .host
--  .port
--  .rcvtimeo
--  .sndtimeo
--  .nsend
--  .nrecv
--  .bytes_sent
--  .bytes_recv
--  .econnect
--  .esend
--  .erecv
--  .esendtimeo
--  .erecvtimeo
local function handleConnection( handler, stat )
    local opts = {
        host = stat.host,
        port = stat.port,
    }
    local sock

    local connect = function()
        sock = NewInetClient( opts )
        while not sock do
            stat.econnect = stat.econnect + 1
            sleep( 500 )
            sock = NewInetClient( opts )
        end
        -- set deadlines
        sock:deadlines( stat.rcvtimeo, stat.sndtimeo )
    end

    --- send
    -- @param str
    -- @return ok
    local send = function( str )
        local len, _, timeout = sock:sendsync( str )

        if not len or len ~= #str then
            if timeout then
                stat.esendtimeo = stat.esendtimeo + 1
            else
                stat.esend = stat.esend + 1
            end
            sock:close()
            sock = nil

            return false
        end

        -- update total-sent bytes and number of sent
        stat.bytes_sent = stat.bytes_sent + len
        stat.nsend = stat.nsend + 1

        return true
    end

    --- recv
    -- @return data
    -- @return len
    local recv = function()
        local data, _, timeout = sock:recvsync()
        local len

        if not data then
            if timeout then
                stat.erecvtimeo = stat.erecvtimeo + 1
            else
                stat.erecv = stat.erecv + 1
            end
            sock:close()
            sock = nil

            return nil
        end

        -- update total-recv bytes and number of recvd
        len = #data
        stat.bytes_recv = stat.bytes_recv + len
        stat.nrecv = stat.nrecv + 1

        return data, len
    end

    assert( suspend() )
    while true do
        connect()
        repeat
            if handler( send, recv ) == true then
                stat.success = stat.success + 1
            else
                stat.failure = stat.failure + 1
            end
        until sock == nil
    end
end


return handleConnection
