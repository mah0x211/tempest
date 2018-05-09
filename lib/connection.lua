--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/connection.lua
  tempest
  Created by Masatoshi Fukunaga on 18/04/26

--]]

--- file scope variables
local NewInetClient = require('net.stream.inet').client.new


--- handleConnection
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
local function handleConnection( stat )
    local opts = {
        host = stat.host,
        port = stat.port,
    }
    local rcvtimeo = stat.rcvtimeo
    local sndtimeo = stat.sndtimeo

    assert( suspend() )
    while true do
        local sock, cerr = NewInetClient( opts )

        -- connected
        if sock then
            -- set deadlines
            sock:deadlines( rcvtimeo, sndtimeo )

            while true do
                local len, err, timeout = sock:send( 'hello!' )
                local data

                if err then
                    stat.esend = stat.esend + 1
                    break
                elseif timeout then
                    stat.esendtimeo = stat.esendtimeo + 1
                    break
                elseif not len or len == 0 then
                    stat.esend = stat.esend + 1
                    break
                end
                -- update total-sent bytes and number of sent
                stat.bytes_sent = stat.bytes_sent + len
                stat.nsend = stat.nsend + 1

                -- receive response
                data, err, timeout = sock:recv()
                if err then
                    stat.erecv = stat.erecv + 1
                    break
                elseif timeout then
                    stat.erecvtimeo = stat.erecvtimeo + 1
                    break
                elseif not data or #data ~= len then
                    stat.erecv = stat.erecv + 1
                    break
                end
                -- update total-recv bytes and number of recvd
                stat.bytes_recv = stat.bytes_recv + len
                stat.nrecv = stat.nrecv + 1
            end

            sock:close()

        -- reconnect
        else
            stat.econnect = stat.econnect + 1
            sleep( 500 )
        end
    end
end


return handleConnection
