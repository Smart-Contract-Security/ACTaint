pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract Subaccount {
    address public owner;
    bool public initialized;
    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    event ExecuteTransaction(address indexed owner, address subaccount, address to, bytes data, uint256 value);
    function init(address _owner) external {
        require(!initialized, "ALREADY INITIALIZED");
        initialized = true;
        owner = _owner;
    }
    function execute(address to, bytes calldata data, uint256 value) external onlyOwner returns (bytes memory){
        require(to != address(0));
        (bool success, bytes memory returnData) = to.call{value: value}(data);
        if (!success) {
            assembly {
                let ptr := mload(0x40)
                let size := returndatasize()
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
        emit ExecuteTransaction(owner, address(this), to, data, value);
        return returnData;
    }
}