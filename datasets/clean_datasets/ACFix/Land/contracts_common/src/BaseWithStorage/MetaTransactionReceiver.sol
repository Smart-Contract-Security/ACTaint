pragma solidity ^0.5.2;
import "./Admin.sol";
contract MetaTransactionReceiver is Admin{
    mapping(address => bool) internal _metaTransactionContracts;
    event MetaTransactionProcessor(address metaTransactionProcessor, bool enabled);
    function setMetaTransactionProcessor(address metaTransactionProcessor, bool enabled) public {
        require(
            msg.sender == _admin,
            "only admin can setup metaTransactionProcessors"
        );
        _setMetaTransactionProcessor(metaTransactionProcessor, enabled);
    }
    function _setMetaTransactionProcessor(address metaTransactionProcessor, bool enabled) internal {
        _metaTransactionContracts[metaTransactionProcessor] = enabled;
        emit MetaTransactionProcessor(metaTransactionProcessor, enabled);
    }
    function isMetaTransactionProcessor(address who) external view returns(bool) {
        return _metaTransactionContracts[who];
    }
}