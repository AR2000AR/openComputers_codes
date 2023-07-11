local bit32 = require('bit32')
return function(str)
    local i = 1
    local crc = 2 ^ 32 - 1
    local poly = 0xEDB88320

    for k = string.len(str), 1, -1 do
        local byte = string.byte(str, i)
        crc = bit32.bxor(crc, byte)
        for j = 0, 7 do
            if bit32.band(crc, 1) ~= 0 then
                crc = bit32.bxor(bit32.rshift(crc, 1), poly)
            else
                crc = bit32.rshift(crc, 1)
            end
        end
        i = i + 1
    end
    crc = bit32.bxor(crc, 0xFFFFFFFF)
    if crc < 0 then crc = crc + 2 ^ 32 end

    return string.pack('<I', crc)
end
