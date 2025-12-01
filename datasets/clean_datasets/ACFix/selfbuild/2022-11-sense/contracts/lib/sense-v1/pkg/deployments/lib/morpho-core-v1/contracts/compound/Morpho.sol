pragma solidity 0.8.13;
import "./MorphoGovernance.sol";
contract Morpho is MorphoGovernance {
    using SafeTransferLib for ERC20;
    using DelegateCall for address;
    event RewardsClaimed(address indexed _user, uint256 _amountClaimed, bool indexed _traded);
    error ClaimRewardsPaused();
    function supply(
        address _poolTokenAddress,
        address _onBehalf,
        uint256 _amount
    ) external nonReentrant isMarketCreatedAndNotPausedNorPartiallyPaused(_poolTokenAddress) {
        address(positionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                positionsManager.supplyLogic.selector,
                _poolTokenAddress,
                msg.sender,
                _onBehalf,
                _amount,
                defaultMaxGasForMatching.supply
            )
        );
    }
    function supply(
        address _poolTokenAddress,
        address _onBehalf,
        uint256 _amount,
        uint256 _maxGasForMatching
    ) external nonReentrant isMarketCreatedAndNotPausedNorPartiallyPaused(_poolTokenAddress) {
        address(positionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                positionsManager.supplyLogic.selector,
                _poolTokenAddress,
                msg.sender,
                _onBehalf,
                _amount,
                _maxGasForMatching
            )
        );
    }
    function borrow(address _poolTokenAddress, uint256 _amount)
        external
        nonReentrant
        isMarketCreatedAndNotPausedNorPartiallyPaused(_poolTokenAddress)
    {
        address(positionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                positionsManager.borrowLogic.selector,
                _poolTokenAddress,
                _amount,
                defaultMaxGasForMatching.borrow
            )
        );
    }
    function borrow(
        address _poolTokenAddress,
        uint256 _amount,
        uint256 _maxGasForMatching
    ) external nonReentrant isMarketCreatedAndNotPausedNorPartiallyPaused(_poolTokenAddress) {
        address(positionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                positionsManager.borrowLogic.selector,
                _poolTokenAddress,
                _amount,
                _maxGasForMatching
            )
        );
    }
    function withdraw(address _poolTokenAddress, uint256 _amount)
        external
        nonReentrant
        isMarketCreatedAndNotPaused(_poolTokenAddress)
    {
        address(positionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                positionsManager.withdrawLogic.selector,
                _poolTokenAddress,
                _amount,
                msg.sender,
                msg.sender,
                defaultMaxGasForMatching.withdraw
            )
        );
    }
    function repay(
        address _poolTokenAddress,
        address _onBehalf,
        uint256 _amount
    ) external nonReentrant isMarketCreatedAndNotPaused(_poolTokenAddress) {
        address(positionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                positionsManager.repayLogic.selector,
                _poolTokenAddress,
                msg.sender,
                _onBehalf,
                _amount,
                defaultMaxGasForMatching.repay
            )
        );
    }
    function liquidate(
        address _poolTokenBorrowedAddress,
        address _poolTokenCollateralAddress,
        address _borrower,
        uint256 _amount
    )
        external
        nonReentrant
        isMarketCreatedAndNotPaused(_poolTokenBorrowedAddress)
        isMarketCreatedAndNotPaused(_poolTokenCollateralAddress)
    {
        address(positionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                positionsManager.liquidateLogic.selector,
                _poolTokenBorrowedAddress,
                _poolTokenCollateralAddress,
                _borrower,
                _amount
            )
        );
    }
    function claimRewards(address[] calldata _cTokenAddresses, bool _tradeForMorphoToken)
        external
        nonReentrant
        returns (uint256 amountOfRewards)
    {
        if (isClaimRewardsPaused) revert ClaimRewardsPaused();
        amountOfRewards = rewardsManager.claimRewards(_cTokenAddresses, msg.sender);
        if (amountOfRewards > 0) {
            ERC20 comp = ERC20(comptroller.getCompAddress());
            comptroller.claimComp(address(this), _cTokenAddresses);
            if (_tradeForMorphoToken) {
                comp.safeApprove(address(incentivesVault), amountOfRewards);
                incentivesVault.tradeCompForMorphoTokens(msg.sender, amountOfRewards);
            } else comp.safeTransfer(msg.sender, amountOfRewards);
            emit RewardsClaimed(msg.sender, amountOfRewards, _tradeForMorphoToken);
        }
    }
    receive() external payable {}
}