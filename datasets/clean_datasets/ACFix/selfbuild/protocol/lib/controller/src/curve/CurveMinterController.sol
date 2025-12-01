pragma solidity ^0.8.15;
import {IController} from "../core/IController.sol";
contract CurveMinterController is IController {
    bytes4 constant MINT = 0x6a627842;
    address[] crv;
    constructor(address _crv) {
        crv.push(_crv);
    }
    function canCall(address, bool, bytes calldata data)
        external
        view
        returns (bool, address[] memory, address[] memory)
    {
        if (bytes4(data) == MINT) {
            return (true, crv, new address[](0));
        }
        return (false, new address[](0), new address[](0));
    }
}