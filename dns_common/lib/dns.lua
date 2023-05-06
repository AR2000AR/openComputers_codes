local bit32         = require("bit32")
local serialization = require("serialization")


---@class libdnstypes
local dns = {}

--=============================================================================
--#region DNSHeaderFlags

---@class DNSHeaderFlags
---@field private _header number
---@overload fun(header:number):DNSHeaderFlags
---@overload fun(qr:flagQr,opcode:flagOpcode,aa:boolean,tc:boolean,rd:boolean,ra:boolean,rcode:flagRcode):DNSHeaderFlags
---@operator call:DNSHeaderFlags
local DNSHeaderFlags = {}

---@enum flagQr
DNSHeaderFlags.QR = {
    QUERRY = 0,
    REPLY  = 1
}

---@enum flagOpcode
DNSHeaderFlags.OPCODE = {
    QUERY  = 0,
    IQUERY = 1,
    STATUS = 2
}

---@enum flagRcode
DNSHeaderFlags.RCODE = {
    NOERROR  = 0,
    FORMERR  = 1,
    SERVFAIL = 2,
    NXDOMAIN = 3,
    NIMPL    = 4,
    REFUSED  = 5
}

---@return DNSHeaderFlags
setmetatable(DNSHeaderFlags, {
    ---@param self DNSHeaderFlags
    ---@param qr flagQr
    ---@param opcode flagOpcode
    ---@param aa boolean
    ---@param tc boolean
    ---@param rd boolean
    ---@param ra boolean
    ---@param rcode flagRcode
    ---@overload fun(self:DNSHeaderFlags,header:number):DNSHeaderFlags
    ---@return table
    __call = function(self, qr, opcode, aa, tc, rd, ra, rcode)
        local o = {
            _header = qr
        }
        checkArg(1, qr, "number")
        if (opcode ~= nil) then
            checkArg(2, opcode, "number")
            checkArg(3, aa, "boolean")
            checkArg(4, tc, "boolean")
            checkArg(5, rd, "boolean")
            checkArg(6, ra, "boolean")
            checkArg(7, rcode, "number")
        end
        setmetatable(o, {__index = self})
        if (opcode ~= nil) then
            o:setQR(qr)
            o:setOPCODE(opcode)
            o:setAA(aa)
            o:setTC(tc)
            o:setRD(rd)
            o:setRA(ra)
            o:setRCODE(rcode)
        end
        return o
    end
})

--#region getter/setter

---Indicates if the message is a query (0) or a reply (1)
---@return flagQr
function DNSHeaderFlags:getQR()
    return bit32.extract(self._header, 15)
end

---Indicates if the message is a query (0) or a reply (1)
---@param value flagQr
function DNSHeaderFlags:setQR(value)
    self._header = bit32.replace(self._header, value, 15)
end

---The type can be QUERY (standard query, 0), IQUERY (inverse query, 1), or STATUS (server status request, 2)
---@return flagOpcode
function DNSHeaderFlags:getOPCODE()
    return bit32.extract(self._header, 11, 4)
end

---The type can be QUERY (standard query, 0), IQUERY (inverse query, 1), or STATUS (server status request, 2)
---@param value flagOpcode
function DNSHeaderFlags:setOPCODE(value)
    self._header = bit32.replace(self._header, value, 11, 4)
end

---Authoritative Answer, in a response, indicates if the DNS server is authoritative for the queried hostname
---@return boolean
function DNSHeaderFlags:getAA()
    return bit32.extract(self._header, 10) == 1
end

---Authoritative Answer, in a response, indicates if the DNS server is authoritative for the queried hostname
---@param value boolean
function DNSHeaderFlags:setAA(value)
    checkArg(1, value, "boolean")
    local nb = 0
    if (value == true) then nb = 1 end
    self._header = bit32.replace(self._header, nb, 10)
end

---TrunCation, indicates that this message was truncated due to excessive length
---@return boolean
function DNSHeaderFlags:getTC()
    return bit32.extract(self._header, 9) == 1
end

