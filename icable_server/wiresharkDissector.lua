--[[
Dissector for icable by AR2000AR
See link for installation instructions : https://www.wireshark.org/docs/wsug_html_chunked/ChPluginFolders.html
]]
local protoIcable                     = Proto('icable', 'icable')

protoIcable.prefs.dissect_server_data = Pref.bool("Dissect server data payload", false, "Should the payload of server data (outbouding data) be parsed. Theses can be redundant.")

local HEADER_KIND_NAME                = {
    CLIENT_AUTH         = 0x02,
    SERVER_AUTH         = 0x03,
    CLIENT_NETCONF      = 0x04,
    SERVER_NETCONF      = 0x05,
    CLIENT_AUTH_REQUEST = 0x06,
    SERVER_AUTH_REQUEST = 0x07,
    CLIENT_ERROR        = 0xfa,
    SERVER_ERROR        = 0xfb,
    CLIENT_DISCONNECT   = 0xfc,
    SERVER_DISCONNECT   = 0xfd,
    CLIENT_DATA         = 0xfe,
    SERVER_DATA         = 0xff,
}

CLIENT_NETCONF_KIND_NAME              = {
    MANUAL_IPv4 = 0x01,
    AUTO_IPv4   = 0x02,
}

SERVER_NETCONF_KIND_NAME              = {
    IPv4 = 0x04
}

SERVER_ERROR_KIND_NAME                = {
    UNKNOWN_MSG = 0x01,
    NOT_AUTH = 0x02,
    NETCONF_ERROR = 0x04,
    MISSING_NETCONF = 0x05,
    NETCONF_MISSMATCH = 0x06,
}

CLIENT_ERROR_KIND_NAME                = {
    UNKNOWN_MSG = 0x01,
}

local HEADER_KIND                     = {
    [HEADER_KIND_NAME.CLIENT_AUTH]         = 'CLIENT_AUTH',
    [HEADER_KIND_NAME.SERVER_AUTH]         = 'SERVER_AUTH',
    [HEADER_KIND_NAME.CLIENT_NETCONF]      = 'CLIENT_NETCONF',
    [HEADER_KIND_NAME.SERVER_NETCONF]      = 'SERVER_NETCONF',
    [HEADER_KIND_NAME.CLIENT_AUTH_REQUEST] = 'CLIENT_AUTH_REQUEST',
    [HEADER_KIND_NAME.SERVER_AUTH_REQUEST] = 'SERVER_AUTH_REQUEST',
    [HEADER_KIND_NAME.CLIENT_ERROR]        = 'CLIENT_ERROR',
    [HEADER_KIND_NAME.SERVER_ERROR]        = 'SERVER_ERROR',
    [HEADER_KIND_NAME.CLIENT_DISCONNECT]   = 'CLIENT_DISCONNECT',
    [HEADER_KIND_NAME.SERVER_DISCONNECT]   = 'SERVER_DISCONNECT',
    [HEADER_KIND_NAME.CLIENT_DATA]         = 'CLIENT_DATA',
    [HEADER_KIND_NAME.SERVER_DATA]         = 'SERVER_DATA',
}

CLIENT_NETCONF_KIND                   = {
    [CLIENT_NETCONF_KIND_NAME.MANUAL_IPv4] = 'MANUAL_IPv4',
    [CLIENT_NETCONF_KIND_NAME.AUTO_IPv4]   = 'AUTO_IPv4',
}

SERVER_NETCONF_KIND                   = {
    [SERVER_NETCONF_KIND_NAME.IPv4] = 'IPv4'
}

SERVER_ERROR_KIND                     = {
    [SERVER_ERROR_KIND_NAME.UNKNOWN_MSG]       = 'UNKNOWN_MSG',
    [SERVER_ERROR_KIND_NAME.NOT_AUTH]          = 'NOT_AUTH',
    [SERVER_ERROR_KIND_NAME.NETCONF_ERROR]     = 'NETCONF_ERROR',
    [SERVER_ERROR_KIND_NAME.MISSING_NETCONF]   = 'MISSING_NETCONF',
    [SERVER_ERROR_KIND_NAME.NETCONF_MISSMATCH] = 'NETCONF_MISSMATCH',
}

CLIENT_ERROR_KIND                     = {
    [CLIENT_ERROR_KIND_NAME.UNKNOWN_MSG] = 'UNKNOWN_MSG'
}

local pf_magic                        = ProtoField.string("icable.magic", "Magic")
local pf_kind                         = ProtoField.uint8("icable.kind", "Packet kind", base.DEC, HEADER_KIND)
local pf_len                          = ProtoField.uint16("icable.len", "Packet data lengh")

local pf_uname_len                    = ProtoField.uint8('icable.client_auth.uname_len', 'Username length')
local pf_uname                        = ProtoField.string('icable.client_auth.uname', 'Username')
local pf_password_len                 = ProtoField.uint8('icable.client_auth.password_len', 'Password length')
local pf_password                     = ProtoField.string('icable.client_auth.password', 'Password')

