pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/misc/IWETH.sol";
import "./interfaces/IAuthorizer.sol";
import "./VaultAuthorization.sol";
import "./FlashLoans.sol";
import "./Swaps.sol";
contract Vault is VaultAuthorization, FlashLoans, Swaps {
    constructor(
        IAuthorizer authorizer,
        IWETH weth,
        uint256 pauseWindowDuration,
        uint256 bufferPeriodDuration
    ) VaultAuthorization(authorizer) AssetHelpers(weth) TemporarilyPausable(pauseWindowDuration, bufferPeriodDuration) {
    }
    function setPaused(bool paused) external override nonReentrant authenticate {
        _setPaused(paused);
    }
    function WETH() external view override returns (IWETH) {
        return _WETH();
    }
}