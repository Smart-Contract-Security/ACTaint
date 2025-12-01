pragma solidity ^0.8.17;
import {Errors} from "../utils/Errors.sol";
import {Pausable} from "../utils/Pausable.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "./utils/ERC4626.sol";
import {IRegistry} from "../interface/core/IRegistry.sol";
import {IRateModel} from "../interface/core/IRateModel.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ILToken} from "../interface/tokens/ILToken.sol";
contract LToken is Pausable, ERC4626, ILToken {
    using FixedPointMathLib for uint;
    using SafeTransferLib for ERC20;
    bool private initialized;
    IRegistry public registry;
    IRateModel public rateModel;
    address public accountManager;
    address public treasury;
    uint public borrows;
    uint public lastUpdated;
    uint public originationFee;
    uint public totalBorrowShares;
    mapping (address => uint) public borrowsOf;
    event ReservesRedeemed(address indexed treasury, uint amt);
    modifier accountManagerOnly() {
        if (msg.sender != accountManager) revert Errors.AccountManagerOnly();
        _;
    }
    function init(
        ERC20 _asset,
        string calldata _name,
        string calldata _symbol,
        IRegistry _registry,
        uint _originationFee,
        address _treasury,
        uint _reserveShares,
        uint _maxSupply
    ) external {
        if (initialized) revert Errors.ContractAlreadyInitialized();
        if (
            address(_asset) == address(0) ||
            address(_registry) == address(0) ||
            _treasury == address(0)
        ) revert Errors.ZeroAddress();
        initialized = true;
        initPausable(msg.sender);
        initERC4626(_asset, _name, _symbol, _reserveShares, _maxSupply);
        registry = _registry;
        originationFee = _originationFee;
        treasury = _treasury;
    }
    function initDep(string calldata _rateModel) external adminOnly {
        rateModel = IRateModel(registry.getAddress(_rateModel));
        accountManager = registry.getAddress('ACCOUNT_MANAGER');
    }
    function lendTo(address account, uint amt)
        external
        whenNotPaused
        accountManagerOnly
        returns (bool isFirstBorrow)
    {
        updateState();
        isFirstBorrow = (borrowsOf[account] == 0);
        uint borrowShares;
        require((borrowShares = convertAssetToBorrowShares(amt)) != 0, "ZERO_BORROW_SHARES");
        totalBorrowShares += borrowShares;
        borrowsOf[account] += borrowShares;
        borrows += amt;
        uint fee = amt.mulDivDown(originationFee, 10 ** decimals);
        asset.safeTransfer(treasury, fee);
        asset.safeTransfer(account, amt - fee);
        return isFirstBorrow;
    }
    function collectFrom(address account, uint amt)
        external
        accountManagerOnly
        returns (bool)
    {
        uint borrowShares;
        require((borrowShares = convertAssetToBorrowShares(amt)) != 0, "ZERO_BORROW_SHARES");
        borrowsOf[account] -= borrowShares;
        totalBorrowShares -= borrowShares;
        borrows -= amt;
        return (borrowsOf[account] == 0);
    }
    function getBorrowBalance(address account) external view returns (uint) {
        return convertBorrowSharesToAsset(borrowsOf[account]);
    }
    function totalAssets() public view override returns (uint) {
        return asset.balanceOf(address(this)) + getBorrows();
    }
    function getBorrows() public view returns (uint) {
        return borrows + borrows.mulWadUp(getRateFactor());
    }
    function updateState() public {
        if (lastUpdated == block.timestamp) return;
        uint rateFactor = getRateFactor();
        uint interestAccrued = borrows.mulWadUp(rateFactor);
        borrows += interestAccrued;
        lastUpdated = block.timestamp;
    }
    function getRateFactor() internal view returns (uint) {
        return (block.timestamp == lastUpdated) ?
            0 :
            ((block.timestamp - lastUpdated)*1e18)
            .mulWadUp(
                rateModel.getBorrowRatePerSecond(
                    asset.balanceOf(address(this)),
                    borrows
                )
            );
    }
    function convertAssetToBorrowShares(uint amt) internal view returns (uint) {
        uint256 supply = totalBorrowShares;
        return supply == 0 ? amt : amt.mulDivUp(supply, getBorrows());
    }
    function convertBorrowSharesToAsset(uint debt) internal view returns (uint) {
        uint256 supply = totalBorrowShares;
        return supply == 0 ? debt : debt.mulDivDown(getBorrows(), supply);
    }
    function beforeDeposit(uint, uint) internal override { updateState(); }
    function beforeWithdraw(uint, uint) internal override { updateState(); }
    function updateOriginationFee(uint _originationFee) external adminOnly {
        originationFee = _originationFee;
    }
    function updateMaxSupply(uint _maxSupply) external adminOnly {
        maxSupply = _maxSupply;
    }
}