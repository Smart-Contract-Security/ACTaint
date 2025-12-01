pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "@balancer-labs/v2-pool-utils/contracts/factories/BasePoolSplitCodeFactory.sol";
import "@balancer-labs/v2-pool-utils/contracts/factories/FactoryWidePauseWindow.sol";
import "./WeightedPool2Tokens.sol";
contract WeightedPool2TokensFactory is BasePoolSplitCodeFactory, FactoryWidePauseWindow {
    constructor(IVault vault) BasePoolSplitCodeFactory(vault, type(WeightedPool2Tokens).creationCode) {
    }
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256[] memory weights,
        uint256 swapFeePercentage,
        bool oracleEnabled,
        address owner
    ) external returns (address) {
        (uint256 pauseWindowDuration, uint256 bufferPeriodDuration) = getPauseConfiguration();
        WeightedPool2Tokens.NewPoolParams memory params = WeightedPool2Tokens.NewPoolParams({
            vault: getVault(),
            name: name,
            symbol: symbol,
            token0: tokens[0],
            token1: tokens[1],
            normalizedWeight0: weights[0],
            normalizedWeight1: weights[1],
            swapFeePercentage: swapFeePercentage,
            pauseWindowDuration: pauseWindowDuration,
            bufferPeriodDuration: bufferPeriodDuration,
            oracleEnabled: oracleEnabled,
            owner: owner
        });
        return _create(abi.encode(params));
    }
}