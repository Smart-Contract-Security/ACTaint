pragma solidity ^0.8.0;
import "../utils/escrow/EscrowUpgradeable.sol";
import "../proxy/utils/Initializable.sol";
abstract contract PullPaymentUpgradeable is Initializable {
    EscrowUpgradeable private _escrow;
    function __PullPayment_init() internal onlyInitializing {
        __PullPayment_init_unchained();
    }
    function __PullPayment_init_unchained() internal onlyInitializing {
        _escrow = new EscrowUpgradeable();
        _escrow.initialize();
    }
    function withdrawPayments(address payable payee) public virtual {
        _escrow.withdraw(payee);
    }
    function payments(address dest) public view returns (uint256) {
        return _escrow.depositsOf(dest);
    }
    function _asyncTransfer(address dest, uint256 amount) internal virtual {
        _escrow.deposit{value: amount}(dest);
    }
    uint256[50] private __gap;
}