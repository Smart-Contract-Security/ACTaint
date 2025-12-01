pragma solidity >=0.6.2 <0.9.0;
import {StdStorage} from "./StdStorage.sol";
import {Vm, VmSafe} from "./Vm.sol";
abstract contract CommonBase {
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    address internal constant CONSOLE = 0x000000000000000000636F6e736F6c652e6c6f67;
    address internal constant DEFAULT_SENDER = address(uint160(uint256(keccak256("foundry default caller"))));
    address internal constant DEFAULT_TEST_CONTRACT = 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f;
    address internal constant MULTICALL3_ADDRESS = 0xcA11bde05977b3631167028862bE2a173976CA11;
    uint256 internal constant UINT256_MAX =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;
    Vm internal constant vm = Vm(VM_ADDRESS);
    StdStorage internal stdstore;
}
abstract contract TestBase is CommonBase {}
abstract contract ScriptBase is CommonBase {
    address internal constant CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    VmSafe internal constant vmSafe = VmSafe(VM_ADDRESS);
}