pragma solidity ^0.8.0;
import "../token/ERC20/IERC20Upgradeable.sol";
import "../interfaces/IERC3156Upgradeable.sol";
import "../utils/AddressUpgradeable.sol";
import "../proxy/utils/Initializable.sol";
contract ERC3156FlashBorrowerMockUpgradeable is Initializable, IERC3156FlashBorrowerUpgradeable {
    bytes32 internal constant _RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");
    bool _enableApprove;
    bool _enableReturn;
    event BalanceOf(address token, address account, uint256 value);
    event TotalSupply(address token, uint256 value);
    function __ERC3156FlashBorrowerMock_init(bool enableReturn, bool enableApprove) internal onlyInitializing {
        __ERC3156FlashBorrowerMock_init_unchained(enableReturn, enableApprove);
    }
    function __ERC3156FlashBorrowerMock_init_unchained(bool enableReturn, bool enableApprove) internal onlyInitializing {
        _enableApprove = enableApprove;
        _enableReturn = enableReturn;
    }
    function onFlashLoan(
        address, 
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) public override returns (bytes32) {
        require(msg.sender == token);
        emit BalanceOf(token, address(this), IERC20Upgradeable(token).balanceOf(address(this)));
        emit TotalSupply(token, IERC20Upgradeable(token).totalSupply());
        if (data.length > 0) {
            AddressUpgradeable.functionCall(token, data);
        }
        if (_enableApprove) {
            IERC20Upgradeable(token).approve(token, amount + fee);
        }
        return _enableReturn ? _RETURN_VALUE : bytes32(0);
    }
    uint256[49] private __gap;
}