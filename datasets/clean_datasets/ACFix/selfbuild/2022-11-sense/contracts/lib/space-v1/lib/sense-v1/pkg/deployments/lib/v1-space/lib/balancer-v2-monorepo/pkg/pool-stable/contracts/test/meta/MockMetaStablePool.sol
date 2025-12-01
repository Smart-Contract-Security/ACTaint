pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "./MockStableOracleMath.sol";
import "../../meta/MetaStablePool.sol";
import "../../meta/OracleMiscData.sol";
contract MockMetaStablePool is MetaStablePool, MockStableOracleMath {
    using OracleMiscData for bytes32;
    struct MiscData {
        int256 logInvariant;
        int256 logTotalSupply;
        uint256 oracleSampleCreationTimestamp;
        uint256 oracleIndex;
        bool oracleEnabled;
    }
    constructor(NewPoolParams memory params) MetaStablePool(params) {
    }
    function getScalingFactor(IERC20 token) external view returns (uint256) {
        return _scalingFactor(token);
    }
    function mockCachePriceRatesIfNecessary() external {
        _cachePriceRatesIfNecessary();
    }
    function mockOracleDisabled() external {
        _setOracleEnabled(false);
    }
    function mockOracleIndex(uint256 index) external {
        _setMiscData(_getMiscData().setOracleIndex(index));
    }
    function mockMiscData(MiscData memory miscData) external {
        _setMiscData(encode(miscData));
    }
    function encode(MiscData memory _data) private pure returns (bytes32 data) {
        data = data.setOracleEnabled(_data.oracleEnabled);
        data = data.setOracleIndex(_data.oracleIndex);
        data = data.setOracleSampleCreationTimestamp(_data.oracleSampleCreationTimestamp);
        data = data.setLogTotalSupply(_data.logTotalSupply);
        data = data.setLogInvariant(_data.logInvariant);
    }
}