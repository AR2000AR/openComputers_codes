import enum
import struct
import ipaddress
from .utils import *

class ICABLE_PACKET_KIND(enum.IntEnum):
    CLIENT_AUTH = 0x02
    SERVER_AUTH = 0x03
    CLIENT_NETCONF = 0x04
    SERVER_NETCONF = 0x05
    CLIENT_AUTH_REQUEST = 0x06
    SERVER_AUTH_REQUEST = 0x07
    CLIENT_ERROR = 0xfa
    SERVER_ERROR = 0xfb
    CLIENT_DISCONNECT = 0xfc
    SERVER_DISCONNECT = 0xfd
    CLIENT_DATA = 0xfe
    SERVER_DATA = 0xff

class CLIENT_NETCONF_KIND(enum.IntEnum):
    MANUAL_IPv4 = 0x01
    AUTO_IPv4 = 0x02

class SERVER_NETCONF_KIND(enum.IntEnum):
    IPv4 = 0x04

class SERVER_ERROR_KIND(enum.IntEnum):
        UNKNOWN_MSG = 0x01
        NOT_AUTH = 0x02
        NETCONF_ERROR = 0x04
        MISSING_NETCONF = 0x05
        NETCONF_MISSMATCH = 0x06

class IcablePacket:
    def __init__(self,kind, payload):
        self.kind = kind
        self.payload = payload
    

    @property
    def kind(self):
        return self._kind
    
    @kind.setter
    def kind(self,value):
        self._kind = value

    @property
    def len(self):
        if self.payload != None:
            return len(self.payload)
        else:
            return 0

    @property
    def payload(self):
        return self._payload
    
    @payload.setter
    def payload(self,value):
        self._payload = value

    payloadFormat = ">4sBHx"

    def pack(self):
        header = struct.pack(self.payloadFormat, b'ICAB', self.kind, self.len)
        if self.len > 0:
            header += struct.pack(f'{self.len}s', self.payload)
        
        return header
    

    @staticmethod
    def unpack(val):
        magic, kind, pklen = struct.unpack_from(IcablePacket.payloadFormat, val)
        payload=None
        if magic != b'ICAB':
            raise ValueError('Not a icable packet') 
        if pklen > 0 :
            payload = struct.unpack_from(f'{pklen}s', val, 8)[0]
        
        return IcablePacket(kind, payload)
    
    @staticmethod
    def getLenFromHeaderData(val):
        magic, len = struct.unpack_from('>4sxHx', val)
        if magic != b'ICAB':
            raise ValueError('Not a icable packet')
        return len
    
class IcableNetconf:

    @property
    def kind(self):
        return self._kind

    @kind.setter
    def kind(self,value):
        self._kind = value

    @property
    def ipv4(self):
        return self._ipv4
    
    @ipv4.setter
    def ipv4(self,value):
        if(type(value) == int):
            value = ipaddress.ip_address(value)
        self._ipv4 = value

    @property
    def mask(self):
        return self._mask
    
    @mask.setter
    def mask(self,value):
        self._mask = value

    @property
    def interface(self):
        return ipaddress.ip_interface(self.ipv4.compressed+'/'+str(self.mask))
    
    @interface.setter
    def interface(self,value:ipaddress.IPv4Interface):
       self.ipv4 = value.ip
       self.mask = value.network.prefixlen

    def pack(self):
        if(self.kind == CLIENT_NETCONF_KIND.AUTO_IPv4):
            return struct.pack('>B',self.kind)
        else:
            return struct.pack('>BIB',self.kind,int(self.ipv4),int(self.mask))
        
    @staticmethod
    def unpack(val):
        netconf = IcableNetconf()
        netconf.kind = struct.unpack_from('>B',val)[0]
        if netconf.kind != CLIENT_NETCONF_KIND.AUTO_IPv4:
            netconf.ipv4,netconf.mask = struct.unpack_from('>IB',val,struct.calcsize('>B'))
        return netconf

class IcableClientAuth:

    def __init__(self,uname:str,password:bytes):
        self._uname = uname
        self._password = password

    @property
    def uname(self):
        return self._uname

    @property
    def password(self)->bytes:
        return self._password
    
    def pack(self):
        return makeLengthedString(self.uname) + makeLengthedString(self.password)

    @staticmethod
    def unpack(value:bytes):
        uname,offset = getLengthedString(value,'B')
        password,offset = getLengthedString(value[offset:],'B')
        return IcableClientAuth(uname.decode(),password)
        
class IcableServerAuth:

    def __init__(self,sucess:bool):
        self.sucess = sucess

    def pack(self):
        return struct.pack('>B',0xff if self.sucess else 0x00)

class IcableClientAuthRequest:
    def __init__(self,username:str):
        self.username = username

    @property
    def username(self)->str:
        return self._username
    
    @username.setter
    def username(self,value:str):
       self._username = value

    @staticmethod
    def unpack(val):
        username,offset = getLengthedString(val)
        return IcableClientAuthRequest(username.decode())
    
class IcableServerAuthRequest:
    def __init__(self,salt:str,srvsalt:str):
        self.salt = salt
        self.srvsalt = srvsalt

    @property
    def salt(self)->str:
        return self._salt
    
    @salt.setter
    def salt(self,value:str):
       self._salt = value

    @property
    def srvsalt(self)->str:
        return self._srvsalt
    
    @srvsalt.setter
    def srvsalt(self,value:str):
       self._srvsalt = value

    def pack(self):
        return struct.pack('>16s16s',self.salt,self.srvsalt)

class IcableServerError:
    
    def __init__(self,kind:SERVER_ERROR_KIND,message:str|None):
        self.kind = kind
        self.message = message

    @property
    def kind(self):
        return self._kind
    
    @kind.setter
    def kind(self,value):
       self._kind = value

    def pack(self):
        data = struct.pack('>B',self.kind)
        if(self.message):
            data += makeLengthedString(self.message,'H')
        else:
            data += struct.pack('>H',0)
        return data
