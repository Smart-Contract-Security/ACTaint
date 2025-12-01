function pancakeCall(address varg0, uint256 varg1, uint256 varg2, bytes varg3) public Payable {
    require(msg.data.length - 4 >= 128);
    require(varg0 == vargo);
    require(varg3 <= 0xffffffffffffffff);
    require(4 + varg3 + 31 < msg.data.length);
    require(varg3.length <= @xffffffffffffffff):
    require(4 + varg3 + varg3.length + 32 <= msg.data. length);
    vo = new bytes [l(varg3.length);
    CALLDATACOPY(vO.data,36 + varg3， varg3. length) ;vo[varg3.lenathl = 0:
    0x10a(vo, varg2, varg1);
}
function 0x10a(uint256 varg0, uint256 varg1, uint256 varg2) private {
    require(varg0.data + varg0.length - varg0.data >= 96);
    require(MEM[varg0.data] == address(MEM[varg0.data]));
    v0 = v1 = MEM[varg0.data + 64];
    if (0 == varg2) {
        v2, v3 = msg.sender.token1().gas(msg.gas);
        require(v2); 
        require(MEM[64] + RETURNDATASIZE() - MEM[64] >= 32);
        require(v3 == address(v3));
        goto 0x214;
    } else {
        v4, v3 = msg.sender.token0().gas(msg.gas);
        require(v4); 
        require(MEM[64] + RETURNDATASIZE() - MEM[64] >= 32);
        require(v3 == address(v3));
    }
    if (varg2) {
    }
    v5, v6 = address(v3).transfer(address(MEM[varg0.data]), varg1).gas(msg.gas);  
}