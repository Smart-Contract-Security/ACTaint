pragma solidity 0.8.13;
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { IPriceFeed } from "../../abstract/IPriceFeed.sol";
contract MasterPriceOracle is IPriceFeed, Trust {
    address public senseChainlinkPriceOracle;
    mapping(address => address) public oracles;
    constructor(
        address _chainlinkOracle,
        address[] memory _underlyings,
        address[] memory _oracles
    ) public Trust(msg.sender) {
        senseChainlinkPriceOracle = _chainlinkOracle;
        if (_underlyings.length != _oracles.length) revert Errors.InvalidParam();
        for (uint256 i = 0; i < _underlyings.length; i++) oracles[_underlyings[i]] = _oracles[i];
    }
    function add(address[] calldata _underlyings, address[] calldata _oracles) external requiresTrust {
        if (_underlyings.length <= 0 || _underlyings.length != _oracles.length) revert Errors.InvalidParam();
        for (uint256 i = 0; i < _underlyings.length; i++) {
            oracles[_underlyings[i]] = _oracles[i];
        }
    }
    function price(address underlying) external view override returns (uint256) {
        if (underlying == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) return 1e18; 
        address oracle = oracles[underlying];
        if (oracle != address(0)) {
            return IPriceFeed(oracle).price(underlying);
        } else {
            try IPriceFeed(senseChainlinkPriceOracle).price(underlying) returns (uint256 price) {
                return price;
            } catch {
                revert Errors.PriceOracleNotFound();
            }
        }
    }
    function setSenseChainlinkPriceOracle(address _senseChainlinkPriceOracle) public requiresTrust {
        senseChainlinkPriceOracle = _senseChainlinkPriceOracle;
        emit SenseChainlinkPriceOracleChanged(senseChainlinkPriceOracle);
    }
    event SenseChainlinkPriceOracleChanged(address indexed senseChainlinkPriceOracle);
}