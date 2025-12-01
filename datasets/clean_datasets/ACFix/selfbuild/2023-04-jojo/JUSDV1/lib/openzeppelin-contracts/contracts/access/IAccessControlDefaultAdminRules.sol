pragma solidity ^0.8.0;
import "./IAccessControl.sol";
interface IAccessControlDefaultAdminRules is IAccessControl {
    event DefaultAdminTransferScheduled(address indexed newAdmin, uint48 acceptSchedule);
    event DefaultAdminTransferCanceled();
    event DefaultAdminDelayChangeScheduled(uint48 newDelay, uint48 effectSchedule);
    event DefaultAdminDelayChangeCanceled();
    function defaultAdmin() external view returns (address);
    function pendingDefaultAdmin() external view returns (address newAdmin, uint48 acceptSchedule);
    function defaultAdminDelay() external view returns (uint48);
    function pendingDefaultAdminDelay() external view returns (uint48 newDelay, uint48 effectSchedule);
    function beginDefaultAdminTransfer(address newAdmin) external;
    function cancelDefaultAdminTransfer() external;
    function acceptDefaultAdminTransfer() external;
    function changeDefaultAdminDelay(uint48 newDelay) external;
    function rollbackDefaultAdminDelay() external;
    function defaultAdminDelayIncreaseWait() external view returns (uint48);
}