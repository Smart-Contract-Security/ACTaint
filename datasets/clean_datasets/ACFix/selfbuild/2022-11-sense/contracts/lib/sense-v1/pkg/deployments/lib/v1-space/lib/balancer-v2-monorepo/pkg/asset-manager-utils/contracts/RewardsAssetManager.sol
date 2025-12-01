import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "@balancer-labs/v2-pool-utils/contracts/interfaces/IRelayedBasePool.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/Math.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "./IAssetManager.sol";
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
abstract contract RewardsAssetManager is IAssetManager {
    using Math for uint256;
    IVault private immutable _vault;
    IERC20 private immutable _token;
    bytes32 private _poolId;
    struct InvestmentConfig {
        uint64 targetPercentage;
        uint64 upperCriticalPercentage;
        uint64 lowerCriticalPercentage;
    }
    InvestmentConfig private _config;
    event InvestmentConfigSet(uint64 targetPercentage, uint64 lowerCriticalPercentage, uint64 upperCriticalPercentage);
    constructor(
        IVault vault,
        bytes32 poolId,
        IERC20 token
    ) {
        token.approve(address(vault), type(uint256).max);
        _vault = vault;
        _poolId = poolId;
        _token = token;
    }
    modifier onlyPoolContract() {
        require(msg.sender == getPoolAddress(), "Only callable by pool");
        _;
    }
    modifier onlyPoolRebalancer() {
        require(
            msg.sender == address(IRelayedBasePool(getPoolAddress()).getRelayer()),
            "Only callable by authorized rebalancer"
        );
        _;
    }
    modifier withCorrectPool(bytes32 pId) {
        require(pId == _poolId, "SinglePoolAssetManager called with incorrect poolId");
        _;
    }
    function _initialize(bytes32 pId) internal {
        require(!isInitialized(), "Already initialised");
        require(pId != bytes32(0), "Pool id cannot be empty");
        _poolId = pId;
    }
    function getVault() public view returns (IVault) {
        return _vault;
    }
    function getPoolId() public view returns (bytes32) {
        return _poolId;
    }
    function getPoolAddress() public view returns (address) {
        return address(uint256(_poolId) >> (12 * 8));
    }
    function isInitialized() public view returns (bool) {
        return getPoolId() != bytes32(0);
    }
    function getToken() public view override returns (IERC20) {
        return _token;
    }
    function maxInvestableBalance(bytes32 pId) public view override withCorrectPool(pId) returns (int256) {
        return _maxInvestableBalance(_getAUM());
    }
    function _maxInvestableBalance(uint256 aum) internal view returns (int256) {
        (uint256 poolCash, , , ) = getVault().getPoolTokenInfo(_poolId, getToken());
        return int256(FixedPoint.mulDown(poolCash.add(aum), _config.targetPercentage)) - int256(aum);
    }
    function updateBalanceOfPool(bytes32 pId) public override withCorrectPool(pId) {
        uint256 managedBalance = _getAUM();
        IVault.PoolBalanceOp memory transfer = IVault.PoolBalanceOp(
            IVault.PoolBalanceOpKind.UPDATE,
            pId,
            getToken(),
            managedBalance
        );
        IVault.PoolBalanceOp[] memory ops = new IVault.PoolBalanceOp[](1);
        ops[0] = (transfer);
        getVault().managePoolBalance(ops);
    }
    function _capitalIn(uint256 amount) private {
        uint256 aum = _getAUM();
        IVault.PoolBalanceOp[] memory ops = new IVault.PoolBalanceOp[](2);
        ops[0] = IVault.PoolBalanceOp(IVault.PoolBalanceOpKind.UPDATE, _poolId, getToken(), aum);
        ops[1] = IVault.PoolBalanceOp(IVault.PoolBalanceOpKind.WITHDRAW, _poolId, getToken(), amount);
        getVault().managePoolBalance(ops);
        _invest(amount, aum);
    }
    function _capitalOut(uint256 amount) private {
        uint256 aum = _getAUM();
        uint256 tokensOut = _divest(amount, aum);
        IVault.PoolBalanceOp[] memory ops = new IVault.PoolBalanceOp[](2);
        ops[0] = IVault.PoolBalanceOp(IVault.PoolBalanceOpKind.UPDATE, _poolId, getToken(), aum);
        ops[1] = IVault.PoolBalanceOp(IVault.PoolBalanceOpKind.DEPOSIT, _poolId, getToken(), tokensOut);
        getVault().managePoolBalance(ops);
    }
    function _invest(uint256 amount, uint256 aum) internal virtual returns (uint256);
    function _divest(uint256 amount, uint256 aum) internal virtual returns (uint256);
    function getAUM(bytes32 pId) public view virtual override withCorrectPool(pId) returns (uint256) {
        return _getAUM();
    }
    function _getAUM() internal view virtual returns (uint256);
    function setConfig(bytes32 pId, bytes memory rawConfig) external override withCorrectPool(pId) onlyPoolContract {
        InvestmentConfig memory config = abi.decode(rawConfig, (InvestmentConfig));
        require(
            config.upperCriticalPercentage <= FixedPoint.ONE,
            "Upper critical level must be less than or equal to 100%"
        );
        require(
            config.targetPercentage <= config.upperCriticalPercentage,
            "Target must be less than or equal to upper critical level"
        );
        require(
            config.lowerCriticalPercentage <= config.targetPercentage,
            "Lower critical level must be less than or equal to target"
        );
        _config = config;
        emit InvestmentConfigSet(
            config.targetPercentage,
            config.lowerCriticalPercentage,
            config.upperCriticalPercentage
        );
    }
    function getInvestmentConfig(bytes32 pId) external view withCorrectPool(pId) returns (InvestmentConfig memory) {
        return _config;
    }
    function getPoolBalances(bytes32 pId)
        public
        view
        override
        withCorrectPool(pId)
        returns (uint256 poolCash, uint256 poolManaged)
    {
        (poolCash, poolManaged) = _getPoolBalances(_getAUM());
    }
    function _getPoolBalances(uint256 aum) internal view returns (uint256 poolCash, uint256 poolManaged) {
        (poolCash, , , ) = getVault().getPoolTokenInfo(_poolId, getToken());
        poolManaged = aum;
    }
    function shouldRebalance(uint256 cash, uint256 managed) public view override returns (bool) {
        uint256 investedPercentage = cash.mul(FixedPoint.ONE).divDown(cash.add(managed));
        InvestmentConfig memory config = _config;
        return
            investedPercentage > config.upperCriticalPercentage || investedPercentage < config.lowerCriticalPercentage;
    }
    function _rebalance(
        bytes32 
    ) internal {
        uint256 aum = _getAUM();
        (uint256 poolCash, uint256 poolManaged) = _getPoolBalances(aum);
        InvestmentConfig memory config = _config;
        uint256 targetInvestment = FixedPoint.mulDown(poolCash + poolManaged, config.targetPercentage);
        if (targetInvestment > poolManaged) {
            uint256 rebalanceAmount = targetInvestment - poolManaged;
            _capitalIn(rebalanceAmount);
        } else {
            uint256 rebalanceAmount = poolManaged - targetInvestment;
            _capitalOut(rebalanceAmount);
        }
        emit Rebalance(_poolId);
    }
    function rebalance(bytes32 pId, bool force) external override withCorrectPool(pId) {
        if (force) {
            _rebalance(pId);
        } else {
            (uint256 poolCash, uint256 poolManaged) = _getPoolBalances(_getAUM());
            if (shouldRebalance(poolCash, poolManaged)) {
                _rebalance(pId);
            }
        }
    }
    function capitalOut(bytes32 pId, uint256 amount) external override withCorrectPool(pId) onlyPoolRebalancer {
        _capitalOut(amount);
    }
}