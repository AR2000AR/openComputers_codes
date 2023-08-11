from . import Model
from icable.firewall import Firewall

class Firewalls(Model):

    def __getitem__(self,key:int):
        cursor=self._database.execute("SELECT pickle FROM firewall WHERE subnetid = ?",(key,))
        res=cursor.fetchone()
        if(not res):
            return Firewall()
        return res[0]

    def __setitem__(self,key:int,firewall:Firewall):
        self._database.execute("INSERT OR REPLACE INTO firewall VALUES(?,?)",(key,firewall))
        self._database.commit()