import ipaddress
import struct
from .utils import *

class IPv4Datagram:
        PACK_FORMAT = '>BBHHHBBHII'

        def __init__(self,version:int,ihl:int,dscp:int, ecn:int, id:int, flags:int, fragmentOffset:int, ttl:int, protocol:int, checksum:int,src:ipaddress.IPv4Address, dst:ipaddress.IPv4Address, payload:str):
            self.version = version
            self.ihl = ihl
            self.dscp = dscp
            self.ecn = ecn
            self.id = id
            self.flags = flags
            self.fragmentOffset = fragmentOffset
            self.ttl = ttl
            self.protocol = protocol
            self.checksum = checksum
            self.src = src
            self.dst = dst
            self.payload = payload

        #region propery
        @property
        def version(self):
            return self._version
        
        @version.setter
        def version(self,value:int):
            self._version = value
        
        @property
        def ihl(self):
            return self._ihl
        
        @ihl.setter
        def ihl(self,value:int):
            self._ihl = value
        
        @property
        def dscp(self):
            return self._dscp
        
        @dscp.setter
        def dscp(self,value:int):
            self._dscp = value
        
        @property
        def ecn(self):
            return self._ecn
        
        @ecn.setter
        def ecn(self,value:int):
            self._ecn = value
        
        @property
        def len(self):
            return struct.calcsize(self.PACK_FORMAT) + len(self.payload)
        
        @property
        def id(self):
            return self._id
        
        @id.setter
        def id(self,value:int):
            self._id = value
        
        @property
        def flags(self):
            return self._flags
        
        @flags.setter
        def flags(self,value:int):
            self._flags = value
        
        @property
        def fragmentOffset(self):
            return self._fragmentOffset
        
        @fragmentOffset.setter
        def fragmentOffset(self,value:int):
            self._fragmentOffset = value
        
        @property
        def ttl(self):
            return self._ttl
        
        @ttl.setter
        def ttl(self,value:int):
            self._ttl = value
        
        @property
        def protocol(self):
            return self._protocol
        
        @protocol.setter
        def protocol(self,value:int):
            self._protocol = value
        
        @property
        def checksum(self):
            return self._checksum or self.calculateChecksum()
        
        @checksum.setter
        def checksum(self,value:int):
            self._checksum = value
        
        @property
        def src(self)->ipaddress.IPv4Address:
            return self._src
        
        @src.setter
        def src(self,value:int|str|ipaddress.IPv4Address):
            if(type(value)in(int,str)):
                addr = ipaddress.ip_address(value)
                if(not isinstance(addr,ipaddress.IPv4Address)):
                    raise ValueError('Must be a IPv4 address')
                else:
                    value = addr
            assert(isinstance(value,ipaddress.IPv4Address))
            self._src = value
        
        @property
        def dst(self)->ipaddress.IPv4Address:
            return self._dst
        
        @dst.setter
        def dst(self,value):
            if(type(value)in(int,str)):
                addr = ipaddress.ip_address(value)
                if(not isinstance(addr,ipaddress.IPv4Address)):
                    raise ValueError('Must be a IPv4 address')
                else:
                    value = addr
            assert(isinstance(value,ipaddress.IPv4Address))
            self._dst = value
        
        
        @property
        def payload(self)->str:
            return self._payload
        
        @payload.setter
        def payload(self,value:str):
            self._payload = value
        #endregion

        def calculateChecksum(self):
            versionAndIHL = (self.version << 4) + self.ihl
            dscpAndEcn = (self.dscp << 4) + self.ecn
            flagsAndFragOffset = (self.flags << 13) + self.fragmentOffset
            return checksum(struct.pack(self.PACK_FORMAT, versionAndIHL, dscpAndEcn, self.len, self.id, flagsAndFragOffset, self.ttl, self.protocol, 0, self.src, self.dst))
            
        @staticmethod
        def unpack(val):
            versionAndIHL, dscpAndEcn, pklen, id, flagsAndFragmentOffset, ttl, protocol, checksum, src, dst = struct.unpack_from(IPv4Datagram.PACK_FORMAT, val)
            version = extract(versionAndIHL,4,4)
            ihl = extract(versionAndIHL,0,4)
            dscp = extract(dscpAndEcn,2,6)
            ecn = extract(dscpAndEcn,0,2)
            flags = extract(flagsAndFragmentOffset,14,3)
            fragmentOffset = extract(flagsAndFragmentOffset,0,13)
            payload = struct.unpack_from(f'{pklen-(ihl*4)}s',val,struct.calcsize(IPv4Datagram.PACK_FORMAT))[0]
            return IPv4Datagram(version,ihl,dscp,ecn,id,flags,fragmentOffset,ttl,protocol,checksum,src,dst,payload)
        
        def pack(self):
            versionAndIHL = (self.version << 4) + self.ihl
            dscpAndEcn = (self.dscp << 4) + self.ecn
            flagsAndFragOffset = (self.flags << 13) + self.fragmentOffset
            header = struct.pack(self.PACK_FORMAT, versionAndIHL, dscpAndEcn, self.len, self.id, flagsAndFragOffset, self.ttl, self.protocol, self.checksum, int(self.src), int(self.dst))
            return header + struct.pack(f'{len(self.payload)}s', self.payload)

        def packForICMP(self):
            versionAndIHL = (self.version << 4) + self.ihl
            dscpAndEcn = (self.dscp << 4) + self.ecn
            flagsAndFragOffset = (self.flags << 13) + self.fragmentOffset
            header = struct.pack(self.PACK_FORMAT, versionAndIHL, dscpAndEcn, self.len, self.id, flagsAndFragOffset, self.ttl, self.protocol, self.checksum, int(self.src), int(self.dst))
            return header + struct.pack(f'8s', self.payload)
        
class ICMPPacket:
    PACK_FORMAT = '>BBHI'

    def __init__(self,icmpType,icmpCode,checksum,param,payload):
        self._type = icmpType
        self._code = icmpCode
        self._checksum = checksum
        self._param = param
        self._payload = payload

    @property
    def type(self):
        return self._type
    
    @type.setter
    def type(self,value):
       self._type = value

    @property
    def code(self):
        return self._code
    
    @code.setter
    def code(self,value):
       self._code = value

    @property
    def checksum(self):
        return self._checksum or self.calculateChecksum()
    
    @checksum.setter
    def checksum(self,value):
       self._checksum = value

    @property
    def param(self):
        return self._param
    
    @param.setter
    def param(self,value):
       self._param = value

    @property
    def payload(self):
        return self._payload
    
    @payload.setter
    def payload(self,value):
       self._payload = value

    def calculateChecksum(self):
        header = struct.pack(self.PACK_FORMAT, self.type, self.code, 0, self.param)
        header += struct.pack(f'{len(self.payload)}s', self.payload)
        return checksum(header)

    @staticmethod
    def unpack(val):
        type, code, checksum, param = struct.unpack_from(ICMPPacket.PACK_FORMAT, val)
        payload = struct.unpack_from(f'{len(val)-struct.calcsize(ICMPPacket.PACK_FORMAT)}s', val, struct.calcsize(ICMPPacket.PACK_FORMAT))[0]
        icmp = ICMPPacket(type, code,checksum, param, payload)
        icmp.checksum=checksum
        return icmp
    
    def pack(self):
        header = struct.pack(self.PACK_FORMAT, self.type, self.code, self.checksum, self.param)
        return header + struct.pack(f'{len(self.payload)}s', self.payload)

    def __str__(self):
         return f'<ICMPPayload type: {self.type} code : {self.code}>'
