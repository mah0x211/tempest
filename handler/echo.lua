--[[

    Copyright (C) 2018 Masatoshi Fukunaga

    handler/echo.lua
    tempest
    Created by Masatoshi Fukunaga on 18/05/11

--]]

--- handler
-- @param send
-- @param recv
-- @return ok
local function handler( send, recv )
    if send( 'hello!' ) then
        local _, len = recv()

        if len then
            return len == 6
        end
    end

    return false
end

return handler
