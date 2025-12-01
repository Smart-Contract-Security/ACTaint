pragma solidity >=0.6.0 <0.9.0;
import "./Script.sol";
import "ds-test/test.sol";
abstract contract Test is DSTest, Script {
    using stdStorage for StdStorage;
    uint256 private constant UINT256_MAX = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    event WARNING_Deprecated(string msg);
    StdStorage internal stdstore;
    function skip(uint256 time) public {
        vm.warp(block.timestamp + time);
    }
    function rewind(uint256 time) public {
        vm.warp(block.timestamp - time);
    }
    function hoax(address who) public {
        vm.deal(who, 1 << 128);
        vm.prank(who);
    }
    function hoax(address who, uint256 give) public {
        vm.deal(who, give);
        vm.prank(who);
    }
    function hoax(address who, address origin) public {
        vm.deal(who, 1 << 128);
        vm.prank(who, origin);
    }
    function hoax(address who, address origin, uint256 give) public {
        vm.deal(who, give);
        vm.prank(who, origin);
    }
    function startHoax(address who) public {
        vm.deal(who, 1 << 128);
        vm.startPrank(who);
    }
    function startHoax(address who, uint256 give) public {
        vm.deal(who, give);
        vm.startPrank(who);
    }
    function startHoax(address who, address origin) public {
        vm.deal(who, 1 << 128);
        vm.startPrank(who, origin);
    }
    function startHoax(address who, address origin, uint256 give) public {
        vm.deal(who, give);
        vm.startPrank(who, origin);
    }
    function changePrank(address who) internal {
        vm.stopPrank();
        vm.startPrank(who);
    }
    function tip(address token, address to, uint256 give) public {
        emit WARNING_Deprecated("The `tip` stdcheat has been deprecated. Use `deal` instead.");
        stdstore
            .target(token)
            .sig(0x70a08231)
            .with_key(to)
            .checked_write(give);
    }
    function deal(address to, uint256 give) public {
        vm.deal(to, give);
    }
    function deal(address token, address to, uint256 give) public {
        deal(token, to, give, false);
    }
    function deal(address token, address to, uint256 give, bool adjust) public {
        (, bytes memory balData) = token.call(abi.encodeWithSelector(0x70a08231, to));
        uint256 prevBal = abi.decode(balData, (uint256));
        stdstore
            .target(token)
            .sig(0x70a08231)
            .with_key(to)
            .checked_write(give);
        if(adjust){
            (, bytes memory totSupData) = token.call(abi.encodeWithSelector(0x18160ddd));
            uint256 totSup = abi.decode(totSupData, (uint256));
            if(give < prevBal) {
                totSup -= (prevBal - give);
            } else {
                totSup += (give - prevBal);
            }
            stdstore
                .target(token)
                .sig(0x18160ddd)
                .checked_write(totSup);
        }
    }
    function bound(uint256 x, uint256 min, uint256 max) public returns (uint256 result) {
        require(min <= max, "Test bound(uint256,uint256,uint256): Max is less than min.");
        uint256 size = max - min;
        if (size == 0)
        {
            result = min;
        }
        else if (size == UINT256_MAX)
        {
            result = x;
        }
        else
        {
            ++size; 
            uint256 mod = x % size;
            result = min + mod;
        }
        emit log_named_uint("Bound Result", result);
    }
    function deployCode(string memory what, bytes memory args)
        public
        returns (address addr)
    {
        bytes memory bytecode = abi.encodePacked(vm.getCode(what), args);
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(
            addr != address(0),
            "Test deployCode(string,bytes): Deployment failed."
        );
    }
    function deployCode(string memory what)
        public
        returns (address addr)
    {
        bytes memory bytecode = vm.getCode(what);
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(
            addr != address(0),
            "Test deployCode(string): Deployment failed."
        );
    }
    function fail(string memory err) internal virtual {
        emit log_named_string("Error", err);
        fail();
    }
    function assertFalse(bool data) internal virtual {
        assertTrue(!data);
    }
    function assertFalse(bool data, string memory err) internal virtual {
        assertTrue(!data, err);
    }
    function assertEq(bool a, bool b) internal {
        if (a != b) {
            emit log                ("Error: a == b not satisfied [bool]");
            emit log_named_string   ("  Expected", b ? "true" : "false");
            emit log_named_string   ("    Actual", a ? "true" : "false");
            fail();
        }
    }
    function assertEq(bool a, bool b, string memory err) internal {
        if (a != b) {
            emit log_named_string("Error", err);
            assertEq(a, b);
        }
    }
    function assertEq(bytes memory a, bytes memory b) internal {
        assertEq0(a, b);
    }
    function assertEq(bytes memory a, bytes memory b, string memory err) internal {
        assertEq0(a, b, err);
    }
    function assertApproxEqAbs(
        uint256 a,
        uint256 b,
        uint256 maxDelta
    ) internal virtual {
        uint256 delta = stdMath.delta(a, b);
        if (delta > maxDelta) {
            emit log            ("Error: a ~= b not satisfied [uint]");
            emit log_named_uint ("  Expected", b);
            emit log_named_uint ("    Actual", a);
            emit log_named_uint (" Max Delta", maxDelta);
            emit log_named_uint ("     Delta", delta);
            fail();
        }
    }
    function assertApproxEqAbs(
        uint256 a,
        uint256 b,
        uint256 maxDelta,
        string memory err
    ) internal virtual {
        uint256 delta = stdMath.delta(a, b);
        if (delta > maxDelta) {
            emit log_named_string   ("Error", err);
            assertApproxEqAbs(a, b, maxDelta);
        }
    }
    function assertApproxEqAbs(
        int256 a,
        int256 b,
        uint256 maxDelta
    ) internal virtual {
        uint256 delta = stdMath.delta(a, b);
        if (delta > maxDelta) {
            emit log            ("Error: a ~= b not satisfied [int]");
            emit log_named_int  ("  Expected", b);
            emit log_named_int  ("    Actual", a);
            emit log_named_uint (" Max Delta", maxDelta);
            emit log_named_uint ("     Delta", delta);
            fail();
        }
    }
    function assertApproxEqAbs(
        int256 a,
        int256 b,
        uint256 maxDelta,
        string memory err
    ) internal virtual {
        uint256 delta = stdMath.delta(a, b);
        if (delta > maxDelta) {
            emit log_named_string   ("Error", err);
            assertApproxEqAbs(a, b, maxDelta);
        }
    }
    function assertApproxEqRel(
        uint256 a,
        uint256 b,
        uint256 maxPercentDelta 
    ) internal virtual {
        if (b == 0) return assertEq(a, b); 
        uint256 percentDelta = stdMath.percentDelta(a, b);
        if (percentDelta > maxPercentDelta) {
            emit log                    ("Error: a ~= b not satisfied [uint]");
            emit log_named_uint         ("    Expected", b);
            emit log_named_uint         ("      Actual", a);
            emit log_named_decimal_uint (" Max % Delta", maxPercentDelta, 18);
            emit log_named_decimal_uint ("     % Delta", percentDelta, 18);
            fail();
        }
    }
    function assertApproxEqRel(
        uint256 a,
        uint256 b,
        uint256 maxPercentDelta, 
        string memory err
    ) internal virtual {
        if (b == 0) return assertEq(a, b); 
        uint256 percentDelta = stdMath.percentDelta(a, b);
        if (percentDelta > maxPercentDelta) {
            emit log_named_string       ("Error", err);
            assertApproxEqRel(a, b, maxPercentDelta);
        }
    }
    function assertApproxEqRel(
        int256 a,
        int256 b,
        uint256 maxPercentDelta
    ) internal virtual {
        if (b == 0) return assertEq(a, b); 
        uint256 percentDelta = stdMath.percentDelta(a, b);
        if (percentDelta > maxPercentDelta) {
            emit log                   ("Error: a ~= b not satisfied [int]");
            emit log_named_int         ("    Expected", b);
            emit log_named_int         ("      Actual", a);
            emit log_named_decimal_uint(" Max % Delta", maxPercentDelta, 18);
            emit log_named_decimal_uint("     % Delta", percentDelta, 18);
            fail();
        }
    }
    function assertApproxEqRel(
        int256 a,
        int256 b,
        uint256 maxPercentDelta,
        string memory err
    ) internal virtual {
        if (b == 0) return assertEq(a, b); 
        uint256 percentDelta = stdMath.percentDelta(a, b);
        if (percentDelta > maxPercentDelta) {
            emit log_named_string      ("Error", err);
            assertApproxEqRel(a, b, maxPercentDelta);
        }
    }
}
library stdError {
    bytes public constant assertionError = abi.encodeWithSignature("Panic(uint256)", 0x01);
    bytes public constant arithmeticError = abi.encodeWithSignature("Panic(uint256)", 0x11);
    bytes public constant divisionError = abi.encodeWithSignature("Panic(uint256)", 0x12);
    bytes public constant enumConversionError = abi.encodeWithSignature("Panic(uint256)", 0x21);
    bytes public constant encodeStorageError = abi.encodeWithSignature("Panic(uint256)", 0x22);
    bytes public constant popError = abi.encodeWithSignature("Panic(uint256)", 0x31);
    bytes public constant indexOOBError = abi.encodeWithSignature("Panic(uint256)", 0x32);
    bytes public constant memOverflowError = abi.encodeWithSignature("Panic(uint256)", 0x41);
    bytes public constant zeroVarError = abi.encodeWithSignature("Panic(uint256)", 0x51);
    bytes public constant lowLevelError = bytes(""); 
}
struct StdStorage {
    mapping (address => mapping(bytes4 => mapping(bytes32 => uint256))) slots;
    mapping (address => mapping(bytes4 =>  mapping(bytes32 => bool))) finds;
    bytes32[] _keys;
    bytes4 _sig;
    uint256 _depth;
    address _target;
    bytes32 _set;
}
library stdStorage {
    event SlotFound(address who, bytes4 fsig, bytes32 keysHash, uint slot);
    event WARNING_UninitedSlot(address who, uint slot);
    uint256 private constant UINT256_MAX = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    int256 private constant INT256_MAX = 57896044618658097711785492504343953926634992332820282019728792003956564819967;
    Vm private constant vm_std_store = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));
    function sigs(
        string memory sigStr
    )
        internal
        pure
        returns (bytes4)
    {
        return bytes4(keccak256(bytes(sigStr)));
    }
    function find(
        StdStorage storage self
    )
        internal
        returns (uint256)
    {
        address who = self._target;
        bytes4 fsig = self._sig;
        uint256 field_depth = self._depth;
        bytes32[] memory ins = self._keys;
        if (self.finds[who][fsig][keccak256(abi.encodePacked(ins, field_depth))]) {
            return self.slots[who][fsig][keccak256(abi.encodePacked(ins, field_depth))];
        }
        bytes memory cald = abi.encodePacked(fsig, flatten(ins));
        vm_std_store.record();
        bytes32 fdat;
        {
            (, bytes memory rdat) = who.staticcall(cald);
            fdat = bytesToBytes32(rdat, 32*field_depth);
        }
        (bytes32[] memory reads, ) = vm_std_store.accesses(address(who));
        if (reads.length == 1) {
            bytes32 curr = vm_std_store.load(who, reads[0]);
            if (curr == bytes32(0)) {
                emit WARNING_UninitedSlot(who, uint256(reads[0]));
            }
            if (fdat != curr) {
                require(false, "stdStorage find(StdStorage): Packed slot. This would cause dangerous overwriting and currently isnt supported");
            }
            emit SlotFound(who, fsig, keccak256(abi.encodePacked(ins, field_depth)), uint256(reads[0]));
            self.slots[who][fsig][keccak256(abi.encodePacked(ins, field_depth))] = uint256(reads[0]);
            self.finds[who][fsig][keccak256(abi.encodePacked(ins, field_depth))] = true;
        } else if (reads.length > 1) {
            for (uint256 i = 0; i < reads.length; i++) {
                bytes32 prev = vm_std_store.load(who, reads[i]);
                if (prev == bytes32(0)) {
                    emit WARNING_UninitedSlot(who, uint256(reads[i]));
                }
                vm_std_store.store(who, reads[i], bytes32(hex"1337"));
                bool success;
                bytes memory rdat;
                {
                    (success, rdat) = who.staticcall(cald);
                    fdat = bytesToBytes32(rdat, 32*field_depth);
                }
                if (success && fdat == bytes32(hex"1337")) {
                    emit SlotFound(who, fsig, keccak256(abi.encodePacked(ins, field_depth)), uint256(reads[i]));
                    self.slots[who][fsig][keccak256(abi.encodePacked(ins, field_depth))] = uint256(reads[i]);
                    self.finds[who][fsig][keccak256(abi.encodePacked(ins, field_depth))] = true;
                    vm_std_store.store(who, reads[i], prev);
                    break;
                }
                vm_std_store.store(who, reads[i], prev);
            }
        } else {
            require(false, "stdStorage find(StdStorage): No storage use detected for target.");
        }
        require(self.finds[who][fsig][keccak256(abi.encodePacked(ins, field_depth))], "stdStorage find(StdStorage): Slot(s) not found.");
        delete self._target;
        delete self._sig;
        delete self._keys;
        delete self._depth;
        return self.slots[who][fsig][keccak256(abi.encodePacked(ins, field_depth))];
    }
    function target(StdStorage storage self, address _target) internal returns (StdStorage storage) {
        self._target = _target;
        return self;
    }
    function sig(StdStorage storage self, bytes4 _sig) internal returns (StdStorage storage) {
        self._sig = _sig;
        return self;
    }
    function sig(StdStorage storage self, string memory _sig) internal returns (StdStorage storage) {
        self._sig = sigs(_sig);
        return self;
    }
    function with_key(StdStorage storage self, address who) internal returns (StdStorage storage) {
        self._keys.push(bytes32(uint256(uint160(who))));
        return self;
    }
    function with_key(StdStorage storage self, uint256 amt) internal returns (StdStorage storage) {
        self._keys.push(bytes32(amt));
        return self;
    }
    function with_key(StdStorage storage self, bytes32 key) internal returns (StdStorage storage) {
        self._keys.push(key);
        return self;
    }
    function depth(StdStorage storage self, uint256 _depth) internal returns (StdStorage storage) {
        self._depth = _depth;
        return self;
    }
    function checked_write(StdStorage storage self, address who) internal {
        checked_write(self, bytes32(uint256(uint160(who))));
    }
    function checked_write(StdStorage storage self, uint256 amt) internal {
        checked_write(self, bytes32(amt));
    }
    function checked_write(StdStorage storage self, bool write) internal {
        bytes32 t;
        assembly {
            t := write
        }
        checked_write(self, t);
    }
    function checked_write(
        StdStorage storage self,
        bytes32 set
    ) internal {
        address who = self._target;
        bytes4 fsig = self._sig;
        uint256 field_depth = self._depth;
        bytes32[] memory ins = self._keys;
        bytes memory cald = abi.encodePacked(fsig, flatten(ins));
        if (!self.finds[who][fsig][keccak256(abi.encodePacked(ins, field_depth))]) {
            find(self);
        }
        bytes32 slot = bytes32(self.slots[who][fsig][keccak256(abi.encodePacked(ins, field_depth))]);
        bytes32 fdat;
        {
            (, bytes memory rdat) = who.staticcall(cald);
            fdat = bytesToBytes32(rdat, 32*field_depth);
        }
        bytes32 curr = vm_std_store.load(who, slot);
        if (fdat != curr) {
            require(false, "stdStorage find(StdStorage): Packed slot. This would cause dangerous overwriting and currently isnt supported.");
        }
        vm_std_store.store(who, slot, set);
        delete self._target;
        delete self._sig;
        delete self._keys;
        delete self._depth;
    }
    function read(StdStorage storage self) private returns (bytes memory) {
        address t = self._target;
        uint256 s = find(self);
        return abi.encode(vm_std_store.load(t, bytes32(s)));
    }
    function read_bytes32(StdStorage storage self) internal returns (bytes32) {
        return abi.decode(read(self), (bytes32));
    }
    function read_bool(StdStorage storage self) internal returns (bool) {
        return abi.decode(read(self), (bool));
    }
    function read_address(StdStorage storage self) internal returns (address) {
        return abi.decode(read(self), (address));
    }
    function read_uint(StdStorage storage self) internal returns (uint256) {
        return abi.decode(read(self), (uint256));
    }
    function read_int(StdStorage storage self) internal returns (int256) {
        return abi.decode(read(self), (int256));
    }
    function bytesToBytes32(bytes memory b, uint offset) public pure returns (bytes32) {
        bytes32 out;
        uint256 max = b.length > 32 ? 32 : b.length;
        for (uint i = 0; i < max; i++) {
            out |= bytes32(b[offset + i] & 0xFF) >> (i * 8);
        }
        return out;
    }
    function flatten(bytes32[] memory b) private pure returns (bytes memory)
    {
        bytes memory result = new bytes(b.length * 32);
        for (uint256 i = 0; i < b.length; i++) {
            bytes32 k = b[i];
            assembly {
                mstore(add(result, add(32, mul(32, i))), k)
            }
        }
        return result;
    }
}
library stdMath {
    int256 private constant INT256_MIN = -57896044618658097711785492504343953926634992332820282019728792003956564819968;
    function abs(int256 a) internal pure returns (uint256) {
        if (a == INT256_MIN)
            return 57896044618658097711785492504343953926634992332820282019728792003956564819968;
        return uint256(a >= 0 ? a : -a);
    }
    function delta(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b
            ? a - b
            : b - a;
    }
    function delta(int256 a, int256 b) internal pure returns (uint256) {
        if (a >= 0 && b >= 0 || a < 0 && b < 0) {
            return delta(abs(a), abs(b));
        }
        return abs(a) + abs(b);
    }
    function percentDelta(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 absDelta = delta(a, b);
        return absDelta * 1e18 / b;
    }
    function percentDelta(int256 a, int256 b) internal pure returns (uint256) {
        uint256 absDelta = delta(a, b);
        uint256 absB = abs(b);
        return absDelta * 1e18 / absB;
    }
}