---TrunCation, indicates that this message was truncated due to excessive length
---@param value boolean
function DNSHeaderFlags:setTC(value)
    checkArg(1, value, "boolean")
    local nb = 0
    if (value == true) then nb = 1 end
    self._header = bit32.replace(self._header, nb, 9)
end

---Recursion Desired, indicates if the client means a recursive query
---@return boolean
function DNSHeaderFlags:getRD()
    return bit32.extract(self._header, 8) == 1
end

---Recursion Desired, indicates if the client means a recursive query
---@param value boolean
function DNSHeaderFlags:setRD(value)
    checkArg(1, value, "boolean")
    local nb = 0
    if (value == true) then nb = 1 end
    self._header = bit32.replace(self._header, nb, 8)
end

---Recursion Available, in a response, indicates if the replying DNS server supports recursion
---@return boolean
function DNSHeaderFlags:getRA()
    return bit32.extract(self._header, 7) == 1
end

---Recursion Available, in a response, indicates if the replying DNS server supports recursion
---@param value boolean
function DNSHeaderFlags:setRA(value)
    checkArg(1, value, "boolean")
    local nb = 0
    if (value == true) then nb = 1 end
    self._header = bit32.replace(self._header, nb, 7)
end

---Response code, can be NOERROR (0), FORMERR (1, Format error), SERVFAIL (2), NXDOMAIN (3, Nonexistent domain), etc.[37]
---@return flagRcode
function DNSHeaderFlags:getRCODE()
    return bit32.extract(self._header, 1, 4)
end

---Response code, can be NOERROR (0), FORMERR (1, Format error), SERVFAIL (2), NXDOMAIN (3, Nonexistent domain), etc.[37]
---@param value flagRcode
function DNSHeaderFlags:setRCODE(value)
    self._header = bit32.replace(self._header, value, 1, 4)
end

--#endregion

function DNSHeaderFlags:pack()
    return string.format("%.4x", self._header)
end

---@param value string
---@return DNSHeaderFlags
function DNSHeaderFlags.unpack(value)
    return DNSHeaderFlags(tonumber(value, 16))
end

--#endregion
--=============================================================================
--#region DNSHeader

---@class DNSHeader
---@field private _id number
---@field private _flags DNSHeaderFlags
---@field private _qdcount number
---@field private _ancount number
---@field private _nscount number
---@field private _arcount number
---@overload fun(id:number,flags:DNSHeaderFlags,qdcount:number,ancount:number,nscound:number,arcount:number):DNSHeader
---@operator call:DNSHeader
local DNSHeader = {}

---@return DNSHeader
setmetatable(DNSHeader, {
    ---@param self DNSHeader
    ---@param id number
    ---@param flags DNSHeaderFlags
    ---@param qdcount number
    ---@param ancount number
    ---@param nscount number
    ---@param arcount number
    __call = function(self, id, flags, qdcount, ancount, nscount, arcount)
        checkArg(1, id, "number")
        checkArg(2, flags, "table")
        checkArg(3, qdcount, "number")
        checkArg(4, ancount, "number")
        checkArg(5, nscount, "number")
        checkArg(6, arcount, "number")
        local o = {
            _id = 0,
            _flags = {},
            _qdcount = 0,
            _ancount = 0,
            _nscount = 0,
            _arcount = 0,
        }
        setmetatable(o, {__index = self})
        ---@cast o DNSHeader
        o:setId(id)
        o:setFlags(flags)
        o:setQdcount(qdcount)
        o:setAncount(ancount)
        o:setNscount(nscount)
        o:setArcount(arcount)
        return o
    end
})

--#region getter/setter

---@param value number
function DNSHeader:setId(value)
    self._id = value
end

---@return number
function DNSHeader:getId() return self._id end

---@param value DNSHeaderFlags
function DNSHeader:setFlags(value)
    self._flags = value
end

---@return DNSHeaderFlags
function DNSHeader:getFlags() return self._flags end

---@param value number
function DNSHeader:setQdcount(value)
    self._qdcount = value
end

---@return number
function DNSHeader:getQdcount() return self._qdcount end

