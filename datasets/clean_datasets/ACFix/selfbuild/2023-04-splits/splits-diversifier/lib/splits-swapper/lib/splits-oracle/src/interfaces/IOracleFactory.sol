pragma solidity ^0.8.17;
import {OracleImpl} from "../OracleImpl.sol";
interface IOracleFactory {
    function createOracle(bytes calldata data_) external returns (OracleImpl oracle);
}