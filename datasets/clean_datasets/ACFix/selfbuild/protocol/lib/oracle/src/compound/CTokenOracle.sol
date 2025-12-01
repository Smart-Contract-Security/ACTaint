pragma solidity ^0.8.17;
import {ICToken} from "./ICToken.sol";
import {IERC20} from "../utils/IERC20.sol";
import {IOracle} from "../core/IOracle.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
contract CTokenOracle is IOracle {
    using FixedPointMathLib for uint;
    IOracle public immutable oracle;
    address public immutable cETHER;
    constructor(IOracle _oracle, address _cETHER) {
        oracle = _oracle;
        cETHER = _cETHER;
    }
    function getPrice(address token) external view returns (uint) {
        return (token == cETHER) ?
            getCEtherPrice() :
            getCErc20Price(ICToken(token), ICToken(token).underlying());
    }
    function getCEtherPrice() internal view returns (uint) {
        return ICToken(cETHER).exchangeRateStored().mulWadDown(1e8);
    }
    function getCErc20Price(ICToken cToken, address underlying) internal view returns (uint) {
        return cToken.exchangeRateStored()
        .mulDivDown(1e8 , 10 ** IERC20(underlying).decimals())
        .mulWadDown(oracle.getPrice(underlying));
    }
}