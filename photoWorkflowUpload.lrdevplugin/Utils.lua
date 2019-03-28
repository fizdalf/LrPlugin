--
-- Created by IntelliJ IDEA.
-- User: Fizdalf
-- Date: 15/11/2016
-- Time: 12:58
-- To change this template use File | Settings | File Templates.
--
local LrLogger = import 'LrLogger'
local myLogger = LrLogger('testLogger')
myLogger:enable("logfile")


SERVER = "http://3.83.35.38:8080/"
--SERVER = "http://api.photoworkflow.local/API1.3.11"

function print_to_log_table(t)
    local print_r_cache = {}
    local function sub_print_r(t, indent)
        if (print_r_cache[tostring(t)]) then
            myLogger:trace(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    if (type(val) == "table") then
                        myLogger:trace(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                        myLogger:trace(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    elseif (type(val) == "string") then
                        myLogger:trace(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        myLogger:trace(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                myLogger:trace(indent .. tostring(t))
            end
        end
    end

    if (type(t) == "table") then
        myLogger:trace(tostring(t) .. " {")
        sub_print_r(t, "  ")
        myLogger:trace("}")
    else
        sub_print_r(t, "  ")
    end
    myLogger:trace()
end

function nocase(s)
    s = string.gsub(s, "%a", function(c)
        return string.format("[%s%s]", string.lower(c),
            string.upper(c))
    end)
    return s
end