local pf_sucess                       = ProtoField.bool('icable.server_auth.success', 'Authentication successful ?')

local pf_cl_nc_kind                   = ProtoField.uint8('icable.client_netconf.kind', 'Type of network configuration request', base.DEC, CLIENT_NETCONF_KIND)
local pf_cl_nc_ipv4                   = ProtoField.ipv4('icable.client_netconf.ipv4', 'IPv4')
local pf_cl_nc_mask                   = ProtoField.uint8('icable.client_netconf.mask', 'Mask length')

local pf_srv_nc_kind                  = ProtoField.uint8('icable.server_netconf.kind', 'Type of network configuration request', base.DEC, SERVER_NETCONF_KIND)
local pf_srv_nc_ipv4                  = ProtoField.ipv4('icable.server_netconf.ipv4', 'IPv4')
local pf_srv_nc_mask                  = ProtoField.uint8('icable.server_netconf.mask', 'Mask length')

local pf_cl_error                     = ProtoField.uint8('icable.client_error.kind', 'Error kind', base.DEC, CLIENT_ERROR_KIND)
local pf_srv_error                    = ProtoField.uint8('icable.server_error.kind', 'Error kind', base.DEC, SERVER_ERROR_KIND)
local pf_error_msg_len                = ProtoField.uint16('icable.error.message_lenght', 'Optional message lengh')
local pf_error_msg                    = ProtoField.string('icable.error.message', 'Message')

local pf_cl_auth_req_uname_len        = ProtoField.uint8('icable.client_auth_request.uname_len', 'Username length')
local pf_cl_auth_req_uname            = ProtoField.string('icable.client_auth_request.uname', 'Username')

local pf_srv_auth_req_salt            = ProtoField.bytes('icable.server_auth_request.salt', 'Password salt')
local pf_srv_auth_req_srvsalt         = ProtoField.bytes('icable.server_auth_request.srvsalt', 'Server salt')


protoIcable.fields = {
    pf_magic, pf_kind, pf_len,
    pf_uname_len, pf_uname, pf_password_len, pf_password,
    pf_sucess,
    pf_cl_nc_kind, pf_cl_nc_ipv4, pf_cl_nc_mask,
    pf_srv_nc_kind, pf_srv_nc_ipv4, pf_srv_nc_mask,
    pf_cl_error, pf_srv_error, pf_error_msg_len, pf_error_msg,
    pf_cl_auth_req_uname_len, pf_cl_auth_req_uname,
    pf_srv_auth_req_salt, pf_srv_auth_req_srvsalt
}

local function defaultDissector(tvbuf, pktinfo, root)
    local tree = root:add(tvbuf(), 'Data')
    return tvbuf():len()
end

