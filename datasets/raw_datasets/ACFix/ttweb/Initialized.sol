function initialize(
    address _LINK,
    address _owner,
    uint256 _capacity,
    uint256 _startingSharesPerLink
) public initializer {          //@audit-issue front-runnable initialize. No access control.
    LINK = _LINK;
    decimals = IERC20Metadata(_LINK).decimals();
    owner = _owner;
    MAX_CAPACITY = _capacity;
    STARTING_SHARES_PER_LINK = _startingSharesPerLink;
}