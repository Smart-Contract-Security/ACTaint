pragma solidity ^0.8.0;
import "./EscrowUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract ConditionalEscrowUpgradeable is Initializable, EscrowUpgradeable {
    function __ConditionalEscrow_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }
    function __ConditionalEscrow_init_unchained() internal onlyInitializing {
    }
    function withdrawalAllowed(address payee) public view virtual returns (bool);
    function withdraw(address payable payee) public virtual override {
        require(withdrawalAllowed(payee), "ConditionalEscrow: payee is not allowed to withdraw");
        super.withdraw(payee);
    }
    uint256[50] private __gap;
}