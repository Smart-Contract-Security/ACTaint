pragma solidity ^0.8.9;
import "./AccessManaged.sol";
abstract contract RoutedUpgradeable is AccessManagedUpgradeable {
    address private _deprecated_router;
    event RouterUpdated(address indexed router);
    function disableRouter() public {
        if (_deprecated_router == address(0)) {
            revert ZeroAddress("_deprecated_router");
        }
        _deprecated_router = address(0);
        emit RouterUpdated(address(0));
    }
    uint256[49] private __gap;
}