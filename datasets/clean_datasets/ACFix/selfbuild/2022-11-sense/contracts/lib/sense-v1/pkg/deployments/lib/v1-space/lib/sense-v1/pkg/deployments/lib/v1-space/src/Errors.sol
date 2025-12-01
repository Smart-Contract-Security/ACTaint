pragma solidity >=0.7.0;
function _require(bool condition, uint256 errorCode) pure {
    if (!condition) _revert(errorCode);
}
function _revert(uint256 errorCode) pure {
    assembly {
        let units := add(mod(errorCode, 10), 0x30)
        errorCode := div(errorCode, 10)
        let tenths := add(mod(errorCode, 10), 0x30)
        errorCode := div(errorCode, 10)
        let hundreds := add(mod(errorCode, 10), 0x30)
        let revertReason := shl(200, add(0x3f534e5323000000, add(add(units, shl(8, tenths)), shl(16, hundreds))))
        mstore(0x0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
        mstore(0x24, 7)
        mstore(0x44, revertReason)
        revert(0, 100)
    }
}
library Errors {
    uint256 internal constant CALLER_NOT_VAULT = 100;
    uint256 internal constant INVALID_G1 = 101;
    uint256 internal constant INVALID_G2 = 102;
    uint256 internal constant INVALID_POOL_ID = 103;
    uint256 internal constant POOL_ALREADY_DEPLOYED = 104;
    uint256 internal constant POOL_PAST_MATURITY = 105;
    uint256 internal constant SWAP_TOO_SMALL = 106;
    uint256 internal constant NEGATIVE_RATE = 107;
    uint256 internal constant BPT_OUT_MIN_AMOUNT = 108;
}