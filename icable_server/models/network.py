from . import Model
import ipaddress

class Network():
    def __init__(self,id:int,subnetid:int,network:ipaddress.IPv4Network):
        self._id = id
        self._subnetid = subnetid
        self._network = network

    @property
    def network(self)->ipaddress.IPv4Network:
        return self._network
    
    @property
    def subnetid(self)->int:
        return self._subnetid
    
    @property
    def id(self)->int:
        return self._id
    
    def __lt__(self,obj):
        assert(isinstance(obj,self.__class__))
        return self.network < obj.network

    def __gt__(self,obj):
        assert(isinstance(obj,self.__class__))
        return self.network > obj.network

class Networks(Model):

    def getNetworkById(self,id:int):
        self._database.execute("SELECT subnetid,network,nmask FROM networks WHERE id = ?",(id,))
        res = self._database.fetchone()
        if(not res):
            return False
        return Network(id,res[0],ipaddress.ip_network((res[1],ipaddress.ip_address(res[2]).compressed))) 
    
    def getNetworksInSubnet(self,subnetid:int):
        self._database.execute("SELECT id,subnetid,network,nmask FROM networks WHERE subnetid = ?",(subnetid,))
        res = self._database.fetchall()
        if(not res):
            return list[Network]()
        return [Network(net[0],subnetid,ipaddress.ip_network(net[2],ipaddress.ip_address(net[3]).compressed))for net in res] 
    
    def getAllNetworks(self):
        self._database.execute("SELECT id,subnetid,network,nmask FROM networks")
        res = self._database.fetchall()
        if(not res):
            return list[Network]()
        return [Network(net[0],net[1],ipaddress.ip_network((net[2],ipaddress.ip_address(net[3]).compressed)))for net in res] 

    def createNetwork(self,subnetwork:int,network:ipaddress.IPv4Network)    :
        with self._database.semaphore:
            self._database.execute("INSERT INTO networks(subnetid,network,nmask) VALUES(?,?,?)",(subnetwork,int(network.network_address),int(network.netmask)))
            self._database.commit()
        self._database.execute("SELECT id from networks WHERE subnetid = ? AND network = ? and nmask = ?",(subnetwork,int(network.network_address),int(network.netmask)))
        res = self._database.fetchone()        
        nt = self.getNetworkById(res[0])
        assert(isinstance(nt,Network))
        return nt

    def deleteNetwork(self,network:Network):
        with self._database.semaphore:
            self._database.execute("DELETE FROM networks WHERE id = ?",(network.id,))
            self._database.commit()