---@param value number
function DNSHeader:setAncount(value)
    self._ancount = value
end

---@return number
function DNSHeader:getAncount() return self._ancount end

---@param value number
function DNSHeader:setNscount(value)
    self._nscount = value
end

---@return number
function DNSHeader:getNscount() return self._nscount end

---@param value number
function DNSHeader:setArcount(value)
    self._arcount = value
end

---@return number
function DNSHeader:getArcount() return self._arcount end

--#endregion

---@return string
function DNSHeader:pack()
    return string.format("%.4x%s%.4x%.4x%.4x%.4x", self:getId(), self:getFlags():pack(), self:getQdcount(), self:getAncount(), self:getNscount(), self:getArcount())
end

---@param value string
---@return DNSHeader
function DNSHeader.unpack(value)
    checkArg(1, value, 'string')
    local id, flags, qdcount, qncount, nscount, arcount = value:match("(%x%x%x%x)(%x%x%x%x)(%x%x%x%x)(%x%x%x%x)(%x%x%x%x)(%x%x%x%x)")
    flags = DNSHeaderFlags.unpack(flags)
    id = tonumber(id)
    qdcount = tonumber(qdcount)
    qncount = tonumber(qncount)
    nscount = tonumber(nscount)
    arcount = tonumber(arcount)
    return DNSHeader(id, flags, qdcount, qncount, nscount, arcount)
end

--#endregion
--=============================================================================
--#region DNSQuestion

---@class DNSQuestion
---@field private _name string
---@field private _type dnsRecordType
---@field private _class dnsRecordClass
---@overload fun(name:string,rtype:dnsRecordType,class:dnsRecordClass):DNSQuestion
---@operator call:DNSQuestion
local DNSQuestion = {}

---@return DNSQuestion
setmetatable(DNSQuestion, {
    ---@param self DNSQuestion
    ---@param name string
    ---@param rtype dnsRecordType
    ---@param class dnsRecordClass
    __call = function(self, name, rtype, class)
        local o = {
            _name = "",
            _type = 1,
            _class = 1,
        }
        setmetatable(o, {__index = self})
        ---@cast o DNSQuestion
        o:setName(name)
        o:setType(rtype)
        o:setClass(class)
        return o
    end
})

---@return string
function DNSQuestion:getName() return self._name end

---@param value string
function DNSQuestion:setName(value)
    self._name = value
end

---@return dnsRecordType
function DNSQuestion:getType() return self._type end

---@param value dnsRecordType
function DNSQuestion:setType(value)
    self._type = value
end

---@return dnsRecordClass
function DNSQuestion:getClass() return self._class end

---@param value dnsRecordClass
function DNSQuestion:setClass(value)
    self._class = value
end

---@return string
function DNSQuestion:pack()
    return table.concat({self:getName(), self:getType(), self:getClass()}, "\0")
end

---@param value string
---@return DNSQuestion
function DNSQuestion.unpack(value)
    local name, rType, class = value:match("^([^\0]*)\0([^\0]*)\0([^\0]*)$")
    rType = tonumber(rType)
    class = tonumber(class)
    return DNSQuestion(name, rType, class)
end

--#endregion
--=============================================================================
--#region DNSRessourceRecord

--TODO check _rdata type in doc
---@class DNSRessourceRecord
---@field private _name string
---@field private _type dnsRecordType
---@field private _class dnsRecordClass
---@field private _ttl number
---@field private _rdata string
---@overload fun(name:string,rtype:dnsRecordType,class:dnsRecordClass,ttl:number,rdata:string):DNSRessourceRecord
---@operator call:DNSRessourceRecord
local DNSRessourceRecord = {}

