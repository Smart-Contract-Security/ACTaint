pragma experimental ABIEncoderV2;
import "../RewardsAssetManager.sol";
pragma solidity ^0.7.0;
contract MockRewardsAssetManager is RewardsAssetManager {
    using Math for uint256;
    constructor(
        IVault vault,
        bytes32 poolId,
        IERC20 token
    ) RewardsAssetManager(vault, poolId, token) {
    }
    function initialize(bytes32 pId) public {
        _initialize(pId);
    }
    function _invest(uint256 amount, uint256) internal pure override returns (uint256) {
        return amount;
    }
    function _divest(uint256 amount, uint256) internal pure override returns (uint256) {
        return amount;
    }
    function _getAUM() internal view override returns (uint256) {
        return getToken().balanceOf(address(this));
    }
}