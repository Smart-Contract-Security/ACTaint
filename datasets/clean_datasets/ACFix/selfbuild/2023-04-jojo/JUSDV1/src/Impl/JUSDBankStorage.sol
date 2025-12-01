pragma solidity 0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";
import {DataTypes} from "../lib/DataTypes.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/FlashLoanReentrancyGuard.sol";
import "../lib/JOJOConstant.sol";
abstract contract JUSDBankStorage is
    Ownable,
    ReentrancyGuard,
    FlashLoanReentrancyGuard
{
    mapping(address => DataTypes.ReserveInfo) public reserveInfo;
    mapping(address => DataTypes.UserInfo) public userInfo;
    mapping(address => mapping(address => bool)) public operatorRegistry;
    uint256 public reservesNum;
    uint256 public maxReservesNum;
    uint256 public maxPerAccountBorrowAmount;
    uint256 public maxTotalBorrowAmount;
    uint256 public t0TotalBorrowAmount;
    uint256 public borrowFeeRate;
    uint256 public t0Rate;
    uint32 public lastUpdateTimestamp;
    address[] public reservesList;
    address public insurance;
    address public JUSD;
    address public primaryAsset;
    address public JOJODealer;
    bool public isLiquidatorWhitelistOpen;
    mapping(address => bool) isLiquidatorWhiteList;
    function getTRate() public view returns (uint256) {
        uint256 timeDifference = block.timestamp - uint256(lastUpdateTimestamp);
        return
            t0Rate +
            (borrowFeeRate * timeDifference) /
            JOJOConstant.SECONDS_PER_YEAR;
    }
}