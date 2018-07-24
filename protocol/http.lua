--[[

    Copyright (C) 2018 Masatoshi Fukunaga

    protocol/http.lua
    tempest
    Created by Masatoshi Fukunaga on 18/07/05

--]]
--- file-scope variables
local HttpRequest = require('net.http.request')
local setmetatable = setmetatable
local getmetatable = getmetatable
local HttpRequestSendto


--- sendto
-- @param req
-- @param conn
-- @param res
-- @param err
-- @param timeout
local function sendto( req, conn )
    conn:measure()
    return HttpRequestSendto( req, conn )
end


return setmetatable({}, {
    __index = function( _, method )
        local fn = HttpRequest[method]

        if fn then
            return function( ... )
                local req, err = fn( ... )

                if err then
                    return nil, err
                end

                -- replace original send and sendto methods
                if not HttpRequestSendto then
                    local mtbl = getmetatable( req )

                    HttpRequestSendto = req.sendto
                    mtbl.__index.send = sendto
                    mtbl.__index.sendto = sendto
                end

                return req
            end
        end
    end
})
