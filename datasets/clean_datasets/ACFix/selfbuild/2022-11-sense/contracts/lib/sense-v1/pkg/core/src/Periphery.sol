pragma solidity 0.8.13;
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { FixedMath } from "./external/FixedMath.sol";
import { BalancerVault, IAsset } from "./external/balancer/Vault.sol";
import { BalancerPool } from "./external/balancer/Pool.sol";
import { IERC3156FlashBorrower } from "./external/flashloan/IERC3156FlashBorrower.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { Levels } from "@sense-finance/v1-utils/src/libs/Levels.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
import { BaseAdapter as Adapter } from "./adapters/abstract/BaseAdapter.sol";
import { BaseFactory as AdapterFactory } from "./adapters/abstract/factories/BaseFactory.sol";
import { Divider } from "./Divider.sol";
import { PoolManager } from "@sense-finance/v1-fuse/src/PoolManager.sol";
interface SpaceFactoryLike {
    function create(address, uint256) external returns (address);
    function pools(address adapter, uint256 maturity) external view returns (address);
}
contract Periphery is Trust, IERC3156FlashBorrower {
    using FixedMath for uint256;
    using SafeTransferLib for ERC20;
    using Levels for uint256;
    uint256 public constant MIN_YT_SWAP_IN = 0.000001e18;
    uint256 public constant PRICE_ESTIMATE_ACCEPTABLE_ERROR = 0.00000001e18;
    Divider public immutable divider;
    BalancerVault public immutable balancerVault;
    PoolManager public poolManager;
    SpaceFactoryLike public spaceFactory;
    mapping(address => bool) public factories;
    mapping(address => bool) public verified;
    struct PoolLiquidity {
        ERC20[] tokens;
        uint256[] amounts;
        uint256 minBptOut;
    }
    constructor(
        address _divider,
        address _poolManager,
        address _spaceFactory,
        address _balancerVault
    ) Trust(msg.sender) {
        divider = Divider(_divider);
        poolManager = PoolManager(_poolManager);
        spaceFactory = SpaceFactoryLike(_spaceFactory);
        balancerVault = BalancerVault(_balancerVault);
    }
    function sponsorSeries(
        address adapter,
        uint256 maturity,
        bool withPool
    ) external returns (address pt, address yt) {
        (, address stake, uint256 stakeSize) = Adapter(adapter).getStakeAndTarget();
        ERC20(stake).safeTransferFrom(msg.sender, address(this), stakeSize);
        ERC20(stake).safeApprove(address(divider), stakeSize);
        (pt, yt) = divider.initSeries(adapter, maturity, msg.sender);
        if (verified[adapter]) {
            if (address(poolManager) == address(0)) {
                spaceFactory.create(adapter, maturity);
            } else {
                poolManager.queueSeries(adapter, maturity, spaceFactory.create(adapter, maturity));
            }
        } else {
            if (withPool) {
                spaceFactory.create(adapter, maturity);
            }
        }
        emit SeriesSponsored(adapter, maturity, msg.sender);
    }
    function deployAdapter(
        address f,
        address target,
        bytes memory data
    ) external returns (address adapter) {
        if (!factories[f]) revert Errors.FactoryNotSupported();
        adapter = AdapterFactory(f).deployAdapter(target, data);
        emit AdapterDeployed(adapter);
        _verifyAdapter(adapter, true);
        _onboardAdapter(adapter, true);
    }
    function swapTargetForPTs(
        address adapter,
        uint256 maturity,
        uint256 tBal,
        uint256 minAccepted
    ) external returns (uint256 ptBal) {
        ERC20(Adapter(adapter).target()).safeTransferFrom(msg.sender, address(this), tBal); 
        return _swapTargetForPTs(adapter, maturity, tBal, minAccepted);
    }
    function swapUnderlyingForPTs(
        address adapter,
        uint256 maturity,
        uint256 uBal,
        uint256 minAccepted
    ) external returns (uint256 ptBal) {
        ERC20 underlying = ERC20(Adapter(adapter).underlying());
        underlying.safeTransferFrom(msg.sender, address(this), uBal); 
        uint256 tBal = Adapter(adapter).wrapUnderlying(uBal); 
        ptBal = _swapTargetForPTs(adapter, maturity, tBal, minAccepted);
    }
    function swapTargetForYTs(
        address adapter,
        uint256 maturity,
        uint256 targetIn,
        uint256 targetToBorrow,
        uint256 minOut
    ) external returns (uint256 targetBal, uint256 ytBal) {
        ERC20(Adapter(adapter).target()).safeTransferFrom(msg.sender, address(this), targetIn);
        (targetBal, ytBal) = _flashBorrowAndSwapToYTs(adapter, maturity, targetIn, targetToBorrow, minOut);
        ERC20(Adapter(adapter).target()).safeTransfer(msg.sender, targetBal);
        ERC20(divider.yt(adapter, maturity)).safeTransfer(msg.sender, ytBal);
    }
    function swapUnderlyingForYTs(
        address adapter,
        uint256 maturity,
        uint256 underlyingIn,
        uint256 targetToBorrow,
        uint256 minOut
    ) external returns (uint256 targetBal, uint256 ytBal) {
        ERC20 underlying = ERC20(Adapter(adapter).underlying());
        underlying.safeTransferFrom(msg.sender, address(this), underlyingIn); 
        uint256 targetIn = Adapter(adapter).wrapUnderlying(underlyingIn);
        (targetBal, ytBal) = _flashBorrowAndSwapToYTs(adapter, maturity, targetIn, targetToBorrow, minOut);
        ERC20(Adapter(adapter).target()).safeTransfer(msg.sender, targetBal);
        ERC20(divider.yt(adapter, maturity)).safeTransfer(msg.sender, ytBal);
    }
    function swapPTsForTarget(
        address adapter,
        uint256 maturity,
        uint256 ptBal,
        uint256 minAccepted
    ) external returns (uint256 tBal) {
        tBal = _swapPTsForTarget(adapter, maturity, ptBal, minAccepted); 
        ERC20(Adapter(adapter).target()).safeTransfer(msg.sender, tBal); 
    }
    function swapPTsForUnderlying(
        address adapter,
        uint256 maturity,
        uint256 ptBal,
        uint256 minAccepted
    ) external returns (uint256 uBal) {
        uint256 tBal = _swapPTsForTarget(adapter, maturity, ptBal, minAccepted); 
        uBal = Adapter(adapter).unwrapTarget(tBal); 
        ERC20(Adapter(adapter).underlying()).safeTransfer(msg.sender, uBal); 
    }
    function swapYTsForTarget(
        address adapter,
        uint256 maturity,
        uint256 ytBal
    ) external returns (uint256 tBal) {
        tBal = _swapYTsForTarget(msg.sender, adapter, maturity, ytBal);
        ERC20(Adapter(adapter).target()).safeTransfer(msg.sender, tBal);
    }
    function swapYTsForUnderlying(
        address adapter,
        uint256 maturity,
        uint256 ytBal
    ) external returns (uint256 uBal) {
        uint256 tBal = _swapYTsForTarget(msg.sender, adapter, maturity, ytBal);
        uBal = Adapter(adapter).unwrapTarget(tBal);
        ERC20(Adapter(adapter).underlying()).safeTransfer(msg.sender, uBal);
    }
    function addLiquidityFromTarget(
        address adapter,
        uint256 maturity,
        uint256 tBal,
        uint8 mode,
        uint256 minBptOut
    )
        external
        returns (
            uint256 tAmount,
            uint256 issued,
            uint256 lpShares
        )
    {
        ERC20(Adapter(adapter).target()).safeTransferFrom(msg.sender, address(this), tBal);
        (tAmount, issued, lpShares) = _addLiquidity(adapter, maturity, tBal, mode, minBptOut);
    }
    function addLiquidityFromUnderlying(
        address adapter,
        uint256 maturity,
        uint256 uBal,
        uint8 mode,
        uint256 minBptOut
    )
        external
        returns (
            uint256 tAmount,
            uint256 issued,
            uint256 lpShares
        )
    {
        ERC20 underlying = ERC20(Adapter(adapter).underlying());
        underlying.safeTransferFrom(msg.sender, address(this), uBal);
        uint256 tBal = Adapter(adapter).wrapUnderlying(uBal);
        (tAmount, issued, lpShares) = _addLiquidity(adapter, maturity, tBal, mode, minBptOut);
    }
    function removeLiquidity(
        address adapter,
        uint256 maturity,
        uint256 lpBal,
        uint256[] memory minAmountsOut,
        uint256 minAccepted,
        bool intoTarget
    ) external returns (uint256 tBal, uint256 ptBal) {
        (tBal, ptBal) = _removeLiquidity(adapter, maturity, lpBal, minAmountsOut, minAccepted, intoTarget);
        ERC20(Adapter(adapter).target()).safeTransfer(msg.sender, tBal); 
    }
    function removeLiquidityAndUnwrapTarget(
        address adapter,
        uint256 maturity,
        uint256 lpBal,
        uint256[] memory minAmountsOut,
        uint256 minAccepted,
        bool intoTarget
    ) external returns (uint256 uBal, uint256 ptBal) {
        uint256 tBal;
        (tBal, ptBal) = _removeLiquidity(adapter, maturity, lpBal, minAmountsOut, minAccepted, intoTarget);
        ERC20(Adapter(adapter).underlying()).safeTransfer(msg.sender, uBal = Adapter(adapter).unwrapTarget(tBal)); 
    }
    function migrateLiquidity(
        address srcAdapter,
        address dstAdapter,
        uint256 srcMaturity,
        uint256 dstMaturity,
        uint256 lpBal,
        uint256[] memory minAmountsOut,
        uint256 minAccepted,
        uint8 mode,
        bool intoTarget,
        uint256 minBptOut
    )
        external
        returns (
            uint256 tAmount,
            uint256 issued,
            uint256 lpShares,
            uint256 ptBal
        )
    {
        if (Adapter(srcAdapter).target() != Adapter(dstAdapter).target()) revert Errors.TargetMismatch();
        uint256 tBal;
        (tBal, ptBal) = _removeLiquidity(srcAdapter, srcMaturity, lpBal, minAmountsOut, minAccepted, intoTarget);
        (tAmount, issued, lpShares) = _addLiquidity(dstAdapter, dstMaturity, tBal, mode, minBptOut);
    }
    function setFactory(address f, bool isOn) external requiresTrust {
        if (factories[f] == isOn) revert Errors.ExistingValue();
        factories[f] = isOn;
        emit FactoryChanged(f, isOn);
    }
    function setSpaceFactory(address newSpaceFactory) external requiresTrust {
        emit SpaceFactoryChanged(address(spaceFactory), newSpaceFactory);
        spaceFactory = SpaceFactoryLike(newSpaceFactory);
    }
    function setPoolManager(address newPoolManager) external requiresTrust {
        emit PoolManagerChanged(address(poolManager), newPoolManager);
        poolManager = PoolManager(newPoolManager);
    }
    function verifyAdapter(address adapter, bool addToPool) public requiresTrust {
        _verifyAdapter(adapter, addToPool);
    }
    function _verifyAdapter(address adapter, bool addToPool) private {
        verified[adapter] = true;
        if (addToPool && address(poolManager) != address(0)) poolManager.addTarget(Adapter(adapter).target(), adapter);
        emit AdapterVerified(adapter);
    }
    function onboardAdapter(address adapter, bool addAdapter) public {
        if (!divider.permissionless() && !isTrusted[msg.sender]) revert Errors.OnlyPermissionless();
        _onboardAdapter(adapter, addAdapter);
    }
    function _onboardAdapter(address adapter, bool addAdapter) private {
        ERC20 target = ERC20(Adapter(adapter).target());
        target.safeApprove(address(divider), type(uint256).max);
        target.safeApprove(address(adapter), type(uint256).max);
        ERC20(Adapter(adapter).underlying()).safeApprove(address(adapter), type(uint256).max);
        if (addAdapter) divider.addAdapter(adapter);
        emit AdapterOnboarded(adapter);
    }
    function _swap(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        bytes32 poolId,
        uint256 minAccepted
    ) internal returns (uint256 amountOut) {
        ERC20(assetIn).safeApprove(address(balancerVault), amountIn);
        BalancerVault.SingleSwap memory request = BalancerVault.SingleSwap({
            poolId: poolId,
            kind: BalancerVault.SwapKind.GIVEN_IN,
            assetIn: IAsset(assetIn),
            assetOut: IAsset(assetOut),
            amount: amountIn,
            userData: hex""
        });
        BalancerVault.FundManagement memory funds = BalancerVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });
        amountOut = balancerVault.swap(request, funds, minAccepted, type(uint256).max);
        emit Swapped(msg.sender, poolId, assetIn, assetOut, amountIn, amountOut, msg.sig);
    }
    function _swapPTsForTarget(
        address adapter,
        uint256 maturity,
        uint256 ptBal,
        uint256 minAccepted
    ) internal returns (uint256 tBal) {
        address principalToken = divider.pt(adapter, maturity);
        ERC20(principalToken).safeTransferFrom(msg.sender, address(this), ptBal); 
        BalancerPool pool = BalancerPool(spaceFactory.pools(adapter, maturity));
        tBal = _swap(principalToken, Adapter(adapter).target(), ptBal, pool.getPoolId(), minAccepted); 
    }
    function _swapTargetForPTs(
        address adapter,
        uint256 maturity,
        uint256 tBal,
        uint256 minAccepted
    ) internal returns (uint256 ptBal) {
        address principalToken = divider.pt(adapter, maturity);
        BalancerPool pool = BalancerPool(spaceFactory.pools(adapter, maturity));
        ptBal = _swap(Adapter(adapter).target(), principalToken, tBal, pool.getPoolId(), minAccepted); 
        ERC20(principalToken).safeTransfer(msg.sender, ptBal); 
    }
    function _swapYTsForTarget(
        address sender,
        address adapter,
        uint256 maturity,
        uint256 ytBal
    ) internal returns (uint256 tBal) {
        address yt = divider.yt(adapter, maturity);
        if (ytBal * 10**(18 - ERC20(yt).decimals()) <= MIN_YT_SWAP_IN) revert Errors.SwapTooSmall();
        BalancerPool pool = BalancerPool(spaceFactory.pools(adapter, maturity));
        if (sender != address(this)) ERC20(yt).safeTransferFrom(msg.sender, address(this), ytBal);
        bytes32 poolId = pool.getPoolId();
        (uint256 pti, uint256 targeti) = pool.getIndices();
        (ERC20[] memory tokens, uint256[] memory balances, ) = balancerVault.getPoolTokens(poolId);
        uint256 targetToBorrow = BalancerPool(pool).onSwap(
            BalancerPool.SwapRequest({
                kind: BalancerVault.SwapKind.GIVEN_OUT,
                tokenIn: tokens[targeti],
                tokenOut: tokens[pti],
                amount: ytBal,
                poolId: poolId,
                lastChangeBlock: 0,
                from: address(0),
                to: address(0),
                userData: ""
            }),
            balances[targeti],
            balances[pti]
        );
        tBal = _flashBorrowAndSwapFromYTs(adapter, maturity, ytBal, targetToBorrow);
    }
    function _addLiquidity(
        address adapter,
        uint256 maturity,
        uint256 tBal,
        uint8 mode,
        uint256 minBptOut
    )
        internal
        returns (
            uint256 tAmount,
            uint256 issued,
            uint256 lpShares
        )
    {
        (issued, lpShares) = _computeIssueAddLiq(adapter, maturity, tBal, minBptOut);
        if (issued > 0) {
            if (mode == 0) {
                tAmount = _swapYTsForTarget(address(this), adapter, maturity, issued);
                ERC20(Adapter(adapter).target()).safeTransfer(msg.sender, tAmount);
            } else {
                ERC20(divider.yt(adapter, maturity)).safeTransfer(msg.sender, issued);
            }
        }
    }
    function _computeIssueAddLiq(
        address adapter,
        uint256 maturity,
        uint256 tBal,
        uint256 minBptOut
    ) internal returns (uint256 issued, uint256 lpShares) {
        BalancerPool pool = BalancerPool(spaceFactory.pools(adapter, maturity));
        (ERC20[] memory tokens, uint256[] memory balances, ) = balancerVault.getPoolTokens(pool.getPoolId());
        (uint256 pti, uint256 targeti) = pool.getIndices(); 
        bool ptInitialized = balances[pti] != 0;
        uint256 ptBalInTarget = ptInitialized ? _computeTarget(adapter, balances[pti], balances[targeti], tBal) : 0;
        issued = ptBalInTarget > 0 ? divider.issue(adapter, maturity, ptBalInTarget) : 0;
        uint256[] memory amounts = new uint256[](2);
        amounts[targeti] = tBal - ptBalInTarget;
        amounts[pti] = issued;
        lpShares = _addLiquidityToSpace(pool, PoolLiquidity(tokens, amounts, minBptOut));
    }
    function _computeTarget(
        address adapter,
        uint256 ptiBal,
        uint256 targetiBal,
        uint256 tBal
    ) internal returns (uint256 tBalForIssuance) {
        return
            tBal.fmul(
                ptiBal.fdiv(
                    Adapter(adapter).scale().fmul(FixedMath.WAD - Adapter(adapter).ifee()).fmul(targetiBal) + ptiBal
                )
            );
    }
    function _removeLiquidity(
        address adapter,
        uint256 maturity,
        uint256 lpBal,
        uint256[] memory minAmountsOut,
        uint256 minAccepted,
        bool intoTarget
    ) internal returns (uint256 tBal, uint256 ptBal) {
        address target = Adapter(adapter).target();
        address pt = divider.pt(adapter, maturity);
        BalancerPool pool = BalancerPool(spaceFactory.pools(adapter, maturity));
        bytes32 poolId = pool.getPoolId();
        ERC20(address(pool)).safeTransferFrom(msg.sender, address(this), lpBal);
        uint256 _ptBal;
        (tBal, _ptBal) = _removeLiquidityFromSpace(poolId, pt, target, minAmountsOut, lpBal);
        if (divider.mscale(adapter, maturity) > 0) {
            if (uint256(Adapter(adapter).level()).redeemRestricted()) {
                ptBal = _ptBal;
            } else {
                tBal += divider.redeem(adapter, maturity, _ptBal);
            }
        } else {
            if (_ptBal > 0 && intoTarget) {
                tBal += _swap(pt, target, _ptBal, poolId, minAccepted);
            } else {
                ptBal = _ptBal;
            }
        }
        if (ptBal > 0) ERC20(pt).safeTransfer(msg.sender, ptBal); 
    }
    function _flashBorrowAndSwapFromYTs(
        address adapter,
        uint256 maturity,
        uint256 ytBalIn,
        uint256 amountToBorrow
    ) internal returns (uint256 tBal) {
        ERC20 target = ERC20(Adapter(adapter).target());
        uint256 decimals = target.decimals();
        uint256 acceptableError = decimals < 9 ? 1 : PRICE_ESTIMATE_ACCEPTABLE_ERROR / 10**(18 - decimals);
        bytes memory data = abi.encode(adapter, uint256(maturity), ytBalIn, ytBalIn - acceptableError, true);
        bool result = Adapter(adapter).flashLoan(this, address(target), amountToBorrow, data);
        if (!result) revert Errors.FlashBorrowFailed();
        tBal = target.balanceOf(address(this));
    }
    function _flashBorrowAndSwapToYTs(
        address adapter,
        uint256 maturity,
        uint256 targetIn,
        uint256 amountToBorrow,
        uint256 minOut
    ) internal returns (uint256 targetBal, uint256 ytBal) {
        bytes memory data = abi.encode(adapter, uint256(maturity), targetIn, minOut, false);
        bool result = Adapter(adapter).flashLoan(this, Adapter(adapter).target(), amountToBorrow, data);
        if (!result) revert Errors.FlashBorrowFailed();
        targetBal = ERC20(Adapter(adapter).target()).balanceOf(address(this));
        ytBal = ERC20(divider.yt(adapter, maturity)).balanceOf(address(this));
        emit YTsPurchased(msg.sender, adapter, maturity, targetIn, targetBal, ytBal);
    }
    function onFlashLoan(
        address initiator,
        address, 
        uint256 amountBorrrowed,
        uint256, 
        bytes calldata data
    ) external returns (bytes32) {
        (address adapter, uint256 maturity, uint256 amountIn, uint256 minOut, bool ytToTarget) = abi.decode(
            data,
            (address, uint256, uint256, uint256, bool)
        );
        if (msg.sender != address(adapter)) revert Errors.FlashUntrustedBorrower();
        if (initiator != address(this)) revert Errors.FlashUntrustedLoanInitiator();
        BalancerPool pool = BalancerPool(spaceFactory.pools(adapter, maturity));
        if (ytToTarget) {
            ERC20 target = ERC20(Adapter(adapter).target());
            uint256 ptBal = _swap(
                address(target),
                divider.pt(adapter, maturity),
                target.balanceOf(address(this)),
                pool.getPoolId(),
                minOut 
            );
            divider.combine(adapter, maturity, ptBal < amountIn ? ptBal : amountIn);
        } else {
            divider.issue(adapter, maturity, amountIn + amountBorrrowed);
            ERC20 pt = ERC20(divider.pt(adapter, maturity));
            _swap(
                address(pt),
                Adapter(adapter).target(),
                pt.balanceOf(address(this)),
                pool.getPoolId(),
                minOut 
            ); 
        }
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
    function _addLiquidityToSpace(BalancerPool pool, PoolLiquidity memory liq) internal returns (uint256 lpBal) {
        bytes32 poolId = pool.getPoolId();
        IAsset[] memory assets = _convertERC20sToAssets(liq.tokens);
        for (uint8 i; i < liq.tokens.length; i++) {
            liq.tokens[i].safeApprove(address(balancerVault), liq.amounts[i]);
        }
        BalancerVault.JoinPoolRequest memory request = BalancerVault.JoinPoolRequest({
            assets: assets,
            maxAmountsIn: liq.amounts,
            userData: abi.encode(liq.amounts, liq.minBptOut),
            fromInternalBalance: false
        });
        balancerVault.joinPool(poolId, address(this), msg.sender, request);
        lpBal = ERC20(address(pool)).balanceOf(msg.sender);
    }
    function _removeLiquidityFromSpace(
        bytes32 poolId,
        address pt,
        address target,
        uint256[] memory minAmountsOut,
        uint256 lpBal
    ) internal returns (uint256 tBal, uint256 ptBal) {
        (ERC20[] memory tokens, , ) = balancerVault.getPoolTokens(poolId);
        IAsset[] memory assets = _convertERC20sToAssets(tokens);
        BalancerVault.ExitPoolRequest memory request = BalancerVault.ExitPoolRequest({
            assets: assets,
            minAmountsOut: minAmountsOut,
            userData: abi.encode(lpBal),
            toInternalBalance: false
        });
        balancerVault.exitPool(poolId, address(this), payable(address(this)), request);
        tBal = ERC20(target).balanceOf(address(this));
        ptBal = ERC20(pt).balanceOf(address(this));
    }
    function _convertERC20sToAssets(ERC20[] memory tokens) internal pure returns (IAsset[] memory assets) {
        assembly {
            assets := tokens
        }
    }
    event FactoryChanged(address indexed factory, bool indexed isOn);
    event SpaceFactoryChanged(address oldSpaceFactory, address newSpaceFactory);
    event PoolManagerChanged(address oldPoolManager, address newPoolManager);
    event SeriesSponsored(address indexed adapter, uint256 indexed maturity, address indexed sponsor);
    event AdapterDeployed(address indexed adapter);
    event AdapterOnboarded(address indexed adapter);
    event AdapterVerified(address indexed adapter);
    event YTsPurchased(
        address indexed sender,
        address adapter,
        uint256 maturity,
        uint256 targetIn,
        uint256 targetReturned,
        uint256 ytOut
    );
    event Swapped(
        address indexed sender,
        bytes32 indexed poolId,
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 amountOut,
        bytes4 indexed sig
    );
}