---@enum dnsRecordType
DNSRessourceRecord.TYPE  = {
    A          = 1,     --Address record	
    NS         = 2,     --Name server record	Delegates a DNS zone to use the given authoritative name servers
    CNAME      = 5,     --Canonical name record	Alias of one name to another: the DNS lookup will continue by retrying the lookup with the new name.
    SOA        = 6,     --and RFC 2308[11]	Start of [a zone of] authority record	Specifies authoritative information about a DNS zone, including the primary name server, the email of the domain administrator, the domain serial number, and several timers relating to refreshing the zone.
    PTR        = 12,    --PTR Resource Record [de]	Pointer to a canonical name. Unlike a CNAME, DNS processing stops and just the name is returned. The most common use is for implementing reverse DNS lookups, but other uses include such things as DNS-SD.
    HINFO      = 13,    --Host Information	Providing Minimal-Sized Responses to DNS Queries That Have QTYPE=ANY
    MX         = 15,    --and RFC 7505	Mail exchange record	List of mail exchange servers that accept email for a domain
    TXT        = 16,    --Text record	Originally for arbitrary human-readable text in a DNS record. Since the early 1990s, however, this record more often carries machine-readable data, such as specified by RFC 1464, opportunistic encryption, Sender Policy Framework, DKIM, DMARC, DNS-SD, etc.
    RP         = 17,    --Responsible Person	Information about the responsible person(s) for the domain. Usually an email address with the @ replaced by a .
    SIG        = 24,    --Signature	Signature record used in SIG(0) (RFC 2931) and TKEY (RFC 2930).[7] RFC 3755 designated RRSIG as the replacement for SIG for use within DNSSEC.[7]
    KEY        = 25,    --and RFC 2930[4]	Key record	Used only for SIG(0) (RFC 2931) and TKEY (RFC 2930).[5] RFC 3445 eliminated their use for application keys and limited their use to DNSSEC.[6] RFC 3755 designates DNSKEY as the replacement within DNSSEC.[7] RFC 4025 designates IPSECKEY as the replacement for use with IPsec.[8]
    AAAA       = 28,    --IPv6 address record
    LOC        = 29,    --Location record	Specifies a geographical location associated with a domain name
    SRV        = 33,    --Service locator	Generalized service location record, used for newer protocols instead of creating protocol-specific records such as MX.
    NAPTR      = 35,    --Naming Authority Pointer	Allows regular-expression-based rewriting of domain names which can then be used as URIs, further domain names to lookups, etc.
    KX         = 36,    --Key Exchanger record	Used with some cryptographic systems (not including DNSSEC) to identify a key management agent for the associated domain-name. Note that this has nothing to do with DNS Security. It is Informational status, rather than being on the IETF standards-track. It has always had limited deployment, but is still in use.
    CERT       = 37,    --Certificate record	Stores PKIX, SPKI, PGP, etc.
    DNAME      = 39,    --Delegation name record	Alias for a name and all its subnames, unlike CNAME, which is an alias for only the exact name. Like a CNAME record, the DNS lookup will continue by retrying the lookup with the new name.
    DS         = 43,    --Delegation signer	The record used to identify the DNSSEC signing key of a delegated zone
    SSHFP      = 44,    --SSH Public Key Fingerprint	Resource record for publishing SSH public host key fingerprints in the DNS, in order to aid in verifying the authenticity of the host. RFC 6594 defines ECC SSH keys and SHA-256 hashes. See the IANA SSHFP RR parameters registry for details.
    IPSECKEY   = 45,    --IPsec Key	Key record that can be used with IPsec
    RRSIG      = 46,    --DNSSEC signature	Signature for a DNSSEC-secured record set. Uses the same format as the SIG record.
    NSEC       = 47,    --Next Secure record	Part of DNSSEC—used to prove a name does not exist. Uses the same format as the (obsolete) NXT record.
    DNSKEY     = 48,    --DNS Key record	The key record used in DNSSEC. Uses the same format as the KEY record.
    DHCID      = 49,    --DHCP identifier	Used in conjunction with the FQDN option to DHCP
    NSEC3      = 50,    --Next Secure record version 3	An extension to DNSSEC that allows proof of nonexistence for a name without permitting zonewalking
    NSEC3PARAM = 51,    --NSEC3 parameters	Parameter record for use with NSEC3
    TLSA       = 52,    --TLSA certificate association	A record for DANE. RFC 6698 defines "The TLSA DNS resource record is used to associate a TLS server certificate or public key with the domain name where the record is found, thus forming a 'TLSA certificate association'".
    SMIMEA     = 53,    --S/MIME cert association[10]	Associates an S/MIME certificate with a domain name for sender authentication.
    HIP        = 55,    --Host Identity Protocol	Method of separating the end-point identifier and locator roles of IP addresses.
    CDS        = 59,    --Child DS	Child copy of DS record, for transfer to parent
    CDNSKEY    = 60,    --	Child copy of DNSKEY record, for transfer to parent
    OPENPGPKEY = 61,    --OpenPGP public key record	A DNS-based Authentication of Named Entities (DANE) method for publishing and locating OpenPGP public keys in DNS for a specific email address using an OPENPGPKEY DNS resource record.
    CSYNC      = 62,    --Child-to-Parent Synchronization	Specify a synchronization mechanism between a child and a parent DNS zone. Typical example is declaring the same NS records in the parent and the child zone
    ZONEMD     = 63,    --Message Digests for DNS Zones	Provides a cryptographic message digest over DNS zone data at rest.
    SVCB       = 64,    --Service Binding	RR that improves performance for clients that need to resolve many resources to access a domain. More info in this IETF Draft by DNSOP Working group and Akamai technologies.
    HTTPS      = 65,    --HTTPS Binding	RR that improves performance for clients that need to resolve many resources to access a domain. More info in this IETF Draft by DNSOP Working group and Akamai technologies.
    EUI48      = 108,   --MAC address (EUI-48)	A 48-bit IEEE Extended Unique Identifier.
    EUI64      = 109,   --MAC address (EUI-64)	A 64-bit IEEE Extended Unique Identifier.
    TKEY       = 249,   --Transaction Key record	A method of providing keying material to be used with TSIG that is encrypted under the public key in an accompanying KEY RR.[12]
    TSIG       = 250,   --Transaction Signature	Can be used to authenticate dynamic updates as coming from an approved client, or to authenticate responses as coming from an approved recursive name server[13] similar to DNSSEC.
    URI        = 256,   --Uniform Resource Identifier	Can be used for publishing mappings from hostnames to URIs.
    CAA        = 257,   --Certification Authority Authorization
    TA         = 32768, --—	DNSSEC Trust Authorities	Part of a deployment proposal for DNSSEC without a signed DNS root. See the IANA database and Weiler Spec for details. Uses the same format as the DS record.
    DLV        = 32769, --DNSSEC Lookaside Validation record	For publishing DNSSEC trust anchors outside of the DNS delegation chain. Uses the same format as the DS record. RFC 5074 describes a way of using these records.
}

