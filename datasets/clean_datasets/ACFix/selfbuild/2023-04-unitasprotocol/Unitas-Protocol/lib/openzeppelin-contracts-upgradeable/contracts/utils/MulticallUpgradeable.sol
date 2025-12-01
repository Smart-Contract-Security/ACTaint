pragma solidity ^0.8.0;
import "./AddressUpgradeable.sol";
import "../proxy/utils/Initializable.sol";
abstract contract MulticallUpgradeable is Initializable {
    function __Multicall_init() internal onlyInitializing {
    }
    function __Multicall_init_unchained() internal onlyInitializing {
    }
    function multicall(bytes[] calldata data) external virtual returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = _functionDelegateCall(address(this), data[i]);
        }
        return results;
    }
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }
    uint256[50] private __gap;
}