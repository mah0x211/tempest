--[[

    Copyright (C) 2018 Masatoshi Fukunaga

    handler/echo.lua
    tempest
    Created by Masatoshi Fukunaga on 18/05/11

--]]

return [[

--- handler
-- @param conn
-- @return ok
local function handler( conn )
    local len = conn:send( 'hello!' )

    if not len then
        return false
    end

    local str = conn:recv()

    if not str or #str ~= 6 then
        return false
    end

    return true
end

return handler

]]