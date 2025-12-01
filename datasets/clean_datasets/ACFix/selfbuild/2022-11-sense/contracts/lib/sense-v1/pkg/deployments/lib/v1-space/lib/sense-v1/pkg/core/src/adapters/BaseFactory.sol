pragma solidity 0.8.11;
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { BaseAdapter } from "./BaseAdapter.sol";
import { Divider } from "../Divider.sol";
abstract contract BaseFactory {
    uint48 public constant DEFAULT_LEVEL = 31;
    address public immutable divider;
    mapping(address => address) public adapters;
    FactoryParams public factoryParams;
    struct FactoryParams {
        address oracle; 
        address stake; 
        uint256 stakeSize; 
        uint256 minm; 
        uint256 maxm; 
        uint128 ifee; 
        uint16 mode; 
        uint64 tilt; 
    }
    constructor(address _divider, FactoryParams memory _factoryParams) {
        divider = _divider;
        factoryParams = _factoryParams;
    }
    function deployAdapter(address _target, bytes memory _data) external virtual returns (address adapter) {}
    event AdapterAdded(address addr, address indexed target);
}