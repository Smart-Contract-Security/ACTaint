pragma solidity ^0.7.0;
import "../helpers/CodeDeployer.sol";
contract CodeDeployerFactory {
    event CodeDeployed(address at);
    function deploy(bytes memory data) external {
        address destination = CodeDeployer.deploy(data);
        emit CodeDeployed(destination);
    }
}