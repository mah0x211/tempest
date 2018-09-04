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
        local stats = self.stats
        local opts = self.opts
        local addr = self.addr

        while not self.aborted do
            local sock = NewInetClient( addr )

            if sock then
                if sock:handshake() then
                    -- set deadlines
                    sock:deadlines( opts.rcvtimeo, opts.sndtimeo )
                    self.sock = sock
                    return true
                end

                sock:close()
            end

            stats:incrEConnect()
            sleep( 500 )
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
                self.stats:incrESendtimeo()
            else
                self.stats:incrESend()
            end
            self.sock:close()
            self.sock = nil
            self.timer:reset()
        else
            -- update total-sent bytes and number of sent
            self.stats:addBytesSent( len )
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
                self.stats:incrESendTimeo()
            else
                self.stats:incrESend()
            end
            self.timer:reset()
            self.sock:close()
            self.sock = nil
        else
            -- update total-sent bytes
            self.stats:addBytesSent( len )
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
                self.stats:incrERecvTimeo()
            else
                self.stats:incrERecv()
            end
            self.timer:reset()
            self.sock:close()
            self.sock = nil
        else
            -- update total-recv bytes
            self.stats:addBytesRecv( #data )
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


local function new( stats, opts )
    return setmetatable({
        aborted = false,
        stats = stats,
        opts = opts,
        addr = {
            host = opts.host,
            port = opts.port,
            tlscfg = opts.tlscfg,
            servername = opts.servername,
        },
        timer = Timer.new( stats ),
    }, {
        __index = Connection
    })
end


return {
    new = new
}
