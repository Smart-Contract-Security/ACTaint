pragma solidity 0.5.1;
contract BirthdayCard {
    event PassphraseOK(string passphrase);
    string public message;
    bytes32 hashed_passphrase;
    ERC20 constant dai = ERC20(0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359);
    constructor(string memory _message, bytes32 _hashed_passphrase) public {
        message = _message;
        hashed_passphrase = _hashed_passphrase;
    }
    function withdraw(string memory passphrase) public {
        require(isPassphrase(passphrase));
        emit PassphraseOK(passphrase);
        assert(dai.transfer(msg.sender, dai.balanceOf(address(this))));
        selfdestruct(msg.sender);
    }
    function balanceOf() public view returns (uint) {
        return dai.balanceOf(address(this));
    }
    function isPassphrase(string memory passphrase) public view returns (bool) {
        return keccak256(bytes(passphrase)) == hashed_passphrase;
    }
}
contract ERC20Events {
    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
}
contract ERC20 is ERC20Events {
    function totalSupply() public view returns (uint);
    function balanceOf(address guy) public view returns (uint);
    function allowance(address src, address guy) public view returns (uint);
    function approve(address guy, uint wad) public returns (bool);
    function transfer(address dst, uint wad) public returns (bool);
    function transferFrom(
        address src, address dst, uint wad
    ) public returns (bool);
}