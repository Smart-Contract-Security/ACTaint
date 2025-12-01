pragma solidity ^0.8.9;
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { PausableUpgradeable } from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import { FullMath } from '@uniswap/v3-core-0.8-support/contracts/libraries/FullMath.sol';
import { IDnGmxJuniorVault } from '../interfaces/IDnGmxJuniorVault.sol';
import { IDnGmxBatchingManager } from '../interfaces/IDnGmxBatchingManager.sol';
import { IGlpManager } from '../interfaces/gmx/IGlpManager.sol';
import { IRewardRouterV2 } from '../interfaces/gmx/IRewardRouterV2.sol';
import { IVault } from '../interfaces/gmx/IVault.sol';
import { SafeCast } from '../libraries/SafeCast.sol';
contract DnGmxBatchingManager is IDnGmxBatchingManager, OwnableUpgradeable, PausableUpgradeable {
    using FullMath for uint256;
    using FullMath for uint128;
    using SafeCast for uint256;
    struct VaultBatchingState {
        uint256 currentRound;
        uint256 roundGlpStaked;
        uint256 roundUsdcBalance;
        mapping(address => UserDeposit) userDeposits;
        mapping(uint256 => RoundDeposit) roundDeposits;
    }
    uint256 private constant MAX_BPS = 10_000;
    uint256[100] private _gaps;
    address public keeper;
    IDnGmxJuniorVault public dnGmxJuniorVault;
    uint256 public slippageThresholdGmxBps;
    uint256 public dnGmxJuniorVaultGlpBalance;
    IERC20 private sGlp;
    IERC20 private usdc;
    IGlpManager private glpManager;
    IVault private gmxUnderlyingVault;
    IRewardRouterV2 private rewardRouter;
    VaultBatchingState public vaultBatchingState;
    uint256[50] private __gaps2;
    modifier onlyDnGmxJuniorVault() {
        if (msg.sender != address(dnGmxJuniorVault)) revert CallerNotVault();
        _;
    }
    modifier onlyKeeper() {
        if (msg.sender != keeper) revert CallerNotKeeper();
        _;
    }
    function initialize(
        IERC20 _sGlp,
        IERC20 _usdc,
        IRewardRouterV2 _rewardRouter,
        IGlpManager _glpManager,
        address _dnGmxJuniorVault,
        address _keeper
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __GMXBatchingManager_init(_sGlp, _usdc, _rewardRouter, _glpManager, _dnGmxJuniorVault, _keeper);
    }
    function __GMXBatchingManager_init(
        IERC20 _sGlp,
        IERC20 _usdc,
        IRewardRouterV2 _rewardRouter,
        IGlpManager _glpManager,
        address _dnGmxJuniorVault,
        address _keeper
    ) internal onlyInitializing {
        sGlp = _sGlp;
        usdc = _usdc;
        glpManager = _glpManager;
        rewardRouter = _rewardRouter;
        gmxUnderlyingVault = IVault(glpManager.vault());
        dnGmxJuniorVault = IDnGmxJuniorVault(_dnGmxJuniorVault);
        keeper = _keeper;
        emit KeeperUpdated(_keeper);
        vaultBatchingState.currentRound = 1;
    }
    function grantAllowances() external onlyOwner {
        sGlp.approve(address(dnGmxJuniorVault), type(uint256).max);
    }
    function setKeeper(address _keeper) external onlyOwner {
        keeper = _keeper;
        emit KeeperUpdated(_keeper);
    }
    function setThresholds(uint256 _slippageThresholdGmxBps) external onlyOwner {
        slippageThresholdGmxBps = _slippageThresholdGmxBps;
        emit ThresholdsUpdated(_slippageThresholdGmxBps);
    }
    function pauseDeposit() external onlyKeeper {
        _pause();
    }
    function unpauseDeposit() external onlyKeeper {
        _unpause();
    }
    function depositToken(
        address token,
        uint256 amount,
        uint256 minUSDG
    ) external whenNotPaused onlyDnGmxJuniorVault returns (uint256 glpStaked) {
        if (token == address(0)) revert InvalidInput(0x30);
        if (amount == 0) revert InvalidInput(0x31);
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        glpStaked = _stakeGlp(token, amount, minUSDG);
        dnGmxJuniorVaultGlpBalance += glpStaked.toUint128();
        emit DepositToken(0, token, msg.sender, amount, glpStaked);
    }
    function depositUsdc(uint256 amount, address receiver) external whenNotPaused returns (uint256 glpStaked) {
        if (amount == 0) revert InvalidInput(0x21);
        if (receiver == address(0)) revert InvalidInput(0x22);
        usdc.transferFrom(msg.sender, address(this), amount);
        UserDeposit storage userDeposit = vaultBatchingState.userDeposits[receiver];
        uint128 userUsdcBalance = userDeposit.usdcBalance;
        uint256 userDepositRound = userDeposit.round;
        if (userDepositRound < vaultBatchingState.currentRound && userUsdcBalance > 0) {
            RoundDeposit storage roundDeposit = vaultBatchingState.roundDeposits[userDepositRound];
            userDeposit.unclaimedShares += userDeposit
                .usdcBalance
                .mulDiv(roundDeposit.totalShares, roundDeposit.totalUsdc)
                .toUint128();
            userUsdcBalance = 0;
        }
        userDeposit.round = vaultBatchingState.currentRound;
        userDeposit.usdcBalance = userUsdcBalance + amount.toUint128();
        vaultBatchingState.roundUsdcBalance += amount.toUint128();
        emit DepositToken(vaultBatchingState.currentRound, address(usdc), receiver, amount, glpStaked);
    }
    function executeBatchStake() external whenNotPaused onlyKeeper {
        dnGmxJuniorVault.harvestFees();
        _executeVaultUserBatchStake();
        _pause();
    }
    function executeBatchDeposit() external {
        if (paused()) _unpause();
        if (dnGmxJuniorVaultGlpBalance > 0) {
            uint256 glpToTransfer = dnGmxJuniorVaultGlpBalance;
            dnGmxJuniorVaultGlpBalance = 0;
            sGlp.transfer(address(dnGmxJuniorVault), glpToTransfer);
            emit VaultDeposit(glpToTransfer);
        }
        _executeVaultUserBatchDeposit();
    }
    function claim(address receiver, uint256 amount) external {
        _claim(msg.sender, receiver, amount);
    }
    function claimAndRedeem(address receiver) external returns (uint256 glpReceived) {
        _claim(msg.sender, msg.sender, unclaimedShares(msg.sender));
        uint256 shares = dnGmxJuniorVault.balanceOf(msg.sender);
        if (shares == 0) return 0;
        glpReceived = dnGmxJuniorVault.redeem(shares, receiver, msg.sender);
        emit ClaimedAndRedeemed(msg.sender, receiver, shares, glpReceived);
    }
    function currentRound() external view returns (uint256) {
        return vaultBatchingState.currentRound;
    }
    function usdcBalance(address account) public view returns (uint256 balance) {
        balance = vaultBatchingState.userDeposits[account].usdcBalance;
    }
    function unclaimedShares(address account) public view returns (uint256 shares) {
        UserDeposit memory userDeposit = vaultBatchingState.userDeposits[account];
        shares = userDeposit.unclaimedShares;
        if (userDeposit.round < vaultBatchingState.currentRound && userDeposit.usdcBalance > 0) {
            RoundDeposit memory roundDeposit = vaultBatchingState.roundDeposits[userDeposit.round];
            shares += userDeposit.usdcBalance.mulDiv(roundDeposit.totalShares, roundDeposit.totalUsdc).toUint128();
        }
    }
    function roundUsdcBalance() external view returns (uint256) {
        return vaultBatchingState.roundUsdcBalance;
    }
    function roundGlpStaked() external view returns (uint256) {
        return vaultBatchingState.roundGlpStaked;
    }
    function userDeposits(address account) external view returns (UserDeposit memory) {
        return vaultBatchingState.userDeposits[account];
    }
    function roundDeposits(uint256 round) external view returns (RoundDeposit memory) {
        return vaultBatchingState.roundDeposits[round];
    }
    function _stakeGlp(
        address token,
        uint256 amount,
        uint256 minUSDG
    ) internal returns (uint256 glpStaked) {
        IERC20(token).approve(address(glpManager), amount);
        glpStaked = rewardRouter.mintAndStakeGlp(token, amount, minUSDG, 0);
    }
    function _executeVaultUserBatchStake() internal {
        uint256 _roundUsdcBalance = vaultBatchingState.roundUsdcBalance;
        if (_roundUsdcBalance == 0) revert NoUsdcBalance();
        uint256 price = gmxUnderlyingVault.getMinPrice(address(usdc));
        uint256 minUsdg = _roundUsdcBalance.mulDiv(price * 1e12 * (MAX_BPS - slippageThresholdGmxBps), 1e30 * MAX_BPS);
        vaultBatchingState.roundGlpStaked = _stakeGlp(address(usdc), _roundUsdcBalance, minUsdg);
        emit BatchStake(vaultBatchingState.currentRound, _roundUsdcBalance, vaultBatchingState.roundGlpStaked);
    }
    function _executeVaultUserBatchDeposit() internal {
        if (vaultBatchingState.roundGlpStaked == 0) return;
        uint256 totalShares = dnGmxJuniorVault.deposit(vaultBatchingState.roundGlpStaked, address(this));
        vaultBatchingState.roundDeposits[vaultBatchingState.currentRound] = RoundDeposit(
            vaultBatchingState.roundUsdcBalance.toUint128(),
            totalShares.toUint128()
        );
        emit BatchDeposit(
            vaultBatchingState.currentRound,
            vaultBatchingState.roundUsdcBalance,
            vaultBatchingState.roundGlpStaked,
            totalShares
        );
        vaultBatchingState.roundUsdcBalance = 0;
        vaultBatchingState.roundGlpStaked = 0;
        ++vaultBatchingState.currentRound;
    }
    function _claim(
        address claimer,
        address receiver,
        uint256 amount
    ) internal {
        if (receiver == address(0)) revert InvalidInput(0x10);
        if (amount == 0) revert InvalidInput(0x11);
        UserDeposit storage userDeposit = vaultBatchingState.userDeposits[claimer];
        uint128 userUsdcBalance = userDeposit.usdcBalance;
        uint128 userUnclaimedShares = userDeposit.unclaimedShares;
        {
            uint256 userDepositRound = userDeposit.round;
            if (userDepositRound < vaultBatchingState.currentRound && userUsdcBalance > 0) {
                RoundDeposit storage roundDeposit = vaultBatchingState.roundDeposits[userDepositRound];
                userUnclaimedShares += userUsdcBalance
                    .mulDiv(roundDeposit.totalShares, roundDeposit.totalUsdc)
                    .toUint128();
                userDeposit.usdcBalance = 0;
            }
        }
        if (userUnclaimedShares < amount.toUint128()) revert InsufficientShares(userUnclaimedShares);
        userDeposit.unclaimedShares = userUnclaimedShares - amount.toUint128();
        dnGmxJuniorVault.transfer(receiver, amount);
        emit SharesClaimed(claimer, receiver, amount);
    }
}