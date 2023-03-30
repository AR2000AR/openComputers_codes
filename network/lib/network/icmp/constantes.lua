---@class icmpConstantes
local icmpConst = {}
---@enum icmpType
icmpConst.TYPE = {
    ECHO_REPLY                      = 0,
    DESTINATION_UNREACHABLE         = 3,
    REDIRECT_MESSAGE                = 5,
    ECHO_REQUEST                    = 8,
    ROUTER_ADVERTISEMENT            = 9,
    ROUTER_SOLICITATION             = 10,
    TIME_EXCEEDED                   = 11,
    PARAMETER_PROBELM_BAD_IP_HEADER = 12,
    TIMESTAMP                       = 13,
    TIMESTAMP_REPLY                 = 14,
    EXTENDED_ECHO_REQUEST           = 42,
    EXTENDED_ECHO_REPLY             = 43
}
icmpConst.CODE = {
    ECHO_REPLY = {
        ECHO_REPLY = 0
    },
    DESTINATION_UNREACHABLE = {
        DESTINATION_NETWORK_UNREACHABLE = 0,
        DESTINATION_HOST_UNREACHABLE = 1,
        DESTINATION_PROTOCOL_UNREACHABLE = 2,
        DESTINATION_PORT_UNREACHABLE = 3,
        FRAGMENTATION_REQUIRED_AND_DF_FLAG_SET = 4,
        SOURCE_ROUTE_FAILED = 5,
        DESTINATION_NETWORK_UNKNOWN = 6,
        DESTINATION_HOST_UNKNOWN = 7,
        SOURCE_HOST_ISOLATED = 8,
        NETWORK_ADMINISTRATIVELY_PROHIBITED = 9,
        HOST_ADMINISTRATIVELY_PROHIBITED = 10,
        NETWORK_UNREACHABLE_FOR_TOS = 11,
        HOST_UNREACHABLE_FOR_TOS = 12,
        COMMUNICATION_ADMINISTRATIVELY_PROHIBITED = 13,
        HOST_PRECEDENCE_VIOLATION = 14,
        PRECEDENCE_CUTOFF_IN_EFFECT = 15,
    },
    REDIRECT_MESSAGE = {
        REDIRECT_DATAGRAM_FOR_THE_NETWORK = 0,
        REDIRECT_DATAGRAM_FOR_THE_HOST = 1,
        REDIRECT_DATAGRAM_FOR_THE_TOS_NETWORK = 2,
        REDIRECT_DATAGRAM_FOR_THE_TOS_HOST = 3,
    },
    ECHO_REQUEST = {
        Echo_request = 0,
    },
    ROUTER_ADVERTISEMENT = {
        ROUTER_ADVERTISEMENt = 0,
    },
    ROUTER_SOLICITATION = {
        Router_discovery_selection_solicitation = 0,
    },
    TIME_EXCEEDED = {
        TTL_expired_in_transit = 0,
        Fragment_reassembly_time_exceeded = 1,
    },
    PARAMETER_PROBELM_BAD_IP_HEADER = {
        Pointer_indicates_the_error = 0,
        Missing_a_required_option = 1,
        Bad_length = 2,
    },
    TIMESTAMP = {
        Timestamp = 0,
    },
    TIMESTAMP_REPLY = {
        Timestamp_reply = 0,
    },
    EXTENDED_ECHO_REQUEST = {
        Request_Extended_Echo = 0,
    },
    EXTENDED_ECHO_REPLY = {
        No_Error = 0,
        Malformed_Query = 1,
        No_Such_Interface = 2,
        No_Such_Table_Entry = 3,
        Multiple_Interfaces_Satisfy_Query = 4,
    }
}

return icmpConst
