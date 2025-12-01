pragma solidity >=0.7.0;
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
abstract contract Trust {
    event UserTrustUpdated(address indexed user, bool trusted);
    mapping(address => bool) public isTrusted;
    constructor(address initialUser) {
        isTrusted[initialUser] = true;
        emit UserTrustUpdated(initialUser, true);
    }
    function setIsTrusted(address user, bool trusted) public virtual requiresTrust {
        isTrusted[user] = trusted;
        emit UserTrustUpdated(user, trusted);
    }
    modifier requiresTrust() {
        if (!isTrusted[msg.sender]) revert Errors.Untrusted();
        _;
    }
}