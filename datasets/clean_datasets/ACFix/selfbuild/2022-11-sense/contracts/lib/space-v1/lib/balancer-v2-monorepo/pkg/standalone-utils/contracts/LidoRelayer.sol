pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/Address.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/SafeMath.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ReentrancyGuard.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "./relayer/RelayerAssetHelpers.sol";
import "./interfaces/IwstETH.sol";
contract LidoRelayer is RelayerAssetHelpers, ReentrancyGuard {
    using Address for address payable;
    using SafeMath for uint256;
    IERC20 private immutable _stETH;
    IwstETH private immutable _wstETH;
    constructor(IVault vault, IwstETH wstETH) RelayerAssetHelpers(vault) {
        _stETH = IERC20(wstETH.stETH());
        _wstETH = wstETH;
    }
    function getStETH() external view returns (address) {
        return address(_stETH);
    }
    function getWstETH() external view returns (address) {
        return address(_wstETH);
    }
    function swap(
        IVault.SingleSwap memory singleSwap,
        IVault.FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable nonReentrant returns (uint256 swapAmount) {
        require(funds.sender == msg.sender, "Invalid sender");
        address recipient = funds.recipient;
        if (singleSwap.assetIn == IAsset(address(_wstETH))) {
            funds.sender = address(this);
            require(!funds.fromInternalBalance, "Cannot send from internal balance");
            uint256 wstETHAmount = singleSwap.kind == IVault.SwapKind.GIVEN_IN ? singleSwap.amount : limit;
            _pullStETHAndWrap(msg.sender, wstETHAmount);
            _approveToken(IERC20(address(_wstETH)), address(getVault()), wstETHAmount);
            swapAmount = getVault().swap{ value: msg.value }(singleSwap, funds, limit, deadline);
            if (singleSwap.kind == IVault.SwapKind.GIVEN_OUT) {
                _unwrapAndPushStETH(msg.sender, IERC20(address(_wstETH)).balanceOf(address(this)));
            }
        } else if (singleSwap.assetOut == IAsset(address(_wstETH))) {
            funds.recipient = payable(address(this));
            require(!funds.toInternalBalance, "Cannot send to internal balance");
            swapAmount = getVault().swap{ value: msg.value }(singleSwap, funds, limit, deadline);
            _unwrapAndPushStETH(recipient, IERC20(address(_wstETH)).balanceOf(address(this)));
        } else {
            revert("Does not require wstETH");
        }
        _sweepETH();
    }
    function batchSwap(
        IVault.SwapKind kind,
        IVault.BatchSwapStep[] calldata swaps,
        IAsset[] calldata assets,
        IVault.FundManagement memory funds,
        int256[] calldata limits,
        uint256 deadline
    ) external payable nonReentrant returns (int256[] memory swapAmounts) {
        require(funds.sender == msg.sender, "Invalid sender");
        address recipient = funds.recipient;
        uint256 wstETHIndex;
        for (uint256 i; i < assets.length; i++) {
            if (assets[i] == IAsset(address(_wstETH))) {
                wstETHIndex = i;
                break;
            }
            require(i < assets.length - 1, "Does not require wstETH");
        }
        int256 wstETHLimit = limits[wstETHIndex];
        if (wstETHLimit > 0) {
            funds.sender = address(this);
            require(!funds.fromInternalBalance, "Cannot send from internal balance");
            _pullStETHAndWrap(msg.sender, uint256(wstETHLimit));
            _approveToken(IERC20(address(_wstETH)), address(getVault()), uint256(wstETHLimit));
            swapAmounts = getVault().batchSwap{ value: msg.value }(kind, swaps, assets, funds, limits, deadline);
            _unwrapAndPushStETH(msg.sender, IERC20(address(_wstETH)).balanceOf(address(this)));
        } else {
            funds.recipient = payable(address(this));
            require(!funds.toInternalBalance, "Cannot send to internal balance");
            swapAmounts = getVault().batchSwap{ value: msg.value }(kind, swaps, assets, funds, limits, deadline);
            _unwrapAndPushStETH(recipient, IERC20(address(_wstETH)).balanceOf(address(this)));
        }
        _sweepETH();
    }
    function joinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.JoinPoolRequest calldata request
    ) external payable nonReentrant {
        require(sender == msg.sender, "Invalid sender");
        uint256 wstETHAmount;
        for (uint256 i; i < request.assets.length; i++) {
            if (request.assets[i] == IAsset(address(_wstETH))) {
                wstETHAmount = request.maxAmountsIn[i];
                break;
            }
            require(i < request.assets.length - 1, "Does not require wstETH");
        }
        _pullStETHAndWrap(sender, wstETHAmount);
        IERC20(address(_wstETH)).transfer(sender, wstETHAmount);
        getVault().joinPool{ value: msg.value }(poolId, sender, recipient, request);
        _sweepETH();
    }
    function exitPool(
        bytes32 poolId,
        address sender,
        address payable recipient,
        IVault.ExitPoolRequest calldata request
    ) external nonReentrant {
        require(sender == msg.sender, "Invalid sender");
        uint256 wstETHBalanceBefore = IERC20(address(_wstETH)).balanceOf(recipient);
        getVault().exitPool(poolId, sender, recipient, request);
        uint256 wstETHBalanceAfter = IERC20(address(_wstETH)).balanceOf(recipient);
        uint256 wstETHAmount = wstETHBalanceAfter.sub(wstETHBalanceBefore);
        _pullToken(recipient, IERC20(address(_wstETH)), wstETHAmount);
        _unwrapAndPushStETH(recipient, wstETHAmount);
    }
    function _pullStETHAndWrap(address sender, uint256 wstETHAmount) private returns (uint256) {
        if (wstETHAmount == 0) return 0;
        uint256 stETHAmount = _wstETH.getStETHByWstETH(wstETHAmount) + 1;
        _pullToken(sender, _stETH, stETHAmount);
        _approveToken(_stETH, address(_wstETH), stETHAmount);
        return _wstETH.wrap(stETHAmount);
    }
    function _unwrapAndPushStETH(address recipient, uint256 wstETHAmount) private {
        if (wstETHAmount == 0) return;
        uint256 stETHAmount = _wstETH.unwrap(wstETHAmount);
        _stETH.transfer(recipient, stETHAmount);
    }
}