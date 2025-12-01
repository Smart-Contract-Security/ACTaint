pragma solidity ^0.7.0;
import "./ERC20.sol";
import "./IERC20Permit.sol";
import "./EIP712.sol";
abstract contract ERC20Permit is ERC20, IERC20Permit, EIP712 {
    mapping(address => uint256) private _nonces;
    bytes32 private immutable _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    constructor(string memory name) EIP712(name, "1") {}
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        _require(block.timestamp <= deadline, Errors.EXPIRED_PERMIT);
        uint256 nonce = _nonces[owner];
        bytes32 structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ecrecover(hash, v, r, s);
        _require((signer != address(0)) && (signer == owner), Errors.INVALID_SIGNATURE);
        _nonces[owner] = nonce + 1;
        _approve(owner, spender, value);
    }
    function nonces(address owner) public view override returns (uint256) {
        return _nonces[owner];
    }
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }
}