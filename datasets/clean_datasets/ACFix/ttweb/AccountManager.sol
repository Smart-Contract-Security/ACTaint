pragma solidity ^0.8.15;
import {Errors} from "../utils/Errors.sol";
import {Helpers} from "../utils/Helpers.sol";
import {Pausable} from "../utils/Pausable.sol";
import {IERC20} from "../interface/tokens/IERC20.sol";
import {ILToken} from "../interface/tokens/ILToken.sol";
import {IAccount} from "../interface/core/IAccount.sol";
import {IRegistry} from "../interface/core/IRegistry.sol";
import {IRiskEngine} from "../interface/core/IRiskEngine.sol";
import {IAccountFactory} from "../interface/core/IAccountFactory.sol";
import {IAccountManager} from "../interface/core/IAccountManager.sol";
import {IControllerFacade} from "controller/core/IControllerFacade.sol";
contract AccountManager is Pausable, IAccountManager {
    using Helpers for address;
    bool private initialized;
    IRegistry public registry;
    IRiskEngine public riskEngine;
    IControllerFacade public controller;
    IAccountFactory public accountFactory;
    mapping(address => address[]) public inactiveAccountsOf;
    mapping(address => bool) public isCollateralAllowed;
    modifier onlyOwner(address account) {
        if (registry.ownerFor(account) != msg.sender)
            revert Errors.AccountOwnerOnly();
        _;
    }
    function init(IRegistry _registry) external {
        if (initialized) revert Errors.ContractAlreadyInitialized();
        initialized = true;
        initPausable(msg.sender);
        registry = _registry;
    }
    function initDep() external adminOnly {
        riskEngine = IRiskEngine(registry.getAddress('RISK_ENGINE'));
        controller = IControllerFacade(registry.getAddress('CONTROLLER'));
        accountFactory =
            IAccountFactory(registry.getAddress('ACCOUNT_FACTORY'));
    }
    function openAccount(address owner) external whenNotPaused {
        if (owner == address(0)) revert Errors.ZeroAddress();
        address account;
        uint length = inactiveAccountsOf[owner].length;
        if (length == 0) {
            account = accountFactory.create(address(this));
            IAccount(account).init(address(this));
            registry.addAccount(account, owner);
        } else {
            account = inactiveAccountsOf[owner][length - 1];
            inactiveAccountsOf[owner].pop();
            registry.updateAccount(account, owner);
        }
        IAccount(account).activate();
        emit AccountAssigned(account, owner);
    }
    function closeAccount(address _account) public onlyOwner(_account) {
        IAccount account = IAccount(_account);
        if (account.activationBlock() == block.number)
            revert Errors.AccountDeactivationFailure();
        if (!account.hasNoDebt()) revert Errors.OutstandingDebt();
        account.deactivate();
        registry.closeAccount(_account);
        inactiveAccountsOf[msg.sender].push(_account);
        account.sweepTo(msg.sender);
        emit AccountClosed(_account, msg.sender);
    }
    function depositEth(address account)
        external
        payable
        whenNotPaused
        onlyOwner(account)
    {
        account.safeTransferEth(msg.value);
    }
    function withdrawEth(address account, uint amt)
        external
        onlyOwner(account)
    {
        if(!riskEngine.isWithdrawAllowed(account, address(0), amt))
            revert Errors.RiskThresholdBreached();
        account.withdrawEth(msg.sender, amt);
    }
    function deposit(address account, address token, uint amt)
        external
        whenNotPaused
        onlyOwner(account)
    {
        if (!isCollateralAllowed[token])
            revert Errors.CollateralTypeRestricted();
        if (IAccount(account).hasAsset(token) == false)
            IAccount(account).addAsset(token);
        token.safeTransferFrom(msg.sender, account, amt);
    }
    function withdraw(address account, address token, uint amt)
        external
        onlyOwner(account)
    {
        if (!riskEngine.isWithdrawAllowed(account, token, amt))
            revert Errors.RiskThresholdBreached();
        account.withdraw(msg.sender, token, amt);
        if (token.balanceOf(account) == 0)
            IAccount(account).removeAsset(token);
    }
    function borrow(address account, address token, uint amt)
        external
        whenNotPaused
        onlyOwner(account)
    {
        if (registry.LTokenFor(token) == address(0))
            revert Errors.LTokenUnavailable();
        if (!riskEngine.isBorrowAllowed(account, token, amt))
            revert Errors.RiskThresholdBreached();
        if (IAccount(account).hasAsset(token) == false)
            IAccount(account).addAsset(token);
        if (ILToken(registry.LTokenFor(token)).lendTo(account, amt))
            IAccount(account).addBorrow(token);
        emit Borrow(account, msg.sender, token, amt);
    }
    function repay(address account, address token, uint amt)
        public
        onlyOwner(account)
    {
        ILToken LToken = ILToken(registry.LTokenFor(token));
        if (address(LToken) == address(0))
            revert Errors.LTokenUnavailable();
        LToken.updateState();
        if (amt == type(uint256).max) amt = LToken.getBorrowBalance(account);
        account.withdraw(address(LToken), token, amt);
        if (LToken.collectFrom(account, amt))
            IAccount(account).removeBorrow(token);
        if (IERC20(token).balanceOf(account) == 0)
            IAccount(account).removeAsset(token);
        emit Repay(account, msg.sender, token, amt);
    }
    function liquidate(address account) external {
        if (riskEngine.isAccountHealthy(account))
            revert Errors.AccountNotLiquidatable();
        _liquidate(account);
        emit AccountLiquidated(account, registry.ownerFor(account));
    }
    function approve(
        address account,
        address token,
        address spender,
        uint amt
    )
        external
        onlyOwner(account)
    {
        if(address(controller.controllerFor(spender)) == address(0))
            revert Errors.FunctionCallRestricted();
        account.safeApprove(token, spender, amt);
    }
    function exec(
        address account,
        address target,
        uint amt,
        bytes calldata data
    )
        external
        onlyOwner(account)
    {
        bool isAllowed;
        address[] memory tokensIn;
        address[] memory tokensOut;
        (isAllowed, tokensIn, tokensOut) =
            controller.canCall(target, (amt > 0), data);
        if (!isAllowed) revert Errors.FunctionCallRestricted();
        _updateTokensIn(account, tokensIn);
        (bool success,) = IAccount(account).exec(target, amt, data);
        if (!success)
            revert Errors.AccountInteractionFailure(account, target, amt, data);
        _updateTokensOut(account, tokensOut);
        if (!riskEngine.isAccountHealthy(account))
            revert Errors.RiskThresholdBreached();
    }
    function settle(address account) external onlyOwner(account) {
        address[] memory borrows = IAccount(account).getBorrows();
        for (uint i; i < borrows.length; i++) {
            uint balance;
            if (borrows[i] == address(0)) balance = account.balance;
            else balance = borrows[i].balanceOf(account);
            if ( balance > 0 ) repay(account, borrows[i], type(uint).max);
        }
    }
    function getInactiveAccountsOf(
        address user
    )
        external
        view
        returns (address[] memory)
    {
        return inactiveAccountsOf[user];
    }
    function _updateTokensIn(address account, address[] memory tokensIn)
        internal
    {
        uint tokensInLen = tokensIn.length;
        for(uint i; i < tokensInLen; ++i) {
            if (IAccount(account).hasAsset(tokensIn[i]) == false)
                IAccount(account).addAsset(tokensIn[i]);
        }
    }
    function _updateTokensOut(address account, address[] memory tokensOut)
        internal
    {
        uint tokensOutLen = tokensOut.length;
        for(uint i; i < tokensOutLen; ++i) {
            if (tokensOut[i].balanceOf(account) == 0)
                IAccount(account).removeAsset(tokensOut[i]);
        }
    }
    function _liquidate(address _account) internal {
        IAccount account = IAccount(_account);
        address[] memory accountBorrows = account.getBorrows();
        uint borrowLen = accountBorrows.length;
        ILToken LToken;
        uint amt;
        for(uint i; i < borrowLen; ++i) {
            address token = accountBorrows[i];
            LToken = ILToken(registry.LTokenFor(token));
            LToken.updateState();
            amt = LToken.getBorrowBalance(_account);
            token.safeTransferFrom(msg.sender, address(LToken), amt);
            LToken.collectFrom(_account, amt);
            account.removeBorrow(token);
        }
        account.sweepTo(msg.sender);
    }
    function toggleCollateralStatus(address token) external adminOnly {
        isCollateralAllowed[token] = !isCollateralAllowed[token];
    }
}