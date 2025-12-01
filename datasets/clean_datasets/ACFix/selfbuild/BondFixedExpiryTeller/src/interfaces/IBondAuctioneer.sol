pragma solidity >=0.8.0;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IBondTeller} from "../interfaces/IBondTeller.sol";
import {IBondAggregator} from "../interfaces/IBondAggregator.sol";
interface IBondAuctioneer {
    function createMarket(bytes memory params_) external returns (uint256);
    function closeMarket(uint256 id_) external;
    function purchaseBond(
        uint256 id_,
        uint256 amount_,
        uint256 minAmountOut_
    ) external returns (uint256 payout);
    function setIntervals(uint256 id_, uint32[3] calldata intervals_) external;
    function pushOwnership(uint256 id_, address newOwner_) external;
    function pullOwnership(uint256 id_) external;
    function setDefaults(uint32[6] memory defaults_) external;
    function setAllowNewMarkets(bool status_) external;
    function setCallbackAuthStatus(address creator_, bool status_) external;
    function getMarketInfoForPurchase(uint256 id_)
        external
        view
        returns (
            address owner,
            address callbackAddr,
            ERC20 payoutToken,
            ERC20 quoteToken,
            uint48 vesting,
            uint256 maxPayout
        );
    function marketPrice(uint256 id_) external view returns (uint256);
    function marketScale(uint256 id_) external view returns (uint256);
    function payoutFor(
        uint256 amount_,
        uint256 id_,
        address referrer_
    ) external view returns (uint256);
    function maxAmountAccepted(uint256 id_, address referrer_) external view returns (uint256);
    function isInstantSwap(uint256 id_) external view returns (bool);
    function isLive(uint256 id_) external view returns (bool);
    function ownerOf(uint256 id_) external view returns (address);
    function getTeller() external view returns (IBondTeller);
    function getAggregator() external view returns (IBondAggregator);
    function currentCapacity(uint256 id_) external view returns (uint256);
}