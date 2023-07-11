import struct

def extract(n,field,width=1):
    return int(bin(n)[::-1][:-2][field:field+width][::-1] or '0',2)

def btest(*args):
    return band(*args) != 0

def band(*args):
    r = ~0
    for num in args:
        r &= num
    return r

def checksum(data):
    sum = 0
    count = len(data)
    offset = 0
    while count > 1 :
        sum += struct.unpack_from('>H', data, offset)[0]
        count -= 2
        offset +=2
    

    #Add left-over byte, if any
    if (count > 0) :
        sum += struct.unpack_from('>B', data, offset)[0]
    

    #Fold 32-bit sum to 16 bits
    while sum >> 16 != 0:
        sum = (sum & 0xffff) + (sum >> 16)
    

    return ~sum & 0xffff

def getLengthedString(val,numberType='B')->tuple[bytes,int]:
    strlen = struct.unpack_from(f'>{numberType}',val)[0]
    string = struct.unpack_from(f'>{strlen}s',val,struct.calcsize(numberType))[0]
    return string,struct.calcsize(numberType)+strlen

def makeLengthedString(val:bytes|str,numberType='B'):
    if(type(val)==str):
        val = bytes(val,'utf-8')
    return struct.pack(f'>{numberType}{len(val)}s',len(val),val)
