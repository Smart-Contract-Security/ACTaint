pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "@balancer-labs/v2-pool-utils/contracts/factories/BasePoolSplitCodeFactory.sol";
import "@balancer-labs/v2-pool-utils/contracts/factories/FactoryWidePauseWindow.sol";
import "./MetaStablePool.sol";
contract MetaStablePoolFactory is BasePoolSplitCodeFactory, FactoryWidePauseWindow {
    constructor(IVault vault) BasePoolSplitCodeFactory(vault, type(MetaStablePool).creationCode) {
    }
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256 amplificationParameter,
        IRateProvider[] memory rateProviders,
        uint256[] memory priceRateCacheDuration,
        uint256 swapFeePercentage,
        bool oracleEnabled,
        address owner
    ) external returns (address) {
        (uint256 pauseWindowDuration, uint256 bufferPeriodDuration) = getPauseConfiguration();
        return
            _create(
                abi.encode(
                    MetaStablePool.NewPoolParams({
                        vault: getVault(),
                        name: name,
                        symbol: symbol,
                        tokens: tokens,
                        rateProviders: rateProviders,
                        priceRateCacheDuration: priceRateCacheDuration,
                        amplificationParameter: amplificationParameter,
                        swapFeePercentage: swapFeePercentage,
                        pauseWindowDuration: pauseWindowDuration,
                        bufferPeriodDuration: bufferPeriodDuration,
                        oracleEnabled: oracleEnabled,
                        owner: owner
                    })
                )
            );
    }
}