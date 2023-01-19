# bank_atm
A simple ATM machine. It let users see their balance, deposit or withdraw coins (using [libCoin](../libCoin/))

## Installation
### Requirement
- 1 network card
- 1 transposer
- 1 T2 screen
- 1 disk drive and/or magnetic card reader
- 1? Keyboard

### Software
- Run `oppm install bank_atm`
- Configure [bank_api](../bank_api)

### Hardware
- Place a chest on top of the transposer.
- Place a chest on any other sides of the transposer.  
Chest are searched in this order : bottom, top, back, front, right, left as defined by the [sides](https://ocdoc.cil.li/api:sides) api. The first one found is the backend chest, the second will be the public chest.

## Usage
- If you plan to deposit coins, place them in the front chest.
- Insert or swipe a debit card then enter your pin.
- Chose withdraw or deposit.
- Enter the amount.
- If your card is a floppy, click exit or take your card back.