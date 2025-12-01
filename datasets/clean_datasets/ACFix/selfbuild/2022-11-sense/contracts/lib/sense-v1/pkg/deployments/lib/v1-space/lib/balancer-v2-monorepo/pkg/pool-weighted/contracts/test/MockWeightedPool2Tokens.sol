pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "./MockWeightedOracleMath.sol";
import "../WeightedPool2Tokens.sol";
contract MockWeightedPool2Tokens is WeightedPool2Tokens, MockWeightedOracleMath {
    using WeightedPool2TokensMiscData for bytes32;
    struct MiscData {
        int256 logInvariant;
        int256 logTotalSupply;
        uint256 oracleSampleCreationTimestamp;
        uint256 oracleIndex;
        bool oracleEnabled;
        uint256 swapFeePercentage;
    }
    constructor(NewPoolParams memory params) WeightedPool2Tokens(params) {}
    function mockOracleDisabled() external {
        _setOracleEnabled(false);
    }
    function mockOracleIndex(uint256 index) external {
        _miscData = _miscData.setOracleIndex(index);
    }
    function mockMiscData(MiscData memory miscData) external {
        _miscData = encode(miscData);
    }
    function encode(MiscData memory _data) private pure returns (bytes32 data) {
        data = data.setSwapFeePercentage(_data.swapFeePercentage);
        data = data.setOracleEnabled(_data.oracleEnabled);
        data = data.setOracleIndex(_data.oracleIndex);
        data = data.setOracleSampleCreationTimestamp(_data.oracleSampleCreationTimestamp);
        data = data.setLogTotalSupply(_data.logTotalSupply);
        data = data.setLogInvariant(_data.logInvariant);
    }
}