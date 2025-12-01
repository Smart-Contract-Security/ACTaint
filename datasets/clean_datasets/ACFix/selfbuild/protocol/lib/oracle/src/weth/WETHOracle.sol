pragma solidity ^0.8.17;
import {IOracle} from "../core/IOracle.sol";
contract WETHOracle is IOracle {
    function getPrice(address) external pure returns (uint) { return 1e18; }
}