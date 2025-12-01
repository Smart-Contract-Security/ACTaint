function withdrawInterest(uint256 _id, address _lender) external nonReentrant {
    _withdrawInterest(_id, _lender);
}
function _withdrawInterest(uint256 _id, address _lender) internal {
    address _strategy = pooledCLConstants[_id].borrowAssetStrategy;
    address _borrowAsset = pooledCLConstants[_id].borrowAsset;
    (uint256 _interestToWithdraw, uint256 _interestSharesToWithdraw) = _calculateInterestToWithdraw(
        _id,
        _lender,
        _strategy,
        _borrowAsset
    );
    pooledCLVariables[_id].sharesHeld = pooledCLVariables[_id].sharesHeld.sub(_interestSharesToWithdraw);
    if (_interestToWithdraw != 0) {
        SAVINGS_ACCOUNT.withdraw(_borrowAsset, _strategy, _lender, _interestToWithdraw, false);
    }
    emit InterestWithdrawn(_id, _lender, _interestSharesToWithdraw);
}