pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-vault/contracts/AssetHelpers.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IAsset.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "@balancer-labs/v2-pool-utils/contracts/interfaces/IBasePoolRelayer.sol";
import "@balancer-labs/v2-solidity-utils/contracts/misc/IWETH.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/BalancerErrors.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/Address.sol";
import "./IAssetManager.sol";
contract RebalancingRelayer is IBasePoolRelayer, AssetHelpers {
    using Address for address payable;
    bytes32 internal constant _EMPTY_CALLED_POOL = bytes32(
        0x0000000000000000000000000000000000000000000000000000000000000001
    );
    modifier rebalance(
        bytes32 poolId,
        IAsset[] memory assets,
        uint256[] memory minCashBalances
    ) {
        _require(_calledPool == _EMPTY_CALLED_POOL, Errors.REBALANCING_RELAYER_REENTERED);
        IERC20[] memory tokens = _translateToIERC20(assets);
        _ensureCashBalance(poolId, tokens, minCashBalances);
        _calledPool = poolId;
        _;
        _calledPool = _EMPTY_CALLED_POOL;
        _rebalance(poolId, tokens);
    }
    IVault public immutable vault;
    bytes32 internal _calledPool;
    constructor(IVault _vault) AssetHelpers(_vault.WETH()) {
        vault = _vault;
        _calledPool = _EMPTY_CALLED_POOL;
    }
    function hasCalledPool(bytes32 poolId) external view override returns (bool) {
        return _calledPool == poolId;
    }
    receive() external payable {
        _require(msg.sender == address(vault), Errors.ETH_TRANSFER);
    }
    function joinPool(
        bytes32 poolId,
        address recipient,
        IVault.JoinPoolRequest memory request
    ) external payable rebalance(poolId, request.assets, new uint256[](request.assets.length)) {
        vault.joinPool{ value: msg.value }(poolId, msg.sender, recipient, request);
        if (address(this).balance > 0) {
            msg.sender.sendValue(address(this).balance);
        }
    }
    function exitPool(
        bytes32 poolId,
        address payable recipient,
        IVault.ExitPoolRequest memory request,
        uint256[] memory minCashBalances
    ) external rebalance(poolId, request.assets, minCashBalances) {
        vault.exitPool(poolId, msg.sender, recipient, request);
    }
    function _ensureCashBalance(
        bytes32 poolId,
        IERC20[] memory tokens,
        uint256[] memory minCashBalances
    ) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            (uint256 cash, , , address assetManager) = vault.getPoolTokenInfo(poolId, tokens[i]);
            if (assetManager != address(0)) {
                uint256 cashNeeded = minCashBalances[i];
                if (cash < cashNeeded) {
                    IAssetManager(assetManager).capitalOut(poolId, cashNeeded - cash);
                } else {
                    IAssetManager(assetManager).updateBalanceOfPool(poolId);
                }
            }
        }
    }
    function _rebalance(bytes32 poolId, IERC20[] memory tokens) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            (, , , address assetManager) = vault.getPoolTokenInfo(poolId, tokens[i]);
            if (assetManager != address(0)) {
                IAssetManager(assetManager).rebalance(poolId, false);
            }
        }
    }
}