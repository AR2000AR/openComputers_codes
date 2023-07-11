from . import Model
from .database import DatabaseHandler
from .network import *
import secrets
import hashlib
import random
import enum

class SubnetworkPermission(enum.IntFlag):
    GUEST = 0
    OWNER = 0x01
    FIREWALL = 0x02

class User(Model):

    def __init__(self,database:DatabaseHandler,login:str):
        self._authenticationSalt = False
        self._login = login
        super().__init__(database)

    @property
    def password(self)->str:
        self._database.execute("SELECT password FROM users WHERE login = ?",(self.login,))
        return self._database.fetchone()[0]
    
    @password.setter
    def password(self,value:str):
       with self._database.semaphore:
        self._database.execute("UPDATE users SET password = ? WHERE login = ?",(self.hashpassword(value),self.login))
        self._database.commit()

    @staticmethod
    def hashpassword(password:str):
        while True:
            password:bytes = password.encode()
            salt = secrets.token_bytes(16)
            hash = hashlib.sha256(salt+password).digest()
            res = salt+b'$'+hash
            if(res.count(b'$')==1):
                return res
            #else loop again

    @property
    def passwordHash(self)->bytes:
        salt,savedHash = self.password.split(b'$')
        return savedHash

    @property
    def salt(self)->bytes:
        salt,savedHash = self.password.split(b'$')
        return salt
    
    @property
    def authenticationSalt(self)->str:
        if(not self._authenticationSalt):
            self._authenticationSalt = secrets.token_bytes(16)
        return self._authenticationSalt
    
    def secureVerify(self,hashed:bytes):
        #we do not use the getter of authenticationSalt to not generate a new one
        if(not self._authenticationSalt):
            return False
        hashed2 = hashlib.sha256(self.authenticationSalt+self.passwordHash).digest()
        self._authenticationSalt = False #the authenticationSalt is single use
        return hashed2 == hashed

    def verify(self,password:bytes|str):
        if(type(password)==str):
            password:bytes = password.encode()
        hash = hashlib.sha256(self.salt+password).digest()
        return hash == self.passwordHash

    @property
    def subnetid(self):
        self._database.execute("SELECT subnetid FROM users WHERE login = ?",(self.login,))
        return self._database.fetchone()[0]
    
    @subnetid.setter
    def subnetid(self,value):
       with self._database.semaphore:
        self._database.execute("UPDATE users SET subnetid = ? WHERE login = ?",(value,self.login))
        self._database.commit()

    @property
    def login(self):
        return self._login
    
    @property
    def networks(self)->list[Network]:
        self._database.execute("""SELECT id from networks WHERE id IN 
        (SELECT networkid FROM networkUsers WHERE userid = ? OR subnetid = ?);""",(self.login,self.subnetid))
        networks = self._database.fetchall()
        networksDB = Networks(self._database)
        return [networksDB.getNetworkById(res[0]) for res in networks] 
    
    def addNetwork(self,net:Network,perm=0):
        self._database.execute("INSERT INTO networkUsers VALUES(?,?,?)",(net.id,self.login,perm))
        self._database.commit()

    def get_network_permission(self,net:Network)->int:
        self._database.execute("SELECT permissions FROM networkUsers WHERE userid = ? AND networkid = ?",(self.login,net.id))
        perm = self._database.fetchone()
        if(not perm):
            return 0
        else:
            return perm[0]
        
    @property
    def subnetwork_permission(self)->SubnetworkPermission:
        self._database.execute("SELECT subnetperm FROM users WHERE login = ?",(self.login,))
        res = self._database.fetchone()
        assert(res)
        return SubnetworkPermission(res[0])

class Users():
    def __init__(self,database_handler:DatabaseHandler):
        self._database = database_handler
        self._database.execute("SELECT * FROM users LIMIT 1")
        if(self._database.fetchone()==None):
            self.createUser('admin','admin')

    def getUserFromLogin(self,login:str):
        self._database.execute("SELECT * FROM users WHERE login = ?",(login,))
        if(self._database.fetchone()):
           return User(self._database,login)
        else:
            return False
        
    def get_users_in_subnet(self,subnetid:int):
        self._database.execute("SELECT login FROM users WHERE subnetid = ?",(subnetid,))
        return [self.getUserFromLogin(res[0]) for res in self._database.fetchall()]

    def createUser(self,login:str,password:str,subnetid=None):
        if(self.getUserFromLogin(login)):
            return False
        else:
            subnetperm = SubnetworkPermission(0)
            if(not subnetid):
                subnetid = random.getrandbits(32)
                subnetperm |= SubnetworkPermission.OWNER
                #TODO : make sure subnetid is uniq
            with self._database.semaphore:
                self._database.execute("INSERT INTO users VALUES(?,?,?,?)",(login,User.hashpassword(password),subnetid,int(subnetperm)))
                self._database.commit()
            return self.getUserFromLogin(login)
        
    def deleteUser(self,user:User):
        subnetwork = user.subnetid
        with self._database.semaphore:
            self._database.execute("DELETE FROM users WHERE login = ?",(user.login,))
            if(not self._database.execute("SELECT * FROM users WHERE subnetid = ?",(subnetwork,)).fetchall()):
                self._database.execute("DELETE FROM networks WHERE subnetid = ?",(subnetwork,))
            self._database.commit()