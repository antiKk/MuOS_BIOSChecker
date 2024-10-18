-- adler32.lua
local adler32 = {}

-- Constants for Adler-32
local MOD_ADLER = 65521

function adler32.checksum(data)
    local a, b = 1, 0

    -- Iterate over the bytes in the data
    for i = 1, #data do
        local byte = string.byte(data, i)
        a = (a + byte) % MOD_ADLER
        b = (b + a) % MOD_ADLER
    end

    -- Combine the two parts into a single checksum value
    return string.format("%08X", (b * 65536) + a)
end

return adler32
