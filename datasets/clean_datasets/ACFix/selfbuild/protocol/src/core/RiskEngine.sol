pragma solidity ^0.8.17;
import {Errors} from "../utils/Errors.sol";
import {Ownable} from "../utils/Ownable.sol";
import {IOracle} from "oracle/core/IOracle.sol";
import {IERC20} from "../interface/tokens/IERC20.sol";
import {ILToken} from "../interface/tokens/ILToken.sol";
import {IAccount} from "../interface/core/IAccount.sol";
import {IRegistry} from "../interface/core/IRegistry.sol";
import {IRiskEngine} from "../interface/core/IRiskEngine.sol";
import {IAccountManager} from "../interface/core/IAccountManager.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
contract RiskEngine is Ownable, IRiskEngine {
    using FixedPointMathLib for uint;
    IRegistry public immutable registry;
    IOracle public oracle;
    IAccountManager public accountManager;
    uint public constant balanceToBorrowThreshold = 1.2e18;
    constructor(IRegistry _registry) {
        initOwnable(msg.sender);
        registry = _registry;
    }
    function initDep() external adminOnly {
        oracle = IOracle(registry.getAddress('ORACLE'));
        accountManager = IAccountManager(registry.getAddress('ACCOUNT_MANAGER'));
    }
    function isBorrowAllowed(
        address account,
        address token,
        uint amt
    )
        external
        returns (bool)
    {
        uint borrowValue = _valueInWei(token, amt);
        return _isAccountHealthy(
            _getBalance(account) + borrowValue,
            _getBorrows(account) + borrowValue
        );
    }
    function isWithdrawAllowed(
        address account,
        address token,
        uint amt
    )
        external
        returns (bool)
    {
        if (IAccount(account).hasNoDebt()) return true;
        return _isAccountHealthy(
            _getBalance(account) - _valueInWei(token, amt),
            _getBorrows(account)
        );
    }
    function isAccountHealthy(address account) external returns (bool) {
        return _isAccountHealthy(
            _getBalance(account),
            _getBorrows(account)
        );
    }
    function getBalance(address account) external returns (uint) {
        return _getBalance(account);
    }
    function getBorrows(address account) external returns (uint) {
        return _getBorrows(account);
    }
    function _getBalance(address account) internal returns (uint) {
        address[] memory assets = IAccount(account).getAssets();
        uint assetsLen = assets.length;
        uint totalBalance;
        for(uint i; i < assetsLen; ++i) {
            totalBalance += _valueInWei(
                assets[i],
                IERC20(assets[i]).balanceOf(account)
            );
        }
        return totalBalance + account.balance;
    }
    function _getBorrows(address account) internal returns (uint) {
        if (IAccount(account).hasNoDebt()) return 0;
        address[] memory borrows = IAccount(account).getBorrows();
        uint borrowsLen = borrows.length;
        uint totalBorrows;
        for(uint i; i < borrowsLen; ++i) {
            address LTokenAddr = registry.LTokenFor(borrows[i]);
            totalBorrows += _valueInWei(
                borrows[i],
                ILToken(LTokenAddr).getBorrowBalance(account)
            );
        }
        return totalBorrows;
    }
    function _valueInWei(address token, uint amt)
        internal
        returns (uint)
    {
        return oracle.getPrice(token)
        .mulDivDown(
            amt,
            10 ** ((token == address(0)) ? 18 : IERC20(token).decimals())
        );
    }
    function _isAccountHealthy(uint accountBalance, uint accountBorrows)
        internal
        pure
        returns (bool)
    {
        return (accountBorrows == 0) ? true :
            (accountBalance.divWadDown(accountBorrows) > balanceToBorrowThreshold);
    }
}