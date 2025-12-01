pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "@balancer-labs/v2-pool-utils/contracts/factories/BasePoolFactory.sol";
import "@balancer-labs/v2-pool-utils/contracts/factories/FactoryWidePauseWindow.sol";
import "./LinearPool.sol";
contract LinearPoolFactory is BasePoolFactory, FactoryWidePauseWindow {
    constructor(IVault vault) BasePoolFactory(vault) {
    }
    function create(
        string memory name,
        string memory symbol,
        IERC20 mainToken,
        IERC20 wrappedToken,
        uint256 lowerTarget,
        uint256 upperTarget,
        uint256 swapFeePercentage,
        IRateProvider wrappedTokenRateProvider,
        uint256 wrappedTokenRateCacheDuration,
        address owner
    ) external returns (LinearPool) {
        (uint256 pauseWindowDuration, uint256 bufferPeriodDuration) = getPauseConfiguration();
        LinearPool pool = new LinearPool(
            LinearPool.NewPoolParams({
                vault: getVault(),
                name: name,
                symbol: symbol,
                mainToken: mainToken,
                wrappedToken: wrappedToken,
                lowerTarget: lowerTarget,
                upperTarget: upperTarget,
                swapFeePercentage: swapFeePercentage,
                pauseWindowDuration: pauseWindowDuration,
                bufferPeriodDuration: bufferPeriodDuration,
                wrappedTokenRateProvider: wrappedTokenRateProvider,
                wrappedTokenRateCacheDuration: wrappedTokenRateCacheDuration,
                owner: owner
            })
        );
        _register(address(pool));
        pool.initialize();
        return pool;
    }
}