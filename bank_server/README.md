# bank_server
The server for the banking system.

## Installation

### Requirement
- 1 network card
- 1 T3 data card

### Installing from oppm
- run `oppm install bank_server`
- run `rc bank_server enable`
- run `rc bank_server start`
On first startup the server will generate it's default configuration file and encryption keys. If the keys are missing they will be regenerated but all account data and all signed credit cards will be lost.

## bank_api client config
The connect to the server, clients use the `bank_api` lib. This api need to know the server address.  
Some clients (`bank_atm`, `bank_client`, `bank_amount_maker`) need a extra configuration value. This secret provided by the server authenticate the client for sensitive operation that could break the economy.  
To generate the client configuration take out it's network card and use `generateClientAPIconfig <clientName>`. It will prompt you to swap the server's network card with the client's one to get it's address. This will create a file called `clientName.conf`. Copy this file as `/etc/bank/api/conf.conf` on the client machine.  
You can generate a generic configuration file for unauthenticated client (`vending`) with `generateClientAPIconfig -n <clientName>`.

## rc
The server can take one argument in the `/etc/rc.cfg` file :  
```
bank_server = "verbose"
```
If set, the server will log all it's operation with clear unencrypted data in `/tmp/bank_server.log`. Useful for debugging purpose. It is best to leave disabled for normal use as there is no limit to the file size.
## Configuration

### key_file
Mandatory : yes  
Type : string  
Default : "/etc/bank/server/key"  
The path to the public and private keys (without extensions)

### account_dir
Mandatory : yes  
Type : string  
Default : "/srv/bank/account/"  
The path where the server save the accounts files

## aes_key_file
Mandatory : yes  
Type : string  
Default : "/etc/bank/server/aes"  
The file containing the aes key used to encrypt the accounts files