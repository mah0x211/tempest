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
local function handleConnection( handler, stat )
    local opts = {
        host = stat.host,
        port = stat.port,
    }
    local sock

    --- connect
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
    -- @return len
    -- @return err
    -- @return timeout
    local function send( _, str )
        local len, err, timeout = sock:send( str )

        if not len or len ~= #str then
            if timeout then
                stat.esendtimeo = stat.esendtimeo + 1
            else
                stat.esend = stat.esend + 1
            end
            sock:close()
            sock = nil
        else
            -- update total-sent bytes and number of sent
            stat.bytes_sent = stat.bytes_sent + len
            stat.nsend = stat.nsend + 1
        end

        return len, err, timeout
    end

    --- writev
    -- @param iov
    -- @return sock
    -- @return len
    -- @return err
    -- @return timeout
    local writev = function ( _, iov )
        local len, err, timeout = sock:writev( iov )

        if not len or len ~= iov:bytes() then
            if timeout then
                stat.esendtimeo = stat.esendtimeo + 1
            else
                stat.esend = stat.esend + 1
            end
            sock:close()
            sock = nil
        else
            -- update total-sent bytes and number of sent
            stat.bytes_sent = stat.bytes_sent + len
            stat.nsend = stat.nsend + 1
        end

        return len, err, timeout
    end

    --- recv
    -- @return data
    -- @return err
    -- @return timeout
    local function recv()
        local data, err, timeout = sock:recv()

        if not data then
            if timeout then
                stat.erecvtimeo = stat.erecvtimeo + 1
            else
                stat.erecv = stat.erecv + 1
            end
            sock:close()
            sock = nil
        else
            -- update total-recv bytes and number of recvd
            stat.bytes_recv = stat.bytes_recv + #data
            stat.nrecv = stat.nrecv + 1
        end

        return data, err, timeout
    end

    local conn = {
        send = send,
        writev = writev,
        recv = recv
    }

    assert( suspend() )
    while true do
        connect()
        repeat
            if handler( conn ) == true then
                stat.success = stat.success + 1
            else
                stat.failure = stat.failure + 1
            end
        until sock == nil
    end
end


return handleConnection
