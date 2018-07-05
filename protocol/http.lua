--[[

    Copyright (C) 2018 Masatoshi Fukunaga

    protocol/http.lua
    tempest
    Created by Masatoshi Fukunaga on 18/07/05

--]]
--- file-scope variables
local HttpRequest = require('net.http.request')
local setmetatable = setmetatable

return setmetatable({}, {
    __index = function( _, method )
        local fn = HttpRequest[method]

        if fn then
            return function( ... )
                local req, err = fn( ... )

                if err then
                    return nil, err
                end

                -- replace original send method
                req.send = req.sendto

                return req
            end
        end
    end
})
