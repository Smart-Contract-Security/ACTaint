pragma solidity ^0.8.9;
import { IAToken } from '@aave/core-v3/contracts/interfaces/IAToken.sol';
import { IPool } from '@aave/core-v3/contracts/interfaces/IPool.sol';
import { IPoolAddressesProvider } from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import { IPriceOracle } from '@aave/core-v3/contracts/interfaces/IPriceOracle.sol';
import { IRewardsController } from '@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol';
import { WadRayMath } from '@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IERC20Metadata } from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { FixedPointMathLib } from '@rari-capital/solmate/src/utils/FixedPointMathLib.sol';
import { ISwapRouter } from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import { IBalancerVault } from '../interfaces/balancer/IBalancerVault.sol';
import { IDnGmxSeniorVault } from '../interfaces/IDnGmxSeniorVault.sol';
import { IDnGmxBatchingManager } from '../interfaces/IDnGmxBatchingManager.sol';
import { IDnGmxJuniorVault, IERC4626 } from '../interfaces/IDnGmxJuniorVault.sol';
import { IDebtToken } from '../interfaces/IDebtToken.sol';
import { IGlpManager } from '../interfaces/gmx/IGlpManager.sol';
import { ISglpExtended } from '../interfaces/gmx/ISglpExtended.sol';
import { IRewardRouterV2 } from '../interfaces/gmx/IRewardRouterV2.sol';
import { IRewardTracker } from '../interfaces/gmx/IRewardTracker.sol';
import { IVault } from '../interfaces/gmx/IVault.sol';
import { IVester } from '../interfaces/gmx/IVester.sol';
import { DnGmxJuniorVaultManager } from '../libraries/DnGmxJuniorVaultManager.sol';
import { SafeCast } from '../libraries/SafeCast.sol';
import { ERC4626Upgradeable } from '../ERC4626/ERC4626Upgradeable.sol';
contract DnGmxJuniorVault is IDnGmxJuniorVault, ERC4626Upgradeable, OwnableUpgradeable, PausableUpgradeable {
    using SafeCast for uint256;
    using WadRayMath for uint256;
    using SafeERC20 for IERC20Metadata;
    using FixedPointMathLib for uint256;
    using DnGmxJuniorVaultManager for DnGmxJuniorVaultManager.State;
    uint256 internal constant MAX_BPS = 10_000;
    uint256 internal constant PRICE_PRECISION = 1e30;
    DnGmxJuniorVaultManager.State internal state;
    uint256[50] private __gaps;
    modifier onlyKeeper() {
        if (msg.sender != state.keeper) revert OnlyKeeperAllowed(msg.sender, state.keeper);
        _;
    }
    modifier whenFlashloaned() {
        if (!state.hasFlashloaned) revert FlashloanNotInitiated();
        _;
    }
    modifier onlyBalancerVault() {
        if (msg.sender != address(state.balancerVault)) revert NotBalancerVault();
        _;
    }
    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _swapRouter,
        address _rewardRouter,
        DnGmxJuniorVaultManager.Tokens calldata _tokens,
        IPoolAddressesProvider _poolAddressesProvider
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ERC4626Upgradeable_init(address(_tokens.sGlp), _name, _symbol);
        state.weth = _tokens.weth;
        state.wbtc = _tokens.wbtc;
        state.usdc = _tokens.usdc;
        state.swapRouter = ISwapRouter(_swapRouter);
        state.rewardRouter = IRewardRouterV2(_rewardRouter);
        state.poolAddressProvider = _poolAddressesProvider;
        state.glp = IERC20Metadata(ISglpExtended(asset).glp());
        state.glpManager = IGlpManager(ISglpExtended(asset).glpManager());
        state.fsGlp = IERC20(ISglpExtended(asset).stakedGlpTracker());
        state.gmxVault = IVault(state.glpManager.vault());
        state.pool = IPool(state.poolAddressProvider.getPool());
        state.oracle = IPriceOracle(state.poolAddressProvider.getPriceOracle());
        state.aUsdc = IAToken(state.pool.getReserveData(address(state.usdc)).aTokenAddress);
        state.vWbtc = IDebtToken(state.pool.getReserveData(address(state.wbtc)).variableDebtTokenAddress);
        state.vWeth = IDebtToken(state.pool.getReserveData(address(state.weth)).variableDebtTokenAddress);
    }
    function grantAllowances() external onlyOwner {
        address aavePool = address(state.pool);
        address swapRouter = address(state.swapRouter);
        state.wbtc.approve(aavePool, type(uint256).max);
        state.wbtc.approve(swapRouter, type(uint256).max);
        state.weth.approve(aavePool, type(uint256).max);
        state.weth.approve(swapRouter, type(uint256).max);
        state.weth.approve(address(state.batchingManager), type(uint256).max);
        state.usdc.approve(aavePool, type(uint256).max);
        state.usdc.approve(address(swapRouter), type(uint256).max);
        state.usdc.approve(address(state.batchingManager), type(uint256).max);
        state.aUsdc.approve(address(state.dnGmxSeniorVault), type(uint256).max);
        IERC20Metadata(asset).approve(address(state.glpManager), type(uint256).max);
        emit AllowancesGranted();
    }
    function setAdminParams(
        address newKeeper,
        address dnGmxSeniorVault,
        uint256 newDepositCap,
        address batchingManager,
        uint16 withdrawFeeBps
    ) external onlyOwner {
        if (withdrawFeeBps > MAX_BPS) revert InvalidWithdrawFeeBps();
        state.keeper = newKeeper;
        state.dnGmxSeniorVault = IDnGmxSeniorVault(dnGmxSeniorVault);
        state.depositCap = newDepositCap;
        state.batchingManager = IDnGmxBatchingManager(batchingManager);
        state.withdrawFeeBps = withdrawFeeBps;
        emit AdminParamsUpdated(newKeeper, dnGmxSeniorVault, newDepositCap, batchingManager, withdrawFeeBps);
    }
    function setThresholds(
        uint16 slippageThresholdSwapBtcBps,
        uint16 slippageThresholdSwapEthBps,
        uint16 slippageThresholdGmxBps,
        uint128 usdcConversionThreshold,
        uint128 wethConversionThreshold,
        uint128 hedgeUsdcAmountThreshold,
        uint128 partialBtcHedgeUsdcAmountThreshold,
        uint128 partialEthHedgeUsdcAmountThreshold
    ) external onlyOwner {
        if (slippageThresholdSwapBtcBps > MAX_BPS) revert InvalidSlippageThresholdSwapBtc();
        if (slippageThresholdSwapEthBps > MAX_BPS) revert InvalidSlippageThresholdSwapEth();
        if (slippageThresholdGmxBps > MAX_BPS) revert InvalidSlippageThresholdGmx();
        state.slippageThresholdSwapBtcBps = slippageThresholdSwapBtcBps;
        state.slippageThresholdSwapEthBps = slippageThresholdSwapEthBps;
        state.slippageThresholdGmxBps = slippageThresholdGmxBps;
        state.usdcConversionThreshold = usdcConversionThreshold;
        state.wethConversionThreshold = wethConversionThreshold;
        state.hedgeUsdcAmountThreshold = hedgeUsdcAmountThreshold;
        state.partialBtcHedgeUsdcAmountThreshold = partialBtcHedgeUsdcAmountThreshold;
        state.partialEthHedgeUsdcAmountThreshold = partialEthHedgeUsdcAmountThreshold;
        emit ThresholdsUpdated(
            slippageThresholdSwapBtcBps,
            slippageThresholdSwapEthBps,
            slippageThresholdGmxBps,
            usdcConversionThreshold,
            wethConversionThreshold,
            hedgeUsdcAmountThreshold,
            partialBtcHedgeUsdcAmountThreshold,
            partialEthHedgeUsdcAmountThreshold
        );
    }
    function setRebalanceParams(
        uint32 rebalanceTimeThreshold,
        uint16 rebalanceDeltaThresholdBps,
        uint16 rebalanceHfThresholdBps
    ) external onlyOwner {
        if (rebalanceTimeThreshold > 3 days) revert InvalidRebalanceTimeThreshold();
        if (rebalanceDeltaThresholdBps > MAX_BPS) revert InvalidRebalanceDeltaThresholdBps();
        if (rebalanceHfThresholdBps < MAX_BPS || rebalanceHfThresholdBps > state.targetHealthFactor)
            revert InvalidRebalanceHfThresholdBps();
        state.rebalanceTimeThreshold = rebalanceTimeThreshold;
        state.rebalanceDeltaThresholdBps = rebalanceDeltaThresholdBps;
        state.rebalanceHfThresholdBps = rebalanceHfThresholdBps;
        emit RebalanceParamsUpdated(rebalanceTimeThreshold, rebalanceDeltaThresholdBps, rebalanceHfThresholdBps);
    }
    function setHedgeParams(
        IBalancerVault vault,
        ISwapRouter swapRouter,
        uint256 targetHealthFactor,
        IRewardsController aaveRewardsController
    ) external onlyOwner {
        if (targetHealthFactor > 20_000) revert InvalidTargetHealthFactor();
        state.balancerVault = vault;
        state.swapRouter = swapRouter;
        state.targetHealthFactor = targetHealthFactor;
        state.aaveRewardsController = aaveRewardsController;
        IPoolAddressesProvider poolAddressProvider = state.poolAddressProvider;
        IPool pool = IPool(poolAddressProvider.getPool());
        state.pool = pool;
        IPriceOracle oracle = IPriceOracle(poolAddressProvider.getPriceOracle());
        state.oracle = oracle;
        emit HedgeParamsUpdated(vault, swapRouter, targetHealthFactor, aaveRewardsController, pool, oracle);
    }
    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }
    function setFeeParams(uint16 _feeBps, address _feeRecipient) external onlyOwner {
        if (state.feeRecipient != _feeRecipient) {
            state.feeRecipient = _feeRecipient;
        } else revert InvalidFeeRecipient();
        if (_feeBps > 3000) revert InvalidFeeBps();
        state.feeBps = _feeBps;
        emit FeeParamsUpdated(_feeBps, _feeRecipient);
    }
    function withdrawFees() external {
        uint256 amount = state.protocolFee;
        state.protocolFee = 0;
        state.weth.transfer(state.feeRecipient, amount);
        emit FeesWithdrawn(amount);
    }
    function unstakeAndVestEsGmx() external onlyOwner {
        state.rewardRouter.unstakeEsGmx(state.protocolEsGmx);
        IVester(state.rewardRouter.glpVester()).deposit(state.protocolEsGmx);
        state.protocolEsGmx = 0;
    }
    function stopVestAndStakeEsGmx() external onlyOwner {
        IVester(state.rewardRouter.glpVester()).withdraw();
        uint256 esGmxWithdrawn = IERC20(state.rewardRouter.esGmx()).balanceOf(address(this));
        state.rewardRouter.stakeEsGmx(esGmxWithdrawn);
        state.protocolEsGmx += esGmxWithdrawn;
    }
    function claimVestedGmx() external onlyOwner {
        uint256 gmxClaimed = IVester(state.rewardRouter.glpVester()).claim();
        IERC20Metadata(state.rewardRouter.gmx()).safeTransfer(state.feeRecipient, gmxClaimed);
    }
    function harvestFees() external {
        state.harvestFees();
    }
    function isValidRebalance() public view returns (bool) {
        return state.isValidRebalanceTime() || state.isValidRebalanceDeviation() || state.isValidRebalanceHF();
    }
    function rebalance() external onlyKeeper {
        if (!isValidRebalance()) revert InvalidRebalance();
        state.harvestFees();
        (uint256 currentBtc, uint256 currentEth) = state.getCurrentBorrows();
        uint256 totalCurrentBorrowValue = state.getBorrowValue(currentBtc, currentEth); 
        state.rebalanceProfit(totalCurrentBorrowValue);
        bool isPartialHedge = state.rebalanceHedge(currentBtc, currentEth, totalAssets(), true);
        if (!isPartialHedge) state.lastRebalanceTS = uint48(block.timestamp);
        emit Rebalanced();
    }
    function deposit(uint256 amount, address to)
        public
        virtual
        override(IERC4626, ERC4626Upgradeable)
        whenNotPaused
        returns (uint256 shares)
    {
        _rebalanceBeforeShareAllocation();
        shares = super.deposit(amount, to);
    }
    function mint(uint256 shares, address to)
        public
        virtual
        override(IERC4626, ERC4626Upgradeable)
        whenNotPaused
        returns (uint256 amount)
    {
        _rebalanceBeforeShareAllocation();
        amount = super.mint(shares, to);
    }
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override(IERC4626, ERC4626Upgradeable) whenNotPaused returns (uint256 shares) {
        _rebalanceBeforeShareAllocation();
        shares = super.withdraw(assets, receiver, owner);
    }
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override(IERC4626, ERC4626Upgradeable) whenNotPaused returns (uint256 assets) {
        _rebalanceBeforeShareAllocation();
        assets = super.redeem(shares, receiver, owner);
    }
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external onlyBalancerVault whenFlashloaned {
        state.receiveFlashLoan(tokens, amounts, feeAmounts, userData);
    }
    function totalAssets() public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        return state.totalAssets();
    }
    function getPrice(bool maximize) public view returns (uint256) {
        uint256 aum = state.glpManager.getAum(maximize);
        uint256 totalSupply = state.glp.totalSupply();
        return aum.mulDivDown(PRICE_PRECISION, totalSupply * 1e24);
    }
    function getPriceX128() public view returns (uint256) {
        uint256 aum = state.glpManager.getAum(false);
        uint256 totalSupply = state.glp.totalSupply();
        return aum.mulDivDown(1 << 128, totalSupply * 1e24);
    }
    function getMarketValue(uint256 assetAmount) public view returns (uint256 marketValue) {
        marketValue = assetAmount.mulDivDown(getPrice(false), PRICE_PRECISION);
    }
    function getVaultMarketValue() public view returns (int256 vaultMarketValue) {
        (uint256 currentBtc, uint256 currentEth) = state.getCurrentBorrows();
        uint256 totalCurrentBorrowValue = state.getBorrowValue(currentBtc, currentEth);
        uint256 glpBalance = state.fsGlp.balanceOf(address(this)) + state.batchingManager.dnGmxJuniorVaultGlpBalance();
        vaultMarketValue = ((getMarketValue(glpBalance).toInt256() +
            state.dnUsdcDeposited +
            state.unhedgedGlpInUsdc.toInt256()) - totalCurrentBorrowValue.toInt256());
    }
    function getUsdcBorrowed() public view returns (uint256 usdcAmount) {
        return
            uint256(
                state.aUsdc.balanceOf(address(this)).toInt256() -
                    state.dnUsdcDeposited -
                    state.unhedgedGlpInUsdc.toInt256()
            );
    }
    function maxDeposit(address) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        return state.depositCap - state.totalAssets(true);
    }
    function maxMint(address receiver) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        return convertToShares(maxDeposit(receiver));
    }
    function convertToShares(uint256 assets) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        uint256 supply = totalSupply(); 
        return supply == 0 ? assets : assets.mulDivDown(supply, state.totalAssets(true));
    }
    function convertToAssets(uint256 shares) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        uint256 supply = totalSupply(); 
        return supply == 0 ? shares : shares.mulDivDown(state.totalAssets(false), supply);
    }
    function previewMint(uint256 shares) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        uint256 supply = totalSupply(); 
        return supply == 0 ? shares : shares.mulDivUp(state.totalAssets(true), supply);
    }
    function previewWithdraw(uint256 assets) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        uint256 supply = totalSupply(); 
        return
            supply == 0
                ? assets
                : assets.mulDivUp(supply * MAX_BPS, state.totalAssets(false) * (MAX_BPS - state.withdrawFeeBps));
    }
    function previewRedeem(uint256 shares) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        uint256 supply = totalSupply(); 
        return
            supply == 0
                ? shares
                : shares.mulDivDown(state.totalAssets(false) * (MAX_BPS - state.withdrawFeeBps), supply * MAX_BPS);
    }
    function depositCap() external view returns (uint256) {
        return state.depositCap;
    }
    function getCurrentBorrows() external view returns (uint256 currentBtcBorrow, uint256 currentEthBorrow) {
        return state.getCurrentBorrows();
    }
    function getOptimalBorrows(uint256 glpDeposited)
        external
        view
        returns (uint256 optimalBtcBorrow, uint256 optimalEthBorrow)
    {
        return state.getOptimalBorrows(glpDeposited);
    }
    function dnUsdcDeposited() external view returns (int256) {
        return state.dnUsdcDeposited;
    }
    function getAdminParams()
        external
        view
        returns (
            address keeper,
            IDnGmxSeniorVault dnGmxSeniorVault,
            uint256 depositCap,
            IDnGmxBatchingManager batchingManager,
            uint16 withdrawFeeBps
        )
    {
        return (state.keeper, state.dnGmxSeniorVault, state.depositCap, state.batchingManager, state.withdrawFeeBps);
    }
    function getThresholds()
        external
        view
        returns (
            uint16 slippageThresholdSwapBtcBps,
            uint16 slippageThresholdSwapEthBps,
            uint16 slippageThresholdGmxBps,
            uint128 usdcConversionThreshold,
            uint128 wethConversionThreshold,
            uint128 hedgeUsdcAmountThreshold,
            uint128 partialBtcHedgeUsdcAmountThreshold,
            uint128 partialEthHedgeUsdcAmountThreshold
        )
    {
        return (
            state.slippageThresholdSwapBtcBps,
            state.slippageThresholdSwapEthBps,
            state.slippageThresholdGmxBps,
            state.usdcConversionThreshold,
            state.wethConversionThreshold,
            state.hedgeUsdcAmountThreshold,
            state.partialBtcHedgeUsdcAmountThreshold,
            state.partialEthHedgeUsdcAmountThreshold
        );
    }
    function getRebalanceParams()
        external
        view
        returns (
            uint32 rebalanceTimeThreshold,
            uint16 rebalanceDeltaThresholdBps,
            uint16 rebalanceHfThresholdBps
        )
    {
        return (state.rebalanceTimeThreshold, state.rebalanceDeltaThresholdBps, state.rebalanceHfThresholdBps);
    }
    function getHedgeParams()
        external
        view
        returns (
            IBalancerVault balancerVault,
            ISwapRouter swapRouter,
            uint256 targetHealthFactor,
            IRewardsController aaveRewardsController
        )
    {
        return (state.balancerVault, state.swapRouter, state.targetHealthFactor, state.aaveRewardsController);
    }
    function _rebalanceBeforeShareAllocation() internal {
        state.harvestFees();
        (uint256 currentBtc, uint256 currentEth) = state.getCurrentBorrows();
        uint256 totalCurrentBorrowValue = state.getBorrowValue(currentBtc, currentEth); 
        state.rebalanceProfit(totalCurrentBorrowValue);
    }
    function beforeWithdraw(
        uint256 assets,
        uint256,
        address
    ) internal override {
        (uint256 currentBtc, uint256 currentEth) = state.getCurrentBorrows();
        state.rebalanceHedge(currentBtc, currentEth, totalAssets() - assets, false);
    }
    function afterDeposit(
        uint256,
        uint256,
        address
    ) internal override {
        if (totalAssets() > state.depositCap) revert DepositCapExceeded();
        (uint256 currentBtc, uint256 currentEth) = state.getCurrentBorrows();
        state.rebalanceHedge(currentBtc, currentEth, totalAssets(), false);
    }
}