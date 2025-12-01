pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "../BasePool.sol";
contract MockBasePool is BasePool {
    uint256 private immutable _totalTokens;
    constructor(
        IVault vault,
        IVault.PoolSpecialization specialization,
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        address[] memory assetManagers,
        uint256 swapFeePercentage,
        uint256 pauseWindowDuration,
        uint256 bufferPeriodDuration,
        address owner
    )
        BasePool(
            vault,
            specialization,
            name,
            symbol,
            tokens,
            assetManagers,
            swapFeePercentage,
            pauseWindowDuration,
            bufferPeriodDuration,
            owner
        )
    {
        _totalTokens = tokens.length;
    }
    function setMiscData(bytes32 data) external {
        _setMiscData(data);
    }
    function getMiscData() external view returns (bytes32) {
        return _getMiscData();
    }
    function _onInitializePool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal override returns (uint256, uint256[] memory) {}
    function _onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory currentBalances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        uint256[] memory scalingFactors,
        bytes memory userData
    )
        internal
        override
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {}
    function _onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory currentBalances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        uint256[] memory scalingFactors,
        bytes memory userData
    )
        internal
        override
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {}
    function _getMaxTokens() internal pure override returns (uint256) {
        return 8;
    }
    function _getTotalTokens() internal view override returns (uint256) {
        return _totalTokens;
    }
    function _scalingFactor(IERC20) internal pure override returns (uint256) {
        return FixedPoint.ONE;
    }
    function _scalingFactors() internal view override returns (uint256[] memory scalingFactors) {
        uint256 numTokens = _getTotalTokens();
        scalingFactors = new uint256[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            scalingFactors[i] = FixedPoint.ONE;
        }
    }    
}