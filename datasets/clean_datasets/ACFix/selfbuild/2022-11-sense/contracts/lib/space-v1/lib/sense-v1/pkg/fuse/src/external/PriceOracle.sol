pragma solidity 0.8.11;
import { CToken } from "./CToken.sol";
abstract contract PriceOracle {
    bool public constant isPriceOracle = true;
    function getUnderlyingPrice(CToken cToken) external view virtual returns (uint256);
    function price(address underlying) external view virtual returns (uint256);
}