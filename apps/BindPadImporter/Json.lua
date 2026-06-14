--[[
    Json.lua - JSON decoder for BindPadImporter.

    Exposes BindPadImporterJson.decode(str) -> (value, errmsg)
    Supports objects, arrays, strings (with \" \\ \/ \b \f \n \r \t \uXXXX),
    numbers, true/false/null. Returns nil and a message on parse error.

    Self-contained so the addon needs no external libraries.
--]]

local _, addon = ...

local Json = {}
_G.BindPadImporterJson = Json

local floor = math.floor
local sub, byte, char, find, gsub, concat = string.sub, string.byte, string.char, string.find, string.gsub, table.concat

local escapes = {
    ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
    b = '\b', f = '\f', n = '\n', r = '\r', t = '\t',
}

-- forward decl
local parseValue

local function skipWhitespace(s, i)
    local _, j = find(s, "^[ \t\r\n]*", i)
    return (j or (i - 1)) + 1
end

local function codepointToUtf8(cp)
    if cp < 0x80 then
        return char(cp)
    elseif cp < 0x800 then
        return char(0xC0 + floor(cp / 0x40), 0x80 + (cp % 0x40))
    else
        return char(
            0xE0 + floor(cp / 0x1000),
            0x80 + (floor(cp / 0x40) % 0x40),
            0x80 + (cp % 0x40))
    end
end

local function parseString(s, i)
    -- assumes s:sub(i,i) == '"'
    i = i + 1
    local out = {}
    local n = #s
    while i <= n do
        local c = sub(s, i, i)
        if c == '"' then
            return concat(out), i + 1
        elseif c == '\\' then
            local e = sub(s, i + 1, i + 1)
            if e == 'u' then
                local hex = sub(s, i + 2, i + 5)
                if not find(hex, "^%x%x%x%x$") then
                    return nil, "bad \\u escape at position " .. i
                end
                out[#out + 1] = codepointToUtf8(tonumber(hex, 16))
                i = i + 6
            elseif escapes[e] then
                out[#out + 1] = escapes[e]
                i = i + 2
            else
                return nil, "bad escape \\" .. e .. " at position " .. i
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return nil, "unterminated string"
end

local function parseNumber(s, i)
    local _, j = find(s, "^%-?%d+%.?%d*[eE]?[%+%-]?%d*", i)
    if not j then
        return nil, "bad number at position " .. i
    end
    local numStr = sub(s, i, j)
    local num = tonumber(numStr)
    if not num then
        return nil, "bad number '" .. numStr .. "'"
    end
    return num, j + 1
end

local function parseArray(s, i)
    i = i + 1 -- skip [
    local arr = {}
    i = skipWhitespace(s, i)
    if sub(s, i, i) == ']' then
        return arr, i + 1
    end
    while true do
        local val, ni, err = parseValue(s, i)
        if val == nil and err then return nil, err end
        arr[#arr + 1] = val
        i = skipWhitespace(s, ni)
        local c = sub(s, i, i)
        if c == ',' then
            i = skipWhitespace(s, i + 1)
        elseif c == ']' then
            return arr, i + 1
        else
            return nil, "expected ',' or ']' at position " .. i
        end
    end
end

local function parseObject(s, i)
    i = i + 1 -- skip {
    local obj = {}
    i = skipWhitespace(s, i)
    if sub(s, i, i) == '}' then
        return obj, i + 1
    end
    while true do
        i = skipWhitespace(s, i)
        if sub(s, i, i) ~= '"' then
            return nil, "expected string key at position " .. i
        end
        local key, ni, err = parseString(s, i)
        if key == nil then return nil, err end
        i = skipWhitespace(s, ni)
        if sub(s, i, i) ~= ':' then
            return nil, "expected ':' at position " .. i
        end
        i = skipWhitespace(s, i + 1)
        local val, vi, verr = parseValue(s, i)
        if val == nil and verr then return nil, verr end
        obj[key] = val
        i = skipWhitespace(s, vi)
        local c = sub(s, i, i)
        if c == ',' then
            i = i + 1
        elseif c == '}' then
            return obj, i + 1
        else
            return nil, "expected ',' or '}' at position " .. i
        end
    end
end

parseValue = function(s, i)
    i = skipWhitespace(s, i)
    local c = sub(s, i, i)
    if c == '{' then
        return parseObject(s, i)
    elseif c == '[' then
        return parseArray(s, i)
    elseif c == '"' then
        return parseString(s, i)
    elseif c == 't' then
        if sub(s, i, i + 3) == 'true' then return true, i + 4 end
        return nil, "invalid token at position " .. i
    elseif c == 'f' then
        if sub(s, i, i + 4) == 'false' then return false, i + 5 end
        return nil, "invalid token at position " .. i
    elseif c == 'n' then
        if sub(s, i, i + 3) == 'null' then return nil, i + 4 end
        return nil, "invalid token at position " .. i
    elseif c == '-' or (c >= '0' and c <= '9') then
        return parseNumber(s, i)
    elseif c == '' then
        return nil, "unexpected end of input"
    else
        return nil, "unexpected character '" .. c .. "' at position " .. i
    end
end

-- Public: decode(str) -> value, errmsg
function Json.decode(str)
    if type(str) ~= "string" then
        return nil, "input is not a string"
    end
    local val, i, err = parseValue(str, 1)
    if val == nil and err then
        return nil, err
    end
    i = skipWhitespace(str, i)
    if i <= #str then
        return nil, "trailing characters after position " .. i
    end
    return val
end
