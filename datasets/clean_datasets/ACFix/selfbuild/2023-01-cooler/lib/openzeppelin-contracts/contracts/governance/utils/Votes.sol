pragma solidity ^0.8.0;
import "../../utils/Context.sol";
import "../../utils/Counters.sol";
import "../../utils/Checkpoints.sol";
import "../../utils/cryptography/EIP712.sol";
import "./IVotes.sol";
abstract contract Votes is IVotes, Context, EIP712 {
    using Checkpoints for Checkpoints.History;
    using Counters for Counters.Counter;
    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
    mapping(address => address) private _delegation;
    mapping(address => Checkpoints.History) private _delegateCheckpoints;
    Checkpoints.History private _totalCheckpoints;
    mapping(address => Counters.Counter) private _nonces;
    function getVotes(address account) public view virtual override returns (uint256) {
        return _delegateCheckpoints[account].latest();
    }
    function getPastVotes(address account, uint256 blockNumber) public view virtual override returns (uint256) {
        return _delegateCheckpoints[account].getAtBlock(blockNumber);
    }
    function getPastTotalSupply(uint256 blockNumber) public view virtual override returns (uint256) {
        require(blockNumber < block.number, "Votes: block not yet mined");
        return _totalCheckpoints.getAtBlock(blockNumber);
    }
    function _getTotalSupply() internal view virtual returns (uint256) {
        return _totalCheckpoints.latest();
    }
    function delegates(address account) public view virtual override returns (address) {
        return _delegation[account];
    }
    function delegate(address delegatee) public virtual override {
        address account = _msgSender();
        _delegate(account, delegatee);
    }
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        require(block.timestamp <= expiry, "Votes: signature expired");
        address signer = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(_DELEGATION_TYPEHASH, delegatee, nonce, expiry))),
            v,
            r,
            s
        );
        require(nonce == _useNonce(signer), "Votes: invalid nonce");
        _delegate(signer, delegatee);
    }
    function _delegate(address account, address delegatee) internal virtual {
        address oldDelegate = delegates(account);
        _delegation[account] = delegatee;
        emit DelegateChanged(account, oldDelegate, delegatee);
        _moveDelegateVotes(oldDelegate, delegatee, _getVotingUnits(account));
    }
    function _transferVotingUnits(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        if (from == address(0)) {
            _totalCheckpoints.push(_add, amount);
        }
        if (to == address(0)) {
            _totalCheckpoints.push(_subtract, amount);
        }
        _moveDelegateVotes(delegates(from), delegates(to), amount);
    }
    function _moveDelegateVotes(
        address from,
        address to,
        uint256 amount
    ) private {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                (uint256 oldValue, uint256 newValue) = _delegateCheckpoints[from].push(_subtract, amount);
                emit DelegateVotesChanged(from, oldValue, newValue);
            }
            if (to != address(0)) {
                (uint256 oldValue, uint256 newValue) = _delegateCheckpoints[to].push(_add, amount);
                emit DelegateVotesChanged(to, oldValue, newValue);
            }
        }
    }
    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }
    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }
    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner].current();
    }
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
    function _getVotingUnits(address) internal view virtual returns (uint256);
}