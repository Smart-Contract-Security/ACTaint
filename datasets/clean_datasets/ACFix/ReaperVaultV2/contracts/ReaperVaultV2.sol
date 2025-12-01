pragma solidity 0.8.11;
import "./interfaces/IStrategy.sol";
import "./interfaces/IERC4626.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {FixedPointMathLib} from "./library/FixedPointMathLib.sol";
contract ReaperVaultV2 is IERC4626, ERC20, ReentrancyGuard, AccessControlEnumerable {
    using SafeERC20 for IERC20Metadata;
    using FixedPointMathLib for uint256;
    struct StrategyParams {
        uint256 activation; 
        uint256 allocBPS; 
        uint256 allocated; 
        uint256 gains; 
        uint256 losses; 
        uint256 lastReport; 
    }
    mapping(address => StrategyParams) public strategies;  
    address[] public withdrawalQueue; 
    uint256 public constant DEGRADATION_COEFFICIENT = 10 ** 18; 
    uint256 public constant PERCENT_DIVISOR = 10_000; 
    uint256 public tvlCap; 
    uint256 public totalAllocBPS; 
    uint256 public totalAllocated; 
    uint256 public lastReport; 
    uint256 public constructionTime; 
    bool public emergencyShutdown; 
    address public immutable asset; 
    uint256 public withdrawMaxLoss = 1; 
    uint256 public lockedProfitDegradation; 
    uint256 public  lockedProfit; 
    bytes32 public constant STRATEGIST = keccak256("STRATEGIST");
    bytes32 public constant GUARDIAN = keccak256("GUARDIAN");
    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32[] private cascadingAccess;
    event TvlCapUpdated(uint256 newTvlCap);
    event LockedProfitDegradationUpdated(uint256 degradation);
    event StrategyReported(
        address indexed strategy,
        int256 roi,
        uint256 repayment,
        uint256 gains,
        uint256 losses,
        uint256 allocated,
        uint256 allocBPS 
    );
    event StrategyAdded(address indexed strategy, uint256 allocBPS);
    event StrategyAllocBPSUpdated(address indexed strategy, uint256 allocBPS);
    event StrategyRevoked(address indexed strategy);
    event UpdateWithdrawalQueue(address[] withdrawalQueue);
    event WithdrawMaxLossUpdated(uint256 withdrawMaxLoss);
    event EmergencyShutdown(bool active);
    event InCaseTokensGetStuckCalled(address token, uint256 amount);
    constructor(
        address _asset,
        string memory _name,
        string memory _symbol,
        uint256 _tvlCap,
        address[] memory _strategists,
        address[] memory _multisigRoles
    ) ERC20(string(_name), string(_symbol)) {
        asset = _asset;
        constructionTime = block.timestamp;
        lastReport = block.timestamp;
        tvlCap = _tvlCap;
        lockedProfitDegradation = DEGRADATION_COEFFICIENT * 46 / 10 ** 6; 
        for (uint256 i = 0; i < _strategists.length; i = _uncheckedInc(i)) {
            _grantRole(STRATEGIST, _strategists[i]);
        }
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, _multisigRoles[0]);
        _grantRole(ADMIN, _multisigRoles[1]);
        _grantRole(GUARDIAN, _multisigRoles[2]);
        cascadingAccess = [DEFAULT_ADMIN_ROLE, ADMIN, GUARDIAN, STRATEGIST];
    }
    function totalAssets() public view returns (uint256) {
        return IERC20Metadata(asset).balanceOf(address(this)) + totalAllocated;
    }
    function _freeFunds() internal view returns (uint256) {
        return totalAssets() - _calculateLockedProfit();
    }
    function _calculateLockedProfit() internal view returns (uint256) {
        uint256 lockedFundsRatio = (block.timestamp - lastReport) * lockedProfitDegradation;
        if(lockedFundsRatio < DEGRADATION_COEFFICIENT) {
            return lockedProfit - (
                lockedFundsRatio
                * lockedProfit
                / DEGRADATION_COEFFICIENT
            );
        } else {
            return 0;
        }
    }
    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        uint256 freeFunds = _freeFunds();
        if (freeFunds == 0 || _totalSupply == 0) return assets;
        return assets.mulDivDown(_totalSupply, freeFunds);
    }
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) return shares; 
        return shares.mulDivDown(_freeFunds(), _totalSupply);
    }
    function maxDeposit(address receiver) public view returns (uint256) {
        uint256 _totalAssets = totalAssets();
        if (_totalAssets > tvlCap) {
            return 0;
        }
        return tvlCap - _totalAssets;
    }
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }
    function depositAll() external {
        deposit(IERC20Metadata(asset).balanceOf(msg.sender), msg.sender);
    }
    function deposit(uint256 assets, address receiver) public nonReentrant returns (uint256 shares) {
        require(!emergencyShutdown, "Cannot deposit during emergency shutdown");
        require(assets != 0, "please provide amount");
        uint256 _pool = totalAssets();
        require(_pool + assets <= tvlCap, "vault is full!");
        shares = previewDeposit(assets);
        IERC20Metadata(asset).safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }
    function maxMint(address receiver) public view virtual returns (uint256) {
        return convertToShares(maxDeposit(address(0)));
    }
    function previewMint(uint256 shares) public view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) return shares; 
        return shares.mulDivUp(_freeFunds(), _totalSupply);
    }
    function mint(uint256 shares, address receiver) external nonReentrant returns (uint256) {
        require(!emergencyShutdown, "Cannot mint during emergency shutdown");
        require(shares != 0, "please provide amount");
        uint256 assets = previewMint(shares);
        uint256 _pool = totalAssets();
        require(_pool + assets <= tvlCap, "vault is full!");
        if (_freeFunds() == 0) assets = shares;
        IERC20Metadata(asset).safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
        return assets;
    }
    function maxWithdraw(address owner) external view returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }
    function previewWithdraw(uint256 assets) public view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        if (totalSupply() == 0) return 0;
        uint256 freeFunds = _freeFunds();
        if (freeFunds == 0) return assets;
        return assets.mulDivUp(_totalSupply, freeFunds);
    }
    function withdraw(uint256 assets, address receiver, address owner) external nonReentrant returns (uint256 shares) {
        require(assets != 0, "please provide amount");
        shares = previewWithdraw(assets);
        _withdraw(assets, shares, receiver, owner);
        return shares;
    }
    function _withdraw(uint256 assets, uint256 shares, address receiver, address owner) internal returns (uint256) {
        _burn(owner, shares);
        if (assets > IERC20Metadata(asset).balanceOf(address(this))) {
            uint256 totalLoss = 0;
            uint256 queueLength = withdrawalQueue.length;
            uint256 vaultBalance = 0;
            for (uint256 i = 0; i < queueLength; i = _uncheckedInc(i)) {
                vaultBalance = IERC20Metadata(asset).balanceOf(address(this));
                if (assets <= vaultBalance) {
                    break;
                }
                address stratAddr = withdrawalQueue[i];
                uint256 strategyBal = strategies[stratAddr].allocated;
                if (strategyBal == 0) {
                    continue;
                }
                uint256 remaining = assets - vaultBalance;
                uint256 loss = IStrategy(stratAddr).withdraw(Math.min(remaining, strategyBal));
                uint256 actualWithdrawn = IERC20Metadata(asset).balanceOf(address(this)) - vaultBalance;
                if (loss != 0) {
                    assets -= loss;
                    totalLoss += loss;
                    _reportLoss(stratAddr, loss);
                }
                strategies[stratAddr].allocated -= actualWithdrawn;
                totalAllocated -= actualWithdrawn;
            }
            vaultBalance = IERC20Metadata(asset).balanceOf(address(this));
            if (assets > vaultBalance) {
                assets = vaultBalance;
            }
            require(totalLoss <= ((assets + totalLoss) * withdrawMaxLoss) / PERCENT_DIVISOR, "Cannot exceed the maximum allowed withdraw slippage");
        }
        IERC20Metadata(asset).safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return assets;
    }
    function maxRedeem(address owner) external view returns (uint256) {
        return balanceOf(owner);
    }
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }
    function getPricePerFullShare() external view returns (uint256) {
        return convertToAssets(10 ** decimals());
    }
    function redeemAll() external {
        redeem(balanceOf(msg.sender), msg.sender, msg.sender);
    }
    function redeem(uint256 shares, address receiver, address owner) public nonReentrant returns (uint256 assets) {
        require(shares != 0, "please provide amount");
        assets = previewRedeem(shares);
        return _withdraw(assets, shares, receiver, owner);
    }
    function addStrategy(address strategy, uint256 allocBPS) external {
        _atLeastRole(DEFAULT_ADMIN_ROLE);
        require(!emergencyShutdown, "Cannot add a strategy during emergency shutdown");
        require(strategy != address(0), "Cannot add the zero address");
        require(strategies[strategy].activation == 0, "Strategy must not be added already");
        require(address(this) == IStrategy(strategy).vault(), "The strategy must use this vault");
        require(asset == IStrategy(strategy).want(), "The strategy must use the same want");
        require(allocBPS + totalAllocBPS <= PERCENT_DIVISOR, "Total allocation points are over 100%");
        strategies[strategy] = StrategyParams({
            activation: block.timestamp,
            allocBPS: allocBPS,
            allocated: 0,
            gains: 0,
            losses: 0,
            lastReport: block.timestamp
        });
        totalAllocBPS += allocBPS;
        withdrawalQueue.push(strategy);
        emit StrategyAdded(strategy, allocBPS);
    }
    function updateStrategyAllocBPS(address strategy, uint256 allocBPS) external {
        _atLeastRole(STRATEGIST);
        require(strategies[strategy].activation != 0, "Strategy must be active");
        totalAllocBPS -= strategies[strategy].allocBPS;
        strategies[strategy].allocBPS = allocBPS;
        totalAllocBPS += allocBPS;
        require(totalAllocBPS <= PERCENT_DIVISOR, "Total allocation points are over 100%");
        emit StrategyAllocBPSUpdated(strategy, allocBPS);
    }
    function revokeStrategy(address strategy) external {
        if (!(msg.sender == strategy)) {
            _atLeastRole(GUARDIAN);
        }
        if (strategies[strategy].allocBPS == 0) {
            return;
        }
        totalAllocBPS -= strategies[strategy].allocBPS;
        strategies[strategy].allocBPS = 0;
        emit StrategyRevoked(strategy);
    }
    function availableCapital() public view returns (int256) {
        address stratAddr = msg.sender;
        if (totalAllocBPS == 0 || emergencyShutdown) {
            return -int256(strategies[stratAddr].allocated);
        }
        uint256 stratMaxAllocation = (strategies[stratAddr].allocBPS * totalAssets()) / PERCENT_DIVISOR;
        uint256 stratCurrentAllocation = strategies[stratAddr].allocated;
        if (stratCurrentAllocation > stratMaxAllocation) {
            return -int256(stratCurrentAllocation - stratMaxAllocation);
        } else if (stratCurrentAllocation < stratMaxAllocation) {
            uint256 vaultMaxAllocation = (totalAllocBPS * totalAssets()) / PERCENT_DIVISOR;
            uint256 vaultCurrentAllocation = totalAllocated;
            if (vaultCurrentAllocation >= vaultMaxAllocation) {
                return 0;
            }
            uint256 available = stratMaxAllocation - stratCurrentAllocation;
            available = Math.min(available, vaultMaxAllocation - vaultCurrentAllocation);
            available = Math.min(available, IERC20Metadata(asset).balanceOf(address(this)));
            return int256(available);
        } else {
            return 0;
        }
    }
    function setWithdrawalQueue(address[] calldata _withdrawalQueue) external {
        _atLeastRole(STRATEGIST);
        uint256 queueLength = _withdrawalQueue.length;
        require(queueLength != 0, "Cannot set an empty withdrawal queue");
        delete withdrawalQueue;
        for (uint256 i = 0; i < queueLength; i = _uncheckedInc(i)) {
            address strategy = _withdrawalQueue[i];
            StrategyParams storage params = strategies[strategy];
            require(params.activation != 0, "Can only use active strategies in the withdrawal queue");
            withdrawalQueue.push(strategy);
        }
        emit UpdateWithdrawalQueue(withdrawalQueue);
    }
    function _reportLoss(address strategy, uint256 loss) internal {
        StrategyParams storage stratParams = strategies[strategy];
        uint256 allocation = stratParams.allocated;
        require(loss <= allocation, "Strategy cannot loose more than what was allocated to it");
        if (totalAllocBPS != 0) {
            uint256 bpsChange = Math.min((loss * totalAllocBPS) / totalAllocated, stratParams.allocBPS);
            if (bpsChange != 0) {
                stratParams.allocBPS -= bpsChange;
                totalAllocBPS -= bpsChange;
            }
        }
        stratParams.losses += loss;
        stratParams.allocated -= loss;
        totalAllocated -= loss;
    }
    function report(int256 roi, uint256 repayment) external returns (uint256) {
        address stratAddr = msg.sender;
        StrategyParams storage strategy = strategies[stratAddr];
        require(strategy.activation != 0, "Only active strategies can report");
        uint256 loss = 0;
        uint256 gain = 0;
        if (roi < 0) {
            loss = uint256(-roi);
            _reportLoss(stratAddr, loss);
        } else {
            gain = uint256(roi);
            strategy.gains += uint256(roi);
        }
        int256 available = availableCapital();
        uint256 debt = 0;
        uint256 credit = 0;
        if (available < 0) {
            debt = uint256(-available);
            repayment = Math.min(debt, repayment);
            if (repayment != 0) {
                strategy.allocated -= repayment;
                totalAllocated -= repayment;
                debt -= repayment;
            }
        } else {
            credit = uint256(available);
            strategy.allocated += credit;
            totalAllocated += credit;
        }
        uint256 freeWantInStrat = repayment;
        if (roi > 0) {
            freeWantInStrat += uint256(roi);
        }
        if (credit > freeWantInStrat) {
            IERC20Metadata(asset).safeTransfer(stratAddr, credit - freeWantInStrat);
        } else if (credit < freeWantInStrat) {
            IERC20Metadata(asset).safeTransferFrom(stratAddr, address(this), freeWantInStrat - credit);
        }
        uint256 lockedProfitBeforeLoss = _calculateLockedProfit() + gain;
        if (lockedProfitBeforeLoss > loss) {
            lockedProfit = lockedProfitBeforeLoss - loss;
        } else {
            lockedProfit = 0;
        }
        strategy.lastReport = block.timestamp;
        lastReport = block.timestamp;
        emit StrategyReported(
            stratAddr,
            roi,
            repayment,
            strategy.gains,
            strategy.losses,
            strategy.allocated,
            strategy.allocBPS 
        );
        if (strategy.allocBPS == 0 || emergencyShutdown) {
            return IStrategy(stratAddr).balanceOf();
        }
        return debt;
    }
    function updateWithdrawMaxLoss(uint256 _withdrawMaxLoss) external {
        _atLeastRole(STRATEGIST);
        require(_withdrawMaxLoss <= PERCENT_DIVISOR, "withdrawMaxLoss cannot be greater than 100%");
        withdrawMaxLoss = _withdrawMaxLoss;
        emit WithdrawMaxLossUpdated(withdrawMaxLoss);
    }
    function updateTvlCap(uint256 newTvlCap) public {
        _atLeastRole(ADMIN);
        tvlCap = newTvlCap;
        emit TvlCapUpdated(tvlCap);
    }
    function removeTvlCap() external {
        _atLeastRole(ADMIN);
        updateTvlCap(type(uint256).max);
    }
    function setEmergencyShutdown(bool active) external {
        if (active == true) {
            _atLeastRole(GUARDIAN);
        } else {
            _atLeastRole(ADMIN);
        }
        emergencyShutdown = active;
        emit EmergencyShutdown(emergencyShutdown);
    }
    function inCaseTokensGetStuck(address token) external {
        _atLeastRole(STRATEGIST);
        require(token != asset, "!asset");
        uint256 amount = IERC20Metadata(token).balanceOf(address(this));
        IERC20Metadata(token).safeTransfer(msg.sender, amount);
        emit InCaseTokensGetStuckCalled(token, amount);
    }
    function decimals() public view override returns (uint8) {
        return IERC20Metadata(asset).decimals();
    }
    function setLockedProfitDegradation(uint256 degradation) external {
        _atLeastRole(STRATEGIST);
        require(degradation <= DEGRADATION_COEFFICIENT, "Degradation cannot be more than 100%");
        lockedProfitDegradation = degradation;
        emit LockedProfitDegradationUpdated(degradation);
    }
    function _atLeastRole(bytes32 role) internal view {
        uint256 numRoles = cascadingAccess.length;
        uint256 specifiedRoleIndex;
        for (uint256 i = 0; i < numRoles; i = _uncheckedInc(i)) {
            if (role == cascadingAccess[i]) {
                specifiedRoleIndex = i;
                break;
            } else if (i == numRoles - 1) {
                revert();
            }
        }
        for (uint256 i = 0; i <= specifiedRoleIndex; i = _uncheckedInc(i)) {
            if (hasRole(cascadingAccess[i], msg.sender)) {
                break;
            } else if (i == specifiedRoleIndex) {
                revert();
            }
        }
    }
    function _uncheckedInc(uint256 i) internal pure returns (uint256) {
        unchecked {
            return i + 1;
        }
    }
}