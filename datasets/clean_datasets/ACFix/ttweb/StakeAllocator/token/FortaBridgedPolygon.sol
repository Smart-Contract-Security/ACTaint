pragma solidity ^0.8.9;
import "./FortaCommon.sol";
contract FortaBridgedPolygon is FortaCommon {
    address public immutable childChainManagerProxy;
    error DepositOnlyByChildChainManager();
    constructor(address _childChainManagerProxy) {
        if (_childChainManagerProxy == address(0)) revert ZeroAddress("_childChainManagerProxy");
        childChainManagerProxy = _childChainManagerProxy;
    }
    function initialize(address admin) public initializer {
        __FortaCommon_init(admin);
    }
    function deposit(address user, bytes calldata depositData) external {
        if (msg.sender != childChainManagerProxy) revert DepositOnlyByChildChainManager();
        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount);
    }
    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    function withdrawTo(uint256 amount, address receiver) external {
        _transfer(msg.sender, receiver, amount);
        _burn(receiver, amount);
    }
    function version() external pure returns(string memory) {
        return "0.2.0";
    }
    uint256[49] private __gap; 
}