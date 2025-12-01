pragma solidity ^0.8.0;
import "../../interfaces/IERC5805.sol";
import "../../utils/Context.sol";
import "../../utils/Counters.sol";
import "../../utils/Checkpoints.sol";
import "../../utils/cryptography/EIP712.sol";
abstract contract Votes is Context, EIP712, IERC5805 {
    using Checkpoints for Checkpoints.Trace224;
    using Counters for Counters.Counter;
    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
    mapping(address => address) private _delegation;
    mapping(address => Checkpoints.Trace224) private _delegateCheckpoints;
    Checkpoints.Trace224 private _totalCheckpoints;
    mapping(address => Counters.Counter) private _nonces;
    function clock() public view virtual override returns (uint48) {
        return SafeCast.toUint48(block.number);
    }
    function CLOCK_MODE() public view virtual override returns (string memory) {
        require(clock() == block.number, "Votes: broken clock mode");
        return "mode=blocknumber&from=default";
    }
    function getVotes(address account) public view virtual override returns (uint256) {
        return _delegateCheckpoints[account].latest();
    }
    function getPastVotes(address account, uint256 timepoint) public view virtual override returns (uint256) {
        require(timepoint < clock(), "Votes: future lookup");
        return _delegateCheckpoints[account].upperLookupRecent(SafeCast.toUint32(timepoint));
    }
    function getPastTotalSupply(uint256 timepoint) public view virtual override returns (uint256) {
        require(timepoint < clock(), "Votes: future lookup");
        return _totalCheckpoints.upperLookupRecent(SafeCast.toUint32(timepoint));
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
    function _transferVotingUnits(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) {
            _push(_totalCheckpoints, _add, SafeCast.toUint224(amount));
        }
        if (to == address(0)) {
            _push(_totalCheckpoints, _subtract, SafeCast.toUint224(amount));
        }
        _moveDelegateVotes(delegates(from), delegates(to), amount);
    }
    function _moveDelegateVotes(address from, address to, uint256 amount) private {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                (uint256 oldValue, uint256 newValue) = _push(
                    _delegateCheckpoints[from],
                    _subtract,
                    SafeCast.toUint224(amount)
                );
                emit DelegateVotesChanged(from, oldValue, newValue);
            }
            if (to != address(0)) {
                (uint256 oldValue, uint256 newValue) = _push(
                    _delegateCheckpoints[to],
                    _add,
                    SafeCast.toUint224(amount)
                );
                emit DelegateVotesChanged(to, oldValue, newValue);
            }
        }
    }
    function _push(
        Checkpoints.Trace224 storage store,
        function(uint224, uint224) view returns (uint224) op,
        uint224 delta
    ) private returns (uint224, uint224) {
        return store.push(SafeCast.toUint32(clock()), op(store.latest(), delta));
    }
    function _add(uint224 a, uint224 b) private pure returns (uint224) {
        return a + b;
    }
    function _subtract(uint224 a, uint224 b) private pure returns (uint224) {
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