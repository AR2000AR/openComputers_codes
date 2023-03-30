---@class ipv4ConstsLib
local ipv4Consts     = {}

---@enum ipv4Protocol
ipv4Consts.PROTOCOLS = {
    ICMP = 1,  --  Internet Control Message Protocol
    TCP  = 6,  --  Transmission Control Protocol
    UDP  = 17, -- User Datagram Protocol
    OSPF = 89, -- Open Shortest Path First
}

return ipv4Consts
