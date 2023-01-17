# vending
A automatic vending machine

## Installation
### Software
- Run `oppm install vending`
- Edit the `/etc/vending/products.csv` file to create your listing
- Set yourself as the admin player in `/etc/vending/config.cfg`
- Configure `bank_api` in `/etc/bank/api/conf.conf` if you want to accept payment via debit card.

### Hardware
You will need :
- 2 chests
- 1 transposer
- 1 T1 screen with keyboard

To allow payment via debit card :
- 1 network card
- 1 disk drive and/or 1 magnetic card reader

## Usage
Run with `vending`

### Buying items
To buy a item, place you payment method in the front chest if it is a item or coins the, enter the item number and optionally the number of time to buy it.  
Example : `1*3`. Buy the item 1 three times.

### Admin menu
Access the admin menu by typing `admin` on the prompt. From here you can configure almost everything in the `config.cfg` file.

## Configuration

### products.csv
In this csv file, you can list the products you want to sell, for which quantity, and for what (item or coins).  
The first line is the header and is ignored.  
Columns are :
- soldItem
- soldQte
- costItem
- costQte
- costCoin

Use the item id. Example :
```csv
soldItem           ,soldQte ,costItem       ,costQte ,costCoin
minecraft:dirt     ,      1 ,minecraft:coal ,      1 ,       0
minecraft:redstone ,     32 ,minecraft:air  ,      0 ,      64
minecraft:grass    ,     32 ,               ,        ,      32
minecraft:dye:12   ,      1 ,               ,        ,       1
sgcraft:naquadah   ,      1 ,               ,        ,      10
```

### config.cfg
Mosts of these settings can be changed from the admin menu

#### chestFront
Mandatory : yes  
Type : number  
Default : 3  
The publicly accessible chest.

#### chestBack
Mandatory : yes  
Type : number  
Default : 2  
The secured chest to store sold items and payment.

#### forceDriveEvent
Mandatory : yes  
Type : boolean  
Default : true  
Do not use already inserted debit card and wait for it to be inserted. Only work for floppy disk debit card.

#### acceptCoin
Mandatory : yes  
Type : boolean  
Default : true  
Accept payment in coins. See `libCoin`.

#### acceptCB
Mandatory : yes  
Type : boolean  
Default : false  
Accept payment with a debit card.

#### accountUUID
Mandatory : yes  
Type : string  
Default : ""  
Bank account to send credits to when paid via debit card.

#### logSales
Mandatory : yes  
Type : boolean  
Default : true  
Log each sales in `/var/vending/sales.csv`

#### cbTimeout
Mandatory : yes  
Type : number  
Default : 30  
Time to wait for a debit card to be read before giving up.

#### adminPlayer
Mandatory : yes  
Type : string  
Default : ""  
Player allowed to access the admin menu.

#### exitString
deprecated. Leave at default