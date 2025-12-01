pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20Permit.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/Authentication.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IAuthorizer.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IBasePool.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
abstract contract MultiRewardsAuthorization is Authentication {
    IVault private immutable _vault;
    mapping(IERC20 => mapping(IERC20 => mapping(address => bool))) private _allowlist;
    constructor(IVault vault) {
        _vault = vault;
    }
    modifier onlyAllowlistedRewarder(IERC20 pool, IERC20 rewardsToken) {
        require(_isAllowlistedRewarder(pool, rewardsToken, msg.sender), "Only accessible by allowlisted rewarders");
        _;
    }
    modifier onlyAllowlisters(IERC20 pool) {
        require(
            _canPerform(getActionId(msg.sig), msg.sender) ||
                msg.sender == address(pool) ||
                isAssetManager(pool, msg.sender),
            "Only accessible by governance, pool or it's asset managers"
        );
        _;
    }
    function getVault() public view returns (IVault) {
        return _vault;
    }
    function getAuthorizer() external view returns (IAuthorizer) {
        return _getAuthorizer();
    }
    function _getAuthorizer() internal view returns (IAuthorizer) {
        return getVault().getAuthorizer();
    }
    function _allowlistRewarder(
        IERC20 pool,
        IERC20 rewardsToken,
        address rewarder
    ) internal {
        _allowlist[pool][rewardsToken][rewarder] = true;
    }
    function _isAllowlistedRewarder(
        IERC20 pool,
        IERC20 rewardsToken,
        address rewarder
    ) internal view returns (bool) {
        return _allowlist[pool][rewardsToken][rewarder];
    }
    function isAssetManager(IERC20 pool, address rewarder) public view returns (bool) {
        IBasePool poolContract = IBasePool(address(pool));
        bytes32 poolId = poolContract.getPoolId();
        (IERC20[] memory poolTokens, , ) = getVault().getPoolTokens(poolId);
        for (uint256 pt; pt < poolTokens.length; pt++) {
            (, , , address assetManager) = getVault().getPoolTokenInfo(poolId, poolTokens[pt]);
            if (assetManager == rewarder) {
                return true;
            }
        }
        return false;
    }
    function _canPerform(bytes32 actionId, address account) internal view override returns (bool) {
        return _getAuthorizer().canPerform(actionId, account, address(this));
    }
}