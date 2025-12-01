pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "@balancer-labs/v2-pool-utils/contracts/factories/BasePoolSplitCodeFactory.sol";
import "@balancer-labs/v2-pool-utils/contracts/factories/FactoryWidePauseWindow.sol";
import "./LiquidityBootstrappingPool.sol";
contract LiquidityBootstrappingPoolFactory is BasePoolSplitCodeFactory, FactoryWidePauseWindow {
    constructor(IVault vault) BasePoolSplitCodeFactory(vault, type(LiquidityBootstrappingPool).creationCode) {
    }
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256[] memory weights,
        uint256 swapFeePercentage,
        address owner,
        bool swapEnabledOnStart
    ) external returns (address) {
        (uint256 pauseWindowDuration, uint256 bufferPeriodDuration) = getPauseConfiguration();
        return
            _create(
                abi.encode(
                    getVault(),
                    name,
                    symbol,
                    tokens,
                    weights,
                    swapFeePercentage,
                    pauseWindowDuration,
                    bufferPeriodDuration,
                    owner,
                    swapEnabledOnStart
                )
            );
    }
}