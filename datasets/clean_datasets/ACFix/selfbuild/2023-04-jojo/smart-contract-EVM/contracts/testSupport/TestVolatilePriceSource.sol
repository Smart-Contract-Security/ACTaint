import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
pragma solidity 0.8.9;
contract TestVolatilePriceSource is Ownable {
    uint256 public price;
    uint256 public updatedAt;
    uint256 public roundId;
    event AnswerUpdated(
        int256 indexed current,
        uint256 indexed roundId,
        uint256 updatedAt
    );
    function getMarkPrice() external view returns (uint256) {
        uint256 offset = (price * (block.number % 10) * 3e16) / 1e18;
        return (block.timestamp % 2 == 0) ? price - offset : price + offset;
    }
    function setMarkPrice(uint256 newPrice) external onlyOwner {
        price = newPrice;
        roundId++;
        updatedAt = block.timestamp;
        emit AnswerUpdated(SafeCast.toInt256(price), roundId, updatedAt);
    }
}