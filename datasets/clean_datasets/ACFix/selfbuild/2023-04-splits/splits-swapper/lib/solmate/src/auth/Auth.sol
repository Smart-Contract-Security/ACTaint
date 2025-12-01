pragma solidity >=0.8.0;
abstract contract Auth {
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event AuthorityUpdated(address indexed user, Authority indexed newAuthority);
    address public owner;
    Authority public authority;
    constructor(address _owner, Authority _authority) {
        owner = _owner;
        authority = _authority;
        emit OwnershipTransferred(msg.sender, _owner);
        emit AuthorityUpdated(msg.sender, _authority);
    }
    modifier requiresAuth() virtual {
        require(isAuthorized(msg.sender, msg.sig), "UNAUTHORIZED");
        _;
    }
    function isAuthorized(address user, bytes4 functionSig) internal view virtual returns (bool) {
        Authority auth = authority; 
        return (address(auth) != address(0) && auth.canCall(user, address(this), functionSig)) || user == owner;
    }
    function setAuthority(Authority newAuthority) public virtual {
        require(msg.sender == owner || authority.canCall(msg.sender, address(this), msg.sig));
        authority = newAuthority;
        emit AuthorityUpdated(msg.sender, newAuthority);
    }
    function transferOwnership(address newOwner) public virtual requiresAuth {
        owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }
}
interface Authority {
    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) external view returns (bool);
}