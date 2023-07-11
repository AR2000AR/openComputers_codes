from . import Model
from icable.firewall import Firewall

class Firewalls(Model):

    def __getitem__(self,key:int):
        self._database.execute("SELECT pickle FROM firewall WHERE subnetid = ?",(key,))
        res=self._database.fetchone()
        if(not res):
            return Firewall()
        return res[0]

    def __setitem__(self,key:int,firewall:Firewall):
        with self._database.semaphore:
            self._database.execute("INSERT OR REPLACE INTO firewall VALUES(?,?)",(key,firewall))
            self._database.commit()