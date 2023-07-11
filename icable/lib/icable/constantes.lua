local consts = {}
---@enum IcablePacketKind
consts.KIND = {
    CLIENT_AUTH = 0x02,
    SERVER_AUTH = 0x03,
    CLIENT_NETCONF = 0x04,
    SERVER_NETCONF = 0x05,
    CLIENT_AUTH_REQUEST = 0x06,
    SERVER_AUTH_REQUEST = 0x07,
    CLIENT_ERROR = 0xfa,
    SERVER_ERROR = 0xfb,
    CLIENT_DISCONNECT = 0xfc,
    SERVER_DISCONNECT = 0xfd,
    CLIENT_DATA = 0xfe,
    SERVER_DATA = 0xff
}

---@enum CLIENT_NETCONF_KIND
consts.CLIENT_NETCONF_KIND = {
    MANUAL_IPv4 = 0x01,
    AUTO_IPv4 = 0x02,
}

---@enum SERVER_NETCONF_KIND
consts.SERVER_NETCONF_KIND = {
    IPv4 = 0x04
}

return consts
