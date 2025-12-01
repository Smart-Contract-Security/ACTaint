pragma solidity 0.8.13;
import "./RewardsLens.sol";
contract Lens is RewardsLens {
    using CompoundMath for uint256;
    function initialize(address _morphoAddress) external initializer {
        morpho = IMorpho(_morphoAddress);
        comptroller = IComptroller(morpho.comptroller());
        rewardsManager = IRewardsManager(morpho.rewardsManager());
    }
    function getTotalSupply()
        external
        view
        returns (
            uint256 p2pSupplyAmount,
            uint256 poolSupplyAmount,
            uint256 totalSupplyAmount
        )
    {
        address[] memory markets = morpho.getAllMarkets();
        ICompoundOracle oracle = ICompoundOracle(comptroller.oracle());
        uint256 nbMarkets = markets.length;
        for (uint256 i; i < nbMarkets; ) {
            address _poolToken = markets[i];
            (uint256 marketP2PSupplyAmount, uint256 marketPoolSupplyAmount) = getTotalMarketSupply(
                _poolToken
            );
            uint256 underlyingPrice = oracle.getUnderlyingPrice(_poolToken);
            if (underlyingPrice == 0) revert CompoundOracleFailed();
            p2pSupplyAmount += marketP2PSupplyAmount.mul(underlyingPrice);
            poolSupplyAmount += marketPoolSupplyAmount.mul(underlyingPrice);
            unchecked {
                ++i;
            }
        }
        totalSupplyAmount = p2pSupplyAmount + poolSupplyAmount;
    }
    function getTotalBorrow()
        external
        view
        returns (
            uint256 p2pBorrowAmount,
            uint256 poolBorrowAmount,
            uint256 totalBorrowAmount
        )
    {
        address[] memory markets = morpho.getAllMarkets();
        ICompoundOracle oracle = ICompoundOracle(comptroller.oracle());
        uint256 nbMarkets = markets.length;
        for (uint256 i; i < nbMarkets; ) {
            address _poolToken = markets[i];
            (uint256 marketP2PBorrowAmount, uint256 marketPoolBorrowAmount) = getTotalMarketBorrow(
                _poolToken
            );
            uint256 underlyingPrice = oracle.getUnderlyingPrice(_poolToken);
            if (underlyingPrice == 0) revert CompoundOracleFailed();
            p2pBorrowAmount += marketP2PBorrowAmount.mul(underlyingPrice);
            poolBorrowAmount += marketPoolBorrowAmount.mul(underlyingPrice);
            unchecked {
                ++i;
            }
        }
        totalBorrowAmount = p2pBorrowAmount + poolBorrowAmount;
    }
}