pragma solidity ^0.8.4;
import {ERC20} from "./ERC20.sol";
contract WETH is ERC20 {
    error ETHTransferFailed();
    event Deposit(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);
    uint256 private constant _DEPOSIT_EVENT_SIGNATURE =
        0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c;
    uint256 private constant _WITHDRAWAL_EVENT_SIGNATURE =
        0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65;
    function name() public view virtual override returns (string memory) {
        return "Wrapped Ether";
    }
    function symbol() public view virtual override returns (string memory) {
        return "WETH";
    }
    function deposit() public payable virtual {
        _mint(msg.sender, msg.value);
        assembly {
            mstore(0x00, callvalue())
            log2(0x00, 0x20, _DEPOSIT_EVENT_SIGNATURE, caller())
        }
    }
    function withdraw(uint256 amount) public virtual {
        _burn(msg.sender, amount);
        assembly {
            mstore(0x00, amount)
            log2(0x00, 0x20, _WITHDRAWAL_EVENT_SIGNATURE, caller())
            if iszero(call(gas(), caller(), amount, 0, 0, 0, 0)) {
                mstore(0x00, 0xb12d13eb)
                revert(0x1c, 0x04)
            }
        }
    }
    receive() external payable virtual {
        deposit();
    }
}