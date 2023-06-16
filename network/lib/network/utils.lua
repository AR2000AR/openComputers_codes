local utils = {}

function utils.checksum(data)
    local sum = 0;
    local count = #data
    local val, offset
    while count > 1 do
        val, offset = string.unpack('>H', data, offset)
        sum = sum + val
        count = count - 2;
    end

    --Add left-over byte, if any
    if (count > 0) then
        sum = sum + (string.unpack('>B', data, offset) << 8)
    end

    --Fold 32-bit sum to 16 bits
    while (sum >> 16 ~= 0) do
        sum = (sum & 0xffff) + (sum >> 16);
    end

    return ~sum & 0xffff
end

return utils
