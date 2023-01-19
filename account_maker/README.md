# bank_account_maker
A atm like machine. Use to let users create their own account without needing to call the bank server owner.

## Installation
- run `oppm install bank_account_maker`
- Configure [bank_api](../bank_api). The secret configuration value is mandatory
- run once to generate the default config
- edit the configuration file `/etc/bank/accountMaker/config.cfg` as needed

## Usage
- Start with `accountMaker`
- Touch the screen to get a new account and debit card. If you already have a account (made on this machine), no new account will be created.
- Write down the pin
- Take your card out

## Configuration

### masterAccountCBdata
Mandatory : no  
Type : string  
Default : nil  
Clear master debit card data. Avoid editing this one by hand. Set to "" to get asked for a card next time the program is started

### masterAccountCreditPerAccount
Mandatory : no  
Type : number  
Default : 0  
Money to add to the master account for each new accounts

### newAccountCredit
Mandatory : no  
Type : number  
Default : 0  
Money to give to the newly created account

### sideChest
Mandatory : yes  
Type : number  
Default : 1  
Internal Chest side. Number correspond to the [sides api](https://ocdoc.cil.li/api:sides)

### sideDrive
Mandatory : yes  
Type : number  
Default : 5  
External disk drive. Number correspond to the [sides api](https://ocdoc.cil.li/api:sides)

## Files

### Configuration
**/etc/bank/accountMaker/config.cfg**
Configuration file

### Created accounts history
**/var/bank/accountMaker/accounts.csv**
The list of accounts created by this machine, with the account owner.  
Columns are : player name,account uuid

### Error file
**/var/bank/accountMaker/operr.csv**
THe list of errors when adding money to a account.