local icablesMsgKind = {
    [HEADER_KIND_NAME.CLIENT_AUTH] = function(tvbuf, pktinfo, root)
        pktinfo.cols.info:set('CLIENT_AUTH')
        local tree = root:add(tvbuf(), 'CLIENT_AUTH')
        local offset = 0
        tree:add(pf_uname_len, tvbuf(offset, 1))
        local len = tvbuf(offset, 1):uint()
        offset = offset + 1
        tree:add(pf_uname, tvbuf(offset, len))
        pktinfo.cols.info:append(' uname = ' .. tvbuf(offset, len):string())
        offset = offset + len
        tree:add(pf_password_len, tvbuf(offset, 1))
        local len = tvbuf(offset, 1):uint()
        offset = offset + 1
        tree:add(pf_password, tvbuf(offset, len))
        offset = offset + len
        return offset
    end,
    [HEADER_KIND_NAME.SERVER_AUTH] = function(tvbuf, pktinfo, root)
        pktinfo.cols.info:set('SERVER_AUTH')
        local tree = root:add(tvbuf(), 'SERVER_AUTH')
        tree:add(pf_sucess, tvbuf(0, 1))
        if (tvbuf(0, 1):uint() == 0xff) then
            pktinfo.cols.info:append(' successful')
        else
            pktinfo.cols.info:append(' failed')
        end
        return 1
    end,
    [HEADER_KIND_NAME.CLIENT_NETCONF] = function(tvbuf, pktinfo, root)
        pktinfo.cols.info:set('CLIENT_NETCONF')
        local tree = root:add(tvbuf(), 'CLIENT_NETCONF')
        tree:add(pf_cl_nc_kind, tvbuf(0, 1))
        local kind = tvbuf(0, 1):uint()
        if (kind == CLIENT_NETCONF_KIND_NAME.MANUAL_IPv4) then
            tree:add(pf_cl_nc_ipv4, tvbuf(1, 4))
            tree:add(pf_cl_nc_mask, tvbuf(5, 1))
            pktinfo.cols.info:append(string.format(' ipv4 = %s/%d', tvbuf(1, 4):ipv4(), tvbuf(5, 1):uint()))
        end
        return tvbuf:len()
    end,
    [HEADER_KIND_NAME.SERVER_NETCONF] = function(tvbuf, pktinfo, root)
        pktinfo.cols.info:set('SERVER_NETCONF')
        local tree = root:add(tvbuf(), 'SERVER_NETCONF')
        tree:add(pf_srv_nc_kind, tvbuf(0, 1))
        local kind = tvbuf(0, 1):uint()
        if (kind == SERVER_NETCONF_KIND_NAME.IPv4) then
            tree:add(pf_srv_nc_ipv4, tvbuf(1, 4))
            tree:add(pf_srv_nc_mask, tvbuf(5, 1))
            pktinfo.cols.info:append(string.format(' ipv4 = %s/%d', tvbuf(1, 4):ipv4(), tvbuf(5, 1):uint()))
        end
        return tvbuf:len()
    end,
    [HEADER_KIND_NAME.CLIENT_ERROR] = function(tvbuf, pktinfo, root)
        pktinfo.cols.info:set('CLIENT_ERROR')
        local tree = root:add(tvbuf(), 'CLIENT_ERROR')
        tree:add(pf_cl_error, tvbuf(0, 1))
        tree:add(pf_error_msg_len, tvbuf(1, 2))
        local msgLen = tvbuf(1, 2):uint()
        if (msgLen > 0) then
            tree:add(pf_error_msg, tvbuf(3, msgLen))
        end
        return tvbuf:len()
    end,
    [HEADER_KIND_NAME.SERVER_ERROR] = function(tvbuf, pktinfo, root)
        pktinfo.cols.info:set('SERVER_ERROR')
        local tree = root:add(tvbuf(), 'SERVER_ERROR')
        tree:add(pf_srv_error, tvbuf(0, 1))
        tree:add(pf_error_msg_len, tvbuf(1, 2))
        local msgLen = tvbuf(1, 2):uint()
        if (msgLen > 0) then
            tree:add(pf_error_msg, tvbuf(3, msgLen))
        end
        return tvbuf:len()
    end,
    [HEADER_KIND_NAME.CLIENT_AUTH_REQUEST] = function(tvbuf, pktinfo, root)
        pktinfo.cols.info:set('CLIENT_AUTH_REQUEST')
        local tree = root:add(tvbuf(), 'CLIENT_AUTH_REQUEST')
        local offset = 0
        tree:add(pf_cl_auth_req_uname_len, tvbuf(offset, 1))
        local len = tvbuf(offset, 1):uint()
        offset = offset + 1
        tree:add(pf_cl_auth_req_uname, tvbuf(offset, len))
        pktinfo.cols.info:append(' uname = ' .. tvbuf(offset, len):string())
        offset = offset + len
        return tvbuf:len()
    end,
    [HEADER_KIND_NAME.SERVER_AUTH_REQUEST] = function(tvbuf, pktinfo, root)
        pktinfo.cols.info:set('SERVER_AUTH_REQUEST')
        local tree = root:add(tvbuf(), 'SERVER_AUTH_REQUEST')
        tree:add(pf_srv_auth_req_salt, tvbuf(0, 16))
        tree:add(pf_srv_auth_req_srvsalt, tvbuf(16))
        return tvbuf:len()
    end,
    [HEADER_KIND_NAME.CLIENT_DATA] = function(tvbuf, pktinfo, root)
        pktinfo.cols.info:set('CLIENT_DATA')
        local tree = root:add(tvbuf(), 'CLIENT_DATA')
        return Dissector.get('ip'):call(tvbuf:tvb(), pktinfo, tree)
    end,
    [HEADER_KIND_NAME.SERVER_DATA] = function(tvbuf, pktinfo, root)
        pktinfo.cols.info:set('SERVER_DATA')
        local tree = root:add(tvbuf(), 'SERVER_DATA')
        if (protoIcable.prefs.dissect_server_data) then
            return Dissector.get('ip'):call(tvbuf:tvb(), pktinfo, tree)
        else
            return tvbuf():len()
        end
    end,
}



function protoIcable.dissector(tvbuf, pktinfo, root)
    if (tvbuf(0, 4):string() ~= "ICAB") then return 0 end
    pktinfo.cols.protocol:set('icable')
    local tree = root:add(protoIcable, tvbuf())
    tree:add(pf_magic, tvbuf(0, 4))
    tree:add(pf_kind, tvbuf(4, 1))
    tree:add(pf_len, tvbuf(5, 2))
    if (icablesMsgKind[tvbuf(4, 1):uint()]) then
        icablesMsgKind[tvbuf(4, 1):uint()](tvbuf(8), pktinfo, tree)
    else
        defaultDissector(tvbuf(8), pktinfo, tree)
    end
    return tvbuf:len()
end

DissectorTable.get("tcp.port"):add(4222, protoIcable)
