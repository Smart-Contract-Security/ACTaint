pragma solidity 0.8.4;
import "./ERC20Burnable.sol";
import "./IERC677Receiver.sol";
contract ERC677 is ERC20Burnable, Ownable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }
    function transferAndCall(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public returns (bool success) {
        super.transfer(_to, _value);
        _transfer(msg.sender, _to, _value);
        if (isContract(_to)) {
            contractFallback(_to, _value, _data);
        }
        return true;
    }
    function contractFallback(
        address _to,
        uint256 _value,
        bytes memory _data
    ) private {
        IERC677Receiver receiver = IERC677Receiver(_to);
        receiver.onTokenTransfer(msg.sender, _value, _data);
    }
    function isContract(address _addr) private view returns (bool hasCode) {
        uint256 length;
        assembly {
            length := extcodesize(_addr)
        }
        return length > 0;
    }
}