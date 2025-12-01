pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "@balancer-labs/v2-pool-utils/contracts/factories/BasePoolSplitCodeFactory.sol";
import "@balancer-labs/v2-pool-utils/contracts/factories/FactoryWidePauseWindow.sol";
import "./InvestmentPool.sol";
contract InvestmentPoolFactory is BasePoolSplitCodeFactory, FactoryWidePauseWindow {
    constructor(IVault vault) BasePoolSplitCodeFactory(vault, type(InvestmentPool).creationCode) {
    }
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256[] memory weights,
        uint256 swapFeePercentage,
        address owner,
        bool swapEnabledOnStart,
        uint256 managementSwapFeePercentage
    ) external returns (address) {
        (uint256 pauseWindowDuration, uint256 bufferPeriodDuration) = getPauseConfiguration();
        return
            _create(
                abi.encode(
                    InvestmentPool.NewPoolParams({
                        vault: getVault(),
                        name: name,
                        symbol: symbol,
                        tokens: tokens,
                        normalizedWeights: weights,
                        assetManagers: new address[](tokens.length),
                        swapFeePercentage: swapFeePercentage,
                        pauseWindowDuration: pauseWindowDuration,
                        bufferPeriodDuration: bufferPeriodDuration,
                        owner: owner,
                        swapEnabledOnStart: swapEnabledOnStart,
                        managementSwapFeePercentage: managementSwapFeePercentage
                    })
                )
            );
    }
}