import ipaddress
import enum
import sqlite3
import pickle
from .packet import IPv4Datagram
from .firewall import *

class FIREWALL_ACTION(enum.Enum):
        ALLOW = 1
        REJECT = 2
        DROP = 3

class FirewallRule():
    @property
    def src(self)->ipaddress.IPv4Network:
        return self._src
    
    @src.setter
    def src(self,value:ipaddress.IPv4Network|str):
        if(type(value)==str):
            addr = ipaddress.ip_network(value)
            if(not isinstance(addr,ipaddress.IPv4Network)):
                raise ValueError('Must be a IPv4 address')
            else:
                value = addr
        assert(isinstance(value,ipaddress.IPv4Network))
        self._src = value

    @property
    def dst(self)->ipaddress.IPv4Network:
        return self._dst
    
    @dst.setter
    def dst(self,value:ipaddress.IPv4Network|str):
        if(type(value)==str):
            addr = ipaddress.ip_network(value)
            if(not isinstance(addr,ipaddress.IPv4Network)):
                raise ValueError('Must be a IPv4 address')
            else:
                value = addr
        assert(isinstance(value,ipaddress.IPv4Network))
        self._dst = value

    @property
    def action(self)->FIREWALL_ACTION:
        return self._action
    
    @action.setter
    def action(self,value:FIREWALL_ACTION):
       self._action = value

    def match(self,ip:IPv4Datagram):
        return ip.src in self.src and ip.dst in self.dst
    
    def __eq__(self,rule):
        return isinstance(rule,self.__class__) and self.src == rule.src and self.dst == rule.dst and self.action == rule.action
    
class Firewall():
    def __init__(self,defaulAction=FIREWALL_ACTION.ALLOW):
        self._rules = list[FirewallRule]()
        self.action = defaulAction

    def insertRule(self,id:int,rule:FirewallRule):
        self._rules.insert(id,rule)

    def appendRule(self,rule:FirewallRule):
        self._rules.append(rule)

    @property
    def rules(self):
        return self._rules

    @property
    def action(self)->FIREWALL_ACTION:
        return self._action
    
    @action.setter
    def action(self,value:FIREWALL_ACTION):
       self._action = value

    def removeRule(self,rule:FirewallRule):
        self._rules.remove(rule)

    def getAction(self,datagram:IPv4Datagram):
        for rule in self.rules:
            if(rule.match(datagram)):
                return rule.action
        return self.action
    
    def __conform__(self,protocol):
        if protocol is sqlite3.PrepareProtocol:
            return pickle.dumps(self)

    @staticmethod
    def sqlite_convert(raw:bytes):
        obj = pickle.loads(raw)
        if(not isinstance(obj,Firewall)):
           raise ValueError('Not a Firewall blob')
        return obj
    
sqlite3.register_converter('FIREWALL',Firewall.sqlite_convert)