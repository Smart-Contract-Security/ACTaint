pragma solidity ^0.8.9;
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "../BaseComponentUpgradeable.sol";
import "../staking/stake_subjects/DirectStakeSubject.sol";
import "../../errors/GeneralErrors.sol";
import "../scanner_pools/ScannerPoolRegistry.sol";
abstract contract ScannerRegistryCore is
    BaseComponentUpgradeable,
    ERC721Upgradeable,
    DirectStakeSubjectUpgradeable
{
    mapping(uint256 => StakeThreshold) internal _stakeThresholds;
    event ScannerUpdated(uint256 indexed scannerId, uint256 indexed chainId, string metadata);
    event StakeThresholdChanged(uint256 indexed chainId, uint256 min, uint256 max, bool activated);
    error ScannerNotRegistered(address scanner);
    modifier onlyOwnerOf(uint256 scannerId) {
        if (_msgSender() != ownerOf(scannerId)) revert SenderNotOwner(_msgSender(), scannerId);
        _;
    }
    function isRegistered(uint256 scannerId) public view override returns(bool) {
        return _exists(scannerId);
    }
    function scannerAddressToId(address scanner) public pure returns(uint256) {
        return uint256(uint160(scanner));
    }
    function setStakeThreshold(StakeThreshold calldata newStakeThreshold, uint256 chainId) external onlyRole(SCANNER_ADMIN_ROLE) {
        if (newStakeThreshold.max <= newStakeThreshold.min) revert StakeThresholdMaxLessOrEqualMin();
        emit StakeThresholdChanged(chainId, newStakeThreshold.min, newStakeThreshold.max, newStakeThreshold.activated);
        _stakeThresholds[chainId] = newStakeThreshold;
    }
    function _getStakeThreshold(uint256 subject) internal virtual view returns(StakeThreshold memory);
    function getStakeThreshold(uint256 subject) external view returns(StakeThreshold memory) {
        return _getStakeThreshold(subject);
    }
    function _isStakedOverMin(uint256 scannerId) internal virtual override view returns(bool) {
        if (address(getSubjectHandler()) == address(0) || !_getStakeThreshold(scannerId).activated) {
            return true;
        }
        return getSubjectHandler().activeStakeFor(SCANNER_SUBJECT, scannerId) >= _getStakeThreshold(scannerId).min && _exists(scannerId);
    }
    function _msgSender() internal view virtual override(BaseComponentUpgradeable, ContextUpgradeable) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(BaseComponentUpgradeable, ContextUpgradeable) returns (bytes calldata) {
        return super._msgData();
    }
    function ownerOf(uint256 subject) public view virtual override(DirectStakeSubjectUpgradeable, ERC721Upgradeable) returns (address) {
        return super.ownerOf(subject);
    }
    uint256[44] private __gap; 
}