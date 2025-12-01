pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "../LinearMath.sol";
contract MockLinearMath is LinearMath {
    function calcBptOutPerMainIn(uint256 mainIn, uint256 mainBalance, uint256 wrappedBalance, uint256 bptSupply, Params memory params) external pure returns (uint256) {
        return _calcBptOutPerMainIn(mainIn, mainBalance, wrappedBalance, bptSupply, params);
    }
    function calcBptInPerMainOut(uint256 mainOut, uint256 mainBalance, uint256 wrappedBalance, uint256 bptSupply, Params memory params) external pure returns (uint256) {
        return _calcBptInPerMainOut(mainOut, mainBalance, wrappedBalance, bptSupply, params);
    }
    function calcWrappedOutPerMainIn(uint256 mainIn, uint256 mainBalance, uint256 wrappedBalance, Params memory params) external pure returns (uint256) {
        return _calcWrappedOutPerMainIn(mainIn, mainBalance, wrappedBalance, params);
    }
    function calcWrappedInPerMainOut(uint256 mainOut, uint256 mainBalance, uint256 wrappedBalance, Params memory params) external pure returns (uint256) {
        return _calcWrappedInPerMainOut(mainOut, mainBalance, wrappedBalance, params);
    }
    function calcMainInPerBptOut(uint256 bptOut, uint256 mainBalance, uint256 wrappedBalance, uint256 bptSupply, Params memory params) external pure returns (uint256) {
        return _calcMainInPerBptOut(bptOut, mainBalance, wrappedBalance, bptSupply, params);
    }
    function calcMainOutPerBptIn(uint256 bptIn, uint256 mainBalance, uint256 wrappedBalance, uint256 bptSupply, Params memory params) external pure returns (uint256) {
        return _calcMainOutPerBptIn(bptIn, mainBalance, wrappedBalance, bptSupply, params);
    }
    function calcMainInPerWrappedOut(uint256 wrappedOut, uint256 mainBalance, Params memory params) external pure returns (uint256) {
        return _calcMainInPerWrappedOut(wrappedOut, mainBalance, params);
    }
    function calcMainOutPerWrappedIn(uint256 wrappedIn, uint256 mainBalance, Params memory params) external pure returns (uint256) {
        return _calcMainOutPerWrappedIn(wrappedIn, mainBalance, params);
    }
}