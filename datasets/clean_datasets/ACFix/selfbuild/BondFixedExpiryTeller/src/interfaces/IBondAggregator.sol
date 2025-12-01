pragma solidity >=0.8.0;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IBondAuctioneer} from "../interfaces/IBondAuctioneer.sol";
import {IBondTeller} from "../interfaces/IBondTeller.sol";
interface IBondAggregator {
    function registerAuctioneer(IBondAuctioneer auctioneer_) external;
    function registerMarket(ERC20 payoutToken_, ERC20 quoteToken_)
        external
        returns (uint256 marketId);
    function getAuctioneer(uint256 id_) external view returns (IBondAuctioneer);
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
    function liveMarketsBetween(uint256 firstIndex_, uint256 lastIndex_)
        external
        view
        returns (uint256[] memory);
    function liveMarketsFor(address token_, bool isPayout_)
        external
        view
        returns (uint256[] memory);
    function liveMarketsBy(address owner_) external view returns (uint256[] memory);
    function marketsFor(address payout_, address quote_) external view returns (uint256[] memory);
    function findMarketFor(
        address payout_,
        address quote_,
        uint256 amountIn_,
        uint256 minAmountOut_,
        uint256 maxExpiry_
    ) external view returns (uint256 id);
    function getTeller(uint256 id_) external view returns (IBondTeller);
    function currentCapacity(uint256 id_) external view returns (uint256);
}