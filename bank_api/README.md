# bank_api
API to talk with `bank_server`

## Installation
- run `oppm install bank_api`

## Configuration
The configuration file for the API is `/etc/bank/api/conf.conf`

### secret
Mandatory : yes  
Type : string  
Default : ""  
Secret delivered by the server to authenticated trusted clients.  
Can be "" for untrusted clients.

### timeout
Mandatory : yes  
Type : number  
Default : 5  
How long to wait for the server to answer before giving up with a timeout (-1) status
### bank_addr
Mandatory : yes  
Type : string  
Default : "00000000-0000-0000-0000-000000000000"  
The server network card address

## Usage

### Import the library
```lua
local bank = require("bank_api")
```

### Methods
The first return value of all methods is a status code.  

#### Public methods
Those methods can be called from any client.

##### `getCredit(cbData)` -> status:int,balance:int
Return the balance of the account

##### `makeTransaction(targetAccount,cbData,amount)` -> status:int
cbData's account will pay targetAccount amount

#### Trusted client methods
All this methods require a valid secret to be set in the api's configuration file

##### `createAccount()` -> status:int, accountUUID,string
Return the newly create account's uuid

##### `requestNewCBdata(accountUUID \[,cbUUID\])` -> status:int,string:rawCBdata
Without cbUUID, the srv will assume it is a magcard from open security and need less data.

##### `editAccount(cbData,amount)` -> status:int
Add amount to the account. If amount is negative, it will be removed form the account.  
A account can't have a negative balance.

### Status codes
- 0 = OK
- 1 = NO_ACCOUNT
- 2 = ERROR_ACCOUNT
- 3 = ERROR_CB
- 4 = ERROR_AMOUNT
- 5 = ERROR_RECEIVING_ACCOUNT
- -1 = timeout
- -2 = wrong message

## Example
```lua
local libCB = require("libCB")
local bank = require("bank_api")
local PIN = "1234" --The card's pin should be asked to the user, not hard coded


local reader = libCB.waitForCB() --wait for a debit card to be available
local encryptedData = libCB.loadCB(reader) --load the debit card data
local cbData = libCB.getCB(encryptedData,PIN) --decrypt the data

--Since we already know the pin, the reader proxy could be given to getCB
--local reader = libCB.waitForCB()
--local cbData = libCB.getCB(reader,PIN)

local status,balance = bank_api.getCredit(cbData) --request the account's balance from the server
if(status == 0) then -- 0 = OK
    print(cbData.uuid,balance)
end
```