pragma solidity ^0.5.16;
import "./RToken.sol";
contract PriceOracle {
    bool public constant isPriceOracle = true;
    function getUnderlyingPrice(RToken rToken) external view returns (uint);
}