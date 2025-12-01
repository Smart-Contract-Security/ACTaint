pragma solidity ^0.7.0;
import "./BalancerErrors.sol";
library CodeDeployer {
    bytes32
        private constant _DEPLOYER_CREATION_CODE = 0x602038038060206000396000f3fefefefefefefefefefefefefefefefefefefe;
    function deploy(bytes memory code) internal returns (address destination) {
        bytes32 deployerCreationCode = _DEPLOYER_CREATION_CODE;
        assembly {
            let codeLength := mload(code)
            mstore(code, deployerCreationCode)
            destination := create(0, code, add(codeLength, 32))
            mstore(code, codeLength)
        }
        _require(destination != address(0), Errors.CODE_DEPLOYMENT_FAILED);
    }
}