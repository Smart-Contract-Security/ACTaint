pragma solidity ^0.8.9;
import "../../../errors/GeneralErrors.sol";
import "./IDelegatedStakeSubject.sol";
import "./IStakeSubjectGateway.sol";
import "../SubjectTypeValidator.sol";
import "../../Roles.sol";
import "../../utils/AccessManaged.sol";
abstract contract DelegatedStakeSubjectUpgradeable is AccessManagedUpgradeable, IDelegatedStakeSubject {
    IStakeSubjectGateway private _subjectGateway;
    event SubjectHandlerUpdated(address indexed newHandler);
    error StakedUnderMinimum(uint256 subject);
    function __StakeSubjectUpgradeable_init(address subjectGateway) internal initializer {
        _setSubjectHandler(subjectGateway);
    }
    function setSubjectHandler(address subjectGateway) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setSubjectHandler(subjectGateway);
    }
    function getSubjectHandler() public view returns (IStakeSubjectGateway) {
        return _subjectGateway;
    }
    function _setSubjectHandler(address subjectGateway) private {
        if (subjectGateway == address(0)) revert ZeroAddress("subjectGateway");
        _subjectGateway = IStakeSubjectGateway(subjectGateway);
        emit SubjectHandlerUpdated(subjectGateway);
    }
    uint256[4] private __gap;
}