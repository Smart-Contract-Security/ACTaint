pragma solidity ^0.8.17;
import {Errors} from "../utils/Errors.sol";
import {IOracle} from "../core/IOracle.sol";
import {Ownable} from "../utils/Ownable.sol";
import {OracleLibrary} from "./library/OracleLibrary.sol";
import {IERC20} from "../utils/IERC20.sol";
contract UniV3TWAPOracle is Ownable, IOracle {
    uint32 public twapPeriod = 1800;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    mapping(address => address) poolFor;
    constructor() Ownable(msg.sender) {}
    function getPrice(address token) public view returns (uint256) {
        address pool;
        if ((pool = poolFor[token]) == address(0)) {
            revert Errors.PriceUnavailable();
        }
        (int24 arithmeticMeanTick, ) = OracleLibrary.consult(
            pool,
            twapPeriod
        );
        return OracleLibrary.getQuoteAtTick(
            arithmeticMeanTick,
            uint128(10) ** IERC20(token).decimals(),
            token,
            WETH
        );
    }
    function updateTwapPeriod(uint32 _twapPeriod) external adminOnly {
        twapPeriod = _twapPeriod;
    }
    function setPool(address token, address pool) external adminOnly {
        poolFor[token] = pool;
    }
}