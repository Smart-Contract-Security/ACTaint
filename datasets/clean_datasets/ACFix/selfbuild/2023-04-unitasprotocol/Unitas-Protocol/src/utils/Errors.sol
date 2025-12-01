pragma solidity ^0.8.19;
function _require(bool condition, uint256 errorCode) pure {
    if (!condition) {
        _revert(errorCode);
    }
}
function _revert(uint256 errorCode) pure {
    assembly {
        let one := add(mod(errorCode, 10), 48)
        let two := add(mod(div(errorCode, 10), 10), 48)
        let three := add(mod(div(errorCode, 100), 10), 48)
        let four := add(mod(div(errorCode, 1000), 10), 48)
        let err := shl(
            160,
            add(
                shl(
                    32,
                    0x556e697461733a20
                ),
                add(add(add(
                    one,
                    shl(8, two)),
                    shl(16, three)),
                    shl(24, four)
                )
            )
        )
        mstore(0x0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
        mstore(0x24, 12)
        mstore(0x44, err)
        revert(0, 100)
    }
}
library Errors {
    uint256 internal constant ADDRESS_ZERO = 1000;
    uint256 internal constant ADDRESS_CODE_SIZE_ZERO = 1001;
    uint256 internal constant PARAMETER_INVALID = 1002;
    uint256 internal constant INPUT_OUT_OF_BOUNDS = 1003;
    uint256 internal constant ARRAY_LENGTH_MISMATCHED = 1004;
    uint256 internal constant AMOUNT_INVALID = 1005;
    uint256 internal constant SENDER_INVALID = 1006;
    uint256 internal constant RECEIVER_INVALID = 1007;
    uint256 internal constant BALANCE_INSUFFICIENT = 1008;
    uint256 internal constant POOL_BALANCE_INSUFFICIENT = 1009;
    uint256 internal constant TOKEN_TYPE_INVALID = 2000;
    uint256 internal constant TOKEN_ALREADY_EXISTS = 2001;
    uint256 internal constant TOKEN_NOT_EXISTS = 2002;
    uint256 internal constant TOKENS_NOT_SORTED = 2003;
    uint256 internal constant PAIR_ALREADY_EXISTS = 2030;
    uint256 internal constant PAIR_NOT_EXISTS = 2031;
    uint256 internal constant PAIRS_MUST_REMOVED = 2032;
    uint256 internal constant PAIR_INVALID = 2033;
    uint256 internal constant MIN_PRICE_INVALID = 2060;
    uint256 internal constant MAX_PRICE_INVALID = 2061;
    uint256 internal constant FEE_NUMERATOR_INVALID = 2062;
    uint256 internal constant RESERVE_RATIO_THRESHOLD_INVALID = 2063;
    uint256 internal constant USD1_NOT_SET = 2064;
    uint256 internal constant SWAP_RESULT_INVALID = 2100;
    uint256 internal constant PRICE_TOLERANCE_INVALID = 2101;
    uint256 internal constant PRICE_INVALID = 2102;
    uint256 internal constant RESERVE_RATIO_NOT_GREATER_THAN_THRESHOLD = 2103;
    uint256 internal constant FEE_FRACTION_INVALID = 2104;
}