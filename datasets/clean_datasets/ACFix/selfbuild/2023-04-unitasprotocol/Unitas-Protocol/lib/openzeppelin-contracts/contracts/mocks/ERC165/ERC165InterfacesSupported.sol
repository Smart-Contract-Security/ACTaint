pragma solidity ^0.8.0;
import "../../utils/introspection/IERC165.sol";
contract SupportsInterfaceWithLookupMock is IERC165 {
    bytes4 public constant INTERFACE_ID_ERC165 = 0x01ffc9a7;
    mapping(bytes4 => bool) private _supportedInterfaces;
    constructor() {
        _registerInterface(INTERFACE_ID_ERC165);
    }
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return _supportedInterfaces[interfaceId];
    }
    function _registerInterface(bytes4 interfaceId) internal {
        require(interfaceId != 0xffffffff, "ERC165InterfacesSupported: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}
contract ERC165InterfacesSupported is SupportsInterfaceWithLookupMock {
    constructor(bytes4[] memory interfaceIds) {
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            _registerInterface(interfaceIds[i]);
        }
    }
}