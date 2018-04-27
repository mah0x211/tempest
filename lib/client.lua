--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/client.lua
  tempest
  Created by Masatoshi Fukunaga on 18/04/26

--]]
--- file scope variables
local NewInetClient = require('net.stream.inet').client.new


--- handleClient
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
local function handleClient( stat )
    local opts = {
        host = stat.host,
        port = stat.port,
    }
    local rcvtimeo = stat.rcvtimeo
    local sndtimeo = stat.sndtimeo

    assert( suspend() )
    while not stat.done do
        local sock, cerr = NewInetClient( opts )

        -- connected
        if sock then
            -- set deadlines
            sock:deadlines( rcvtimeo, sndtimeo )

            while not stat.done do
                local len, err, timeout = sock:send( 'hello!' )
                local data

                if err then
                    if not stat.done then
                        log.notice( '[client] failed to send():', err )
                        stat.esend = stat.esend + 1
                    end
                    break
                elseif timeout then
                    log.notice( '[client] failed to send(): timed out' )
                    stat.esendtimeo = stat.esendtimeo + 1
                    break
                elseif len == 0 then
                    log.notice( '[client] failed to send(): closed by peer' )
                    stat.esend = stat.esend + 1
                    break
                end
                -- update total-sent bytes and number of sent
                stat.bytes_sent = stat.bytes_sent + len
                stat.nsend = stat.nsend + 1

                -- receive response
                data, err, timeout = sock:recv()
                if err then
                    if not stat.done then
                        log.notice( '[client] failed to recv()', err )
                        stat.erecv = stat.erecv + 1
                    end
                    break
                elseif timeout then
                    log.notice( '[client] failed to recv()', 'timed out' )
                    stat.erecvtimeo = stat.erecvtimeo + 1
                    break
                elseif data == nil then
                    log.notice( '[client] failed to recv(): closed by peer' )
                    stat.erecv = stat.erecv + 1
                    break
                elseif #data ~= len then
                    log.notice( '[client] failed to recv():', 'invalid response received' )
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
            log.notice( '[client] failed to connect', cerr )
            stat.econnect = stat.econnect + 1
            sleep( 500 )
        end
    end
end


return handleClient
