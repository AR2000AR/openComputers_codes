from . import database
from sqlite3 import Cursor

__all__ = ["user","network","firewall","web","database"]

class Model():
    """Abstract class for data model calss"""

    def __init__(self,database:database.DatabaseHandler):
        self._database = database
