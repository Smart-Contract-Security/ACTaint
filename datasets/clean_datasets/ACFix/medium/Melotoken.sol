function mint(
    address account,
    uint256 amount,
    string memory txId
) public returns (bool) {
    _mint(account, amount);
    emit Minted(account, amount, txId);
    return true;
}