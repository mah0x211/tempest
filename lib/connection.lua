--[[

  Copyright (C) 2018 Masatoshi Fukunaga

  lib/connection.lua
  tempest
  Created by Masatoshi Fukunaga on 18/07/20

--]]

--- file scope variables
local NewInetClient = require('net.stream.inet').client.new
local Timer = require('tempest.timer')


--- class
local Connection = {}


--- connect
-- @return ok
function Connection:connect()
    if not self.aborted then
        local stat = self.stat
        local opts = self.opts

        while not self.aborted do
            local sock = NewInetClient( opts )

            if not sock then
                stat.econnect = stat.econnect + 1
                sleep( 500 )
            else
                -- set deadlines
                sock:deadlines( stat.rcvtimeo, stat.sndtimeo )
                self.sock = sock
                return true
            end
        end
    end

    return false
end


--- send
-- @param str
-- @return len
-- @return err
-- @return timeout
function Connection:send( str )
    if not self.aborted then
        local len, err, timeout = self.sock:send( str )

        if not len or len ~= #str then
            if timeout then
                self.stat.esendtimeo = self.stat.esendtimeo + 1
            else
                self.stat.esend = self.stat.esend + 1
            end
            self.sock:close()
            self.sock = nil
            self.timer:reset()
        else
            -- update total-sent bytes and number of sent
            self.stat.bytes_sent = self.stat.bytes_sent + len
            self.stat.nsend = self.stat.nsend + 1
        end

        return len, err, timeout
    end

    return nil, 'aborted'
end


--- writev
-- @param iov
-- @return sock
-- @return len
-- @return err
-- @return timeout
function Connection:writev( iov )
    if not self.aborted then
        local len, err, timeout = self.sock:writev( iov )

        if not len or len ~= iov:bytes() then
            if timeout then
                self.stat.esendtimeo = self.stat.esendtimeo + 1
            else
                self.stat.esend = self.stat.esend + 1
            end
            self.timer:reset()
            self.sock:close()
            self.sock = nil
        else
            -- update total-sent bytes and number of sent
            self.stat.bytes_sent = self.stat.bytes_sent + len
            self.stat.nsend = self.stat.nsend + 1
        end

        return len, err, timeout
    end

    return nil, 'aborted'
end


--- recv
-- @return data
-- @return err
-- @return timeout
function Connection:recv()
    if not self.aborted then
        local data, err, timeout = self.sock:recv()

        self.timer:measure()
        if not data then
            if timeout then
                self.stat.erecvtimeo = self.stat.erecvtimeo + 1
            else
                self.stat.erecv = self.stat.erecv + 1
            end
            self.timer:reset()
            self.sock:close()
            self.sock = nil
        else
            -- update total-recv bytes and number of recvd
            self.stat.bytes_recv = self.stat.bytes_recv + #data
            self.stat.nrecv = self.stat.nrecv + 1
        end

        return data, err, timeout
    end

    return nil, 'aborted'
end


--- measure
function Connection:measure()
    self.timer:start()
end


--- abort
function Connection:abort()
    self.aborted = true
end


--- abort
function Connection:close()
    if self.sock then
        self.sock:close()
        self.sock = nil
        self.timer:reset()
    end
end


local function new( stat )
    return setmetatable({
        aborted = false,
        stat = stat,
        opts = {
            host = stat.host,
            port = stat.port
        },
        timer = Timer.new( stat.latency ),
    }, {
        __index = Connection
    })
end


return {
    new = new
}
