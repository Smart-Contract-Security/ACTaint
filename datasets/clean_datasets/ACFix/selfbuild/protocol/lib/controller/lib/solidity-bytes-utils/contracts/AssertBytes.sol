pragma solidity >=0.8.0 <0.9.0;
library AssertBytes {
    event TestEvent(bool indexed result, string message);
    function _equal(bytes memory _a, bytes memory _b) internal pure returns (bool) {
        bool returnBool = true;
        assembly {
            let length := mload(_a)
            switch eq(length, mload(_b))
            case 1 {
                let cb := 1
                let mc := add(_a, 0x20)
                let end := add(mc, length)
                for {
                    let cc := add(_b, 0x20)
                } eq(add(lt(mc, end), cb), 2) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    if iszero(eq(mload(mc), mload(cc))) {
                        returnBool := 0
                        cb := 0
                    }
                }
            }
            default {
                returnBool := 0
            }
        }
        return returnBool;
    }
    function equal(bytes memory _a, bytes memory _b, string memory message) internal returns (bool) {
        bool returnBool = _equal(_a, _b);
        _report(returnBool, message);
        return returnBool;
    }
    function notEqual(bytes memory _a, bytes memory _b, string memory message) internal returns (bool) {
        bool returnBool = _equal(_a, _b);
        _report(!returnBool, message);
        return !returnBool;
    }
    function _equalStorage(bytes storage _a, bytes memory _b) internal view returns (bool) {
        bool returnBool = true;
        assembly {
            let fslot := sload(_a.slot)
            let slength := div(and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)), 2)
            let mlength := mload(_b)
            switch eq(slength, mlength)
            case 1 {
                if iszero(iszero(slength)) {
                    switch lt(slength, 32)
                    case 1 {
                        fslot := mul(div(fslot, 0x100), 0x100)
                        if iszero(eq(fslot, mload(add(_b, 0x20)))) {
                            returnBool := 0
                        }
                    }
                    default {
                        let cb := 1
                        mstore(0x0, _a.slot)
                        let sc := keccak256(0x0, 0x20)
                        let mc := add(_b, 0x20)
                        let end := add(mc, mlength)
                        for {} eq(add(lt(mc, end), cb), 2) {
                            sc := add(sc, 1)
                            mc := add(mc, 0x20)
                        } {
                            if iszero(eq(sload(sc), mload(mc))) {
                                returnBool := 0
                                cb := 0
                            }
                        }
                    }
                }
            }
            default {
                returnBool := 0
            }
        }
        return returnBool;
    }
    function equalStorage(bytes storage _a, bytes memory _b, string memory message) internal returns (bool) {
        bool returnBool = _equalStorage(_a, _b);
        _report(returnBool, message);
        return returnBool;
    }
    function notEqualStorage(bytes storage _a, bytes memory _b, string memory message) internal returns (bool) {
        bool returnBool = _equalStorage(_a, _b);
        _report(!returnBool, message);
        return !returnBool;
    }
    function _report(bool result, string memory message) internal {
        if (result)
            emit TestEvent(true, "");
        else
            emit TestEvent(false, message);
    }
}