---@enum dnsRecordClass
DNSHeaderFlags.CLASS     = {
    IN = 1, --the Internet
    CS = 2, --the CSNET class (Obsolete - used only for examples insome obsolete RFCs)
    CH = 3, --the CHAOS class
    HS = 4, --Hesiod [Dyer 87]
}

---@return DNSRessourceRecord
setmetatable(DNSRessourceRecord, {
    ---@param self DNSRessourceRecord
    ---@param name string
    ---@param rtype dnsRecordType
    ---@param class dnsRecordClass
    ---@param ttl number
    ---@param rdata string
    ---@return DNSRessourceRecord
    __call = function(self, name, rtype, class, ttl, rdata)
        local o = {
            _name = "",
            _type = 1,
            _class = 1,
            _ttl = 0,
            _rdata = ""
        }
        setmetatable(o, {__index = self})
        ---@cast o DNSRessourceRecord
        o:setName(name)
        o:setType(rtype)
        o:setClass(class)
        o:setTtl(ttl)
        o:setRdata(rdata)
        return o
    end
})

---@return string
function DNSRessourceRecord:getName() return self._name end

---@param value string
function DNSRessourceRecord:setName(value)
    self._name = value
end

---@return dnsRecordType
function DNSRessourceRecord:getType() return self._type end

---@param value dnsRecordType
function DNSRessourceRecord:setType(value)
    self._type = value
end

---@return dnsRecordClass
function DNSRessourceRecord:getClass() return self._class end

---@param value dnsRecordClass
function DNSRessourceRecord:setClass(value)
    self._class = value
end

---@return number
function DNSRessourceRecord:getTtl() return self._ttl end

---@param value number
function DNSRessourceRecord:setTtl(value)
    self._ttl = value
end

---@return string
function DNSRessourceRecord:getRdata() return self._rdata end

---@param value string
function DNSRessourceRecord:setRdata(value)
    self._rdata = value
end

---@return string
function DNSRessourceRecord:pack()
    return table.concat({self:getName(), self:getType(), self:getClass(), self:getTtl(), serialization.serialize(self:getRdata())}, "\0")
end

---@param value string
---@return DNSRessourceRecord
function DNSRessourceRecord.unpack(value)
    checkArg(1, value, 'string')
    local name, rType, class, ttl, rdata = value:match("^([^\0]*)\0([^\0]*)\0([^\0]*)\0([^\0]*)\0([^\0]*)$")
    rType = tonumber(rType)
    class = tonumber(class)
    ttl = tonumber(ttl)
    return DNSRessourceRecord(name, rType, class, ttl, serialization.unserialize(rdata))
end

--#endregion
--=============================================================================
--#region DNSMessage

---@class DNSMessage
---@field header DNSHeader
---@field questions table<DNSQuestion>
---@field answer table<DNSRessourceRecord>
---@field authority table<DNSRessourceRecord>
---@field additional table<DNSRessourceRecord>

local message = {}

---Parse the packet into objects from  udp.types
---@param packet UDPDatagram|string
---@return DNSMessage
function message.parsePacket(packet)
    if (type(packet) == "table") then
        packet = packet:payload()
    end
    ---@cast packet string
    local request = serialization.unserialize(packet)
    local header = dns.DNSHeader.unpack(request[1])
    ---@type table<DNSQuestion>
    local questions = {}
    ---@type table<DNSRessourceRecord>
    local answer = {}
    ---@type table<DNSRessourceRecord>
    local authority = {}
    ---@type table<DNSRessourceRecord>
    local additional = {}

    --unpack the ressource records
    local i = 2
    while #questions < header:getQdcount() do
        table.insert(questions, dns.DNSQuestion.unpack(request[i]))
        i = i + 1
    end
    while #answer < header:getAncount() do
        table.insert(answer, dns.DNSRessourceRecord.unpack(request[i]))
        i = i + 1
    end
    while #authority < header:getNscount() do
        table.insert(authority, dns.DNSRessourceRecord.unpack(request[i]))
        i = i + 1
    end
    while #additional < header:getArcount() do
        table.insert(additional, dns.DNSRessourceRecord.unpack(request[i]))
        i = i + 1
    end
    return {header = header, questions = questions, answer = answer, authority = authority, additional = additional}
end

---Pack the message to be sent
---@param dnsMessage DNSMessage
---@return string
function message.packDNSMessage(dnsMessage)
    local msgtbl = {}
    table.insert(msgtbl, dnsMessage.header:pack())
    for _, v in pairs(dnsMessage.questions) do table.insert(msgtbl, v:pack()) end
    for _, v in pairs(dnsMessage.answer) do table.insert(msgtbl, v:pack()) end
    for _, v in pairs(dnsMessage.authority) do table.insert(msgtbl, v:pack()) end
    for _, v in pairs(dnsMessage.additional) do table.insert(msgtbl, v:pack()) end
    return serialization.serialize(msgtbl)
end

--#endregion
--=============================================================================

dns.DNSHeaderFlags     = DNSHeaderFlags
dns.DNSHeader          = DNSHeader
dns.DNSQuestion        = DNSQuestion
dns.DNSRessourceRecord = DNSRessourceRecord
dns.message            = message
dns.QR                 = DNSHeaderFlags.QR
dns.RCODE              = DNSHeaderFlags.RCODE
dns.OPCODE             = DNSHeaderFlags.OPCODE
dns.CLASS              = DNSHeaderFlags.CLASS
dns.TYPE               = DNSRessourceRecord.TYPE
return dns
