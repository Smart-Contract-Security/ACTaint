pragma solidity 0.8.13;
import "./interfaces/IPositionsManager.sol";
import "./interfaces/IWETH.sol";
import "./MatchingEngine.sol";
contract PositionsManager is IPositionsManager, MatchingEngine {
    using DoubleLinkedList for DoubleLinkedList.List;
    using SafeTransferLib for ERC20;
    using CompoundMath for uint256;
    event Supplied(
        address indexed _supplier,
        address indexed _onBehalf,
        address indexed _poolTokenAddress,
        uint256 _amount,
        uint256 _balanceOnPool,
        uint256 _balanceInP2P
    );
    event Borrowed(
        address indexed _borrower,
        address indexed _poolTokenAddress,
        uint256 _amount,
        uint256 _balanceOnPool,
        uint256 _balanceInP2P
    );
    event Withdrawn(
        address indexed _supplier,
        address indexed _receiver,
        address indexed _poolTokenAddress,
        uint256 _amount,
        uint256 _balanceOnPool,
        uint256 _balanceInP2P
    );
    event Repaid(
        address indexed _repayer,
        address indexed _onBehalf,
        address indexed _poolTokenAddress,
        uint256 _amount,
        uint256 _balanceOnPool,
        uint256 _balanceInP2P
    );
    event Liquidated(
        address _liquidator,
        address indexed _liquidated,
        address indexed _poolTokenBorrowedAddress,
        uint256 _amountRepaid,
        address indexed _poolTokenCollateralAddress,
        uint256 _amountSeized
    );
    event P2PBorrowDeltaUpdated(address indexed _poolTokenAddress, uint256 _p2pBorrowDelta);
    event P2PSupplyDeltaUpdated(address indexed _poolTokenAddress, uint256 _p2pSupplyDelta);
    event P2PAmountsUpdated(
        address indexed _poolTokenAddress,
        uint256 _p2pSupplyAmount,
        uint256 _p2pBorrowAmount
    );
    error AmountAboveWhatAllowedToRepay();
    error BorrowOnCompoundFailed();
    error RedeemOnCompoundFailed();
    error RepayOnCompoundFailed();
    error MintOnCompoundFailed();
    error UserNotMemberOfMarket();
    error UnauthorisedWithdraw();
    error UnauthorisedLiquidate();
    error UnauthorisedBorrow();
    error WithdrawTooSmall();
    error AddressIsZero();
    error AmountIsZero();
    error SameBlockBorrowRepay();
    struct SupplyVars {
        uint256 remainingToSupply;
        uint256 poolBorrowIndex;
        uint256 toRepay;
    }
    struct WithdrawVars {
        uint256 remainingGasForMatching;
        uint256 remainingToWithdraw;
        uint256 poolSupplyIndex;
        uint256 p2pSupplyIndex;
        uint256 withdrawable;
        uint256 toWithdraw;
        ERC20 underlyingToken;
    }
    struct RepayVars {
        uint256 remainingGasForMatching;
        uint256 remainingToRepay;
        uint256 maxToRepayOnPool;
        uint256 poolBorrowIndex;
        uint256 p2pSupplyIndex;
        uint256 p2pBorrowIndex;
        uint256 borrowedOnPool;
        uint256 feeToRepay;
        uint256 toRepay;
    }
    struct LiquidateVars {
        uint256 collateralPrice;
        uint256 borrowBalance;
        uint256 supplyBalance;
        uint256 borrowedPrice;
        uint256 amountToSeize;
    }
    function supplyLogic(
        address _poolTokenAddress,
        address _supplier,
        address _onBehalf,
        uint256 _amount,
        uint256 _maxGasForMatching
    ) external {
        if (_onBehalf == address(0)) revert AddressIsZero();
        if (_amount == 0) revert AmountIsZero();
        _updateP2PIndexes(_poolTokenAddress);
        _enterMarketIfNeeded(_poolTokenAddress, _onBehalf);
        ERC20 underlyingToken = _getUnderlying(_poolTokenAddress);
        underlyingToken.safeTransferFrom(_supplier, address(this), _amount);
        Types.Delta storage delta = deltas[_poolTokenAddress];
        SupplyVars memory vars;
        vars.poolBorrowIndex = ICToken(_poolTokenAddress).borrowIndex();
        vars.remainingToSupply = _amount;
        if (delta.p2pBorrowDelta > 0) {
            uint256 deltaInUnderlying = delta.p2pBorrowDelta.mul(vars.poolBorrowIndex);
            if (deltaInUnderlying > vars.remainingToSupply) {
                vars.toRepay += vars.remainingToSupply;
                delta.p2pBorrowDelta -= vars.remainingToSupply.div(vars.poolBorrowIndex);
                vars.remainingToSupply = 0;
            } else {
                vars.toRepay += deltaInUnderlying;
                delta.p2pBorrowDelta = 0;
                vars.remainingToSupply -= deltaInUnderlying;
            }
            emit P2PBorrowDeltaUpdated(_poolTokenAddress, delta.p2pBorrowDelta);
        }
        if (
            vars.remainingToSupply > 0 &&
            !p2pDisabled[_poolTokenAddress] &&
            borrowersOnPool[_poolTokenAddress].getHead() != address(0)
        ) {
            (uint256 matched, ) = _matchBorrowers(
                _poolTokenAddress,
                vars.remainingToSupply,
                _maxGasForMatching
            ); 
            if (matched > 0) {
                vars.toRepay += matched;
                vars.remainingToSupply -= matched;
                delta.p2pBorrowAmount += matched.div(p2pBorrowIndex[_poolTokenAddress]);
            }
        }
        if (vars.toRepay > 0) {
            uint256 toAddInP2P = vars.toRepay.div(p2pSupplyIndex[_poolTokenAddress]);
            delta.p2pSupplyAmount += toAddInP2P;
            supplyBalanceInOf[_poolTokenAddress][_onBehalf].inP2P += toAddInP2P;
            _repayToPool(_poolTokenAddress, underlyingToken, vars.toRepay); 
            emit P2PAmountsUpdated(_poolTokenAddress, delta.p2pSupplyAmount, delta.p2pBorrowAmount);
        }
        if (vars.remainingToSupply > 0) {
            supplyBalanceInOf[_poolTokenAddress][_onBehalf].onPool += vars.remainingToSupply.div(
                ICToken(_poolTokenAddress).exchangeRateStored() 
            ); 
            _supplyToPool(_poolTokenAddress, underlyingToken, vars.remainingToSupply); 
        }
        _updateSupplierInDS(_poolTokenAddress, _onBehalf);
        emit Supplied(
            _supplier,
            _onBehalf,
            _poolTokenAddress,
            _amount,
            supplyBalanceInOf[_poolTokenAddress][_onBehalf].onPool,
            supplyBalanceInOf[_poolTokenAddress][_onBehalf].inP2P
        );
    }
    function borrowLogic(
        address _poolTokenAddress,
        uint256 _amount,
        uint256 _maxGasForMatching
    ) external {
        if (_amount == 0) revert AmountIsZero();
        _updateP2PIndexes(_poolTokenAddress);
        _enterMarketIfNeeded(_poolTokenAddress, msg.sender);
        lastBorrowBlock[msg.sender] = block.number;
        if (_isLiquidatable(msg.sender, _poolTokenAddress, 0, _amount)) revert UnauthorisedBorrow();
        ERC20 underlyingToken = _getUnderlying(_poolTokenAddress);
        uint256 remainingToBorrow = _amount;
        uint256 toWithdraw;
        Types.Delta storage delta = deltas[_poolTokenAddress];
        uint256 poolSupplyIndex = ICToken(_poolTokenAddress).exchangeRateStored(); 
        uint256 withdrawable = ICToken(_poolTokenAddress).balanceOfUnderlying(address(this)); 
        if (delta.p2pSupplyDelta > 0) {
            uint256 deltaInUnderlying = delta.p2pSupplyDelta.mul(poolSupplyIndex);
            if (deltaInUnderlying > remainingToBorrow || deltaInUnderlying > withdrawable) {
                uint256 matchedDelta = CompoundMath.min(remainingToBorrow, withdrawable);
                toWithdraw += matchedDelta;
                delta.p2pSupplyDelta -= matchedDelta.div(poolSupplyIndex);
                remainingToBorrow -= matchedDelta;
            } else {
                toWithdraw += deltaInUnderlying;
                delta.p2pSupplyDelta = 0;
                remainingToBorrow -= deltaInUnderlying;
            }
            emit P2PSupplyDeltaUpdated(_poolTokenAddress, delta.p2pSupplyDelta);
        }
        if (
            remainingToBorrow > 0 &&
            !p2pDisabled[_poolTokenAddress] &&
            suppliersOnPool[_poolTokenAddress].getHead() != address(0)
        ) {
            (uint256 matched, ) = _matchSuppliers(
                _poolTokenAddress,
                CompoundMath.min(remainingToBorrow, withdrawable - toWithdraw),
                _maxGasForMatching
            ); 
            if (matched > 0) {
                toWithdraw += matched;
                remainingToBorrow -= matched;
                deltas[_poolTokenAddress].p2pSupplyAmount += matched.div(
                    p2pSupplyIndex[_poolTokenAddress]
                );
            }
        }
        if (toWithdraw > 0) {
            uint256 toAddInP2P = toWithdraw.div(p2pBorrowIndex[_poolTokenAddress]); 
            deltas[_poolTokenAddress].p2pBorrowAmount += toAddInP2P;
            borrowBalanceInOf[_poolTokenAddress][msg.sender].inP2P += toAddInP2P;
            emit P2PAmountsUpdated(_poolTokenAddress, delta.p2pSupplyAmount, delta.p2pBorrowAmount);
            if (toWithdraw.div(poolSupplyIndex) > 0)
                _withdrawFromPool(_poolTokenAddress, toWithdraw); 
        }
        if (remainingToBorrow > 0) {
            borrowBalanceInOf[_poolTokenAddress][msg.sender].onPool += remainingToBorrow.div(
                ICToken(_poolTokenAddress).borrowIndex()
            ); 
            _borrowFromPool(_poolTokenAddress, remainingToBorrow);
        }
        _updateBorrowerInDS(_poolTokenAddress, msg.sender);
        underlyingToken.safeTransfer(msg.sender, _amount);
        emit Borrowed(
            msg.sender,
            _poolTokenAddress,
            _amount,
            borrowBalanceInOf[_poolTokenAddress][msg.sender].onPool,
            borrowBalanceInOf[_poolTokenAddress][msg.sender].inP2P
        );
    }
    function withdrawLogic(
        address _poolTokenAddress,
        uint256 _amount,
        address _supplier,
        address _receiver,
        uint256 _maxGasForMatching
    ) external {
        if (_amount == 0) revert AmountIsZero();
        if (!userMembership[_poolTokenAddress][_supplier]) revert UserNotMemberOfMarket();
        _updateP2PIndexes(_poolTokenAddress);
        uint256 toWithdraw = Math.min(
            _getUserSupplyBalanceInOf(_poolTokenAddress, _supplier),
            _amount
        );
        if (_isLiquidatable(_supplier, _poolTokenAddress, toWithdraw, 0))
            revert UnauthorisedWithdraw();
        _safeWithdrawLogic(_poolTokenAddress, toWithdraw, _supplier, _receiver, _maxGasForMatching);
    }
    function repayLogic(
        address _poolTokenAddress,
        address _repayer,
        address _onBehalf,
        uint256 _amount,
        uint256 _maxGasForMatching
    ) external {
        if (_amount == 0) revert AmountIsZero();
        if (!userMembership[_poolTokenAddress][_onBehalf]) revert UserNotMemberOfMarket();
        _updateP2PIndexes(_poolTokenAddress);
        uint256 toRepay = Math.min(
            _getUserBorrowBalanceInOf(_poolTokenAddress, _onBehalf),
            _amount
        );
        _safeRepayLogic(_poolTokenAddress, _repayer, _onBehalf, toRepay, _maxGasForMatching);
    }
    function liquidateLogic(
        address _poolTokenBorrowedAddress,
        address _poolTokenCollateralAddress,
        address _borrower,
        uint256 _amount
    ) external {
        if (
            !userMembership[_poolTokenBorrowedAddress][_borrower] ||
            !userMembership[_poolTokenCollateralAddress][_borrower]
        ) revert UserNotMemberOfMarket();
        _updateP2PIndexes(_poolTokenBorrowedAddress);
        _updateP2PIndexes(_poolTokenCollateralAddress);
        if (!_isLiquidatable(_borrower, address(0), 0, 0)) revert UnauthorisedLiquidate();
        LiquidateVars memory vars;
        vars.borrowBalance = _getUserBorrowBalanceInOf(_poolTokenBorrowedAddress, _borrower);
        if (_amount > vars.borrowBalance.mul(comptroller.closeFactorMantissa()))
            revert AmountAboveWhatAllowedToRepay(); 
        _safeRepayLogic(_poolTokenBorrowedAddress, msg.sender, _borrower, _amount, 0);
        ICompoundOracle compoundOracle = ICompoundOracle(comptroller.oracle());
        vars.collateralPrice = compoundOracle.getUnderlyingPrice(_poolTokenCollateralAddress);
        vars.borrowedPrice = compoundOracle.getUnderlyingPrice(_poolTokenBorrowedAddress);
        if (vars.collateralPrice == 0 || vars.borrowedPrice == 0) revert CompoundOracleFailed();
        vars.amountToSeize = Math.min(
            _amount.mul(comptroller.liquidationIncentiveMantissa()).mul(vars.borrowedPrice).div(
                vars.collateralPrice
            ),
            _getUserSupplyBalanceInOf(_poolTokenCollateralAddress, _borrower)
        );
        _safeWithdrawLogic(
            _poolTokenCollateralAddress,
            vars.amountToSeize,
            _borrower,
            msg.sender,
            0
        );
        emit Liquidated(
            msg.sender,
            _borrower,
            _poolTokenBorrowedAddress,
            _amount,
            _poolTokenCollateralAddress,
            vars.amountToSeize
        );
    }
    function _safeWithdrawLogic(
        address _poolTokenAddress,
        uint256 _amount,
        address _supplier,
        address _receiver,
        uint256 _maxGasForMatching
    ) internal {
        if (_amount == 0) revert AmountIsZero();
        WithdrawVars memory vars;
        vars.underlyingToken = _getUnderlying(_poolTokenAddress);
        vars.remainingToWithdraw = _amount;
        vars.remainingGasForMatching = _maxGasForMatching;
        vars.withdrawable = ICToken(_poolTokenAddress).balanceOfUnderlying(address(this));
        vars.poolSupplyIndex = ICToken(_poolTokenAddress).exchangeRateStored(); 
        if (_amount.div(vars.poolSupplyIndex) == 0) revert WithdrawTooSmall();
        uint256 onPoolSupply = supplyBalanceInOf[_poolTokenAddress][_supplier].onPool;
        if (onPoolSupply > 0) {
            uint256 maxToWithdrawOnPool = onPoolSupply.mul(vars.poolSupplyIndex);
            if (
                maxToWithdrawOnPool > vars.remainingToWithdraw ||
                maxToWithdrawOnPool > vars.withdrawable
            ) {
                vars.toWithdraw = CompoundMath.min(vars.remainingToWithdraw, vars.withdrawable);
                vars.remainingToWithdraw -= vars.toWithdraw;
                supplyBalanceInOf[_poolTokenAddress][_supplier].onPool -= vars.toWithdraw.div(
                    vars.poolSupplyIndex
                );
            } else {
                vars.toWithdraw = maxToWithdrawOnPool;
                vars.remainingToWithdraw -= maxToWithdrawOnPool;
                supplyBalanceInOf[_poolTokenAddress][_supplier].onPool = 0;
            }
            if (vars.remainingToWithdraw == 0) {
                _updateSupplierInDS(_poolTokenAddress, _supplier);
                _leaveMarketIfNeeded(_poolTokenAddress, _supplier);
                if (vars.toWithdraw.div(vars.poolSupplyIndex) > 0)
                    _withdrawFromPool(_poolTokenAddress, vars.toWithdraw); 
                vars.underlyingToken.safeTransfer(_receiver, _amount);
                emit Withdrawn(
                    _supplier,
                    _receiver,
                    _poolTokenAddress,
                    _amount,
                    supplyBalanceInOf[_poolTokenAddress][_supplier].onPool,
                    supplyBalanceInOf[_poolTokenAddress][_supplier].inP2P
                );
                return;
            }
        }
        Types.Delta storage delta = deltas[_poolTokenAddress];
        vars.p2pSupplyIndex = p2pSupplyIndex[_poolTokenAddress];
        supplyBalanceInOf[_poolTokenAddress][_supplier].inP2P -= CompoundMath.min(
            supplyBalanceInOf[_poolTokenAddress][_supplier].inP2P,
            vars.remainingToWithdraw.div(vars.p2pSupplyIndex)
        ); 
        _updateSupplierInDS(_poolTokenAddress, _supplier);
        if (vars.remainingToWithdraw > 0 && delta.p2pSupplyDelta > 0) {
            uint256 deltaInUnderlying = delta.p2pSupplyDelta.mul(vars.poolSupplyIndex);
            if (
                deltaInUnderlying > vars.remainingToWithdraw ||
                deltaInUnderlying > vars.withdrawable - vars.toWithdraw
            ) {
                uint256 matchedDelta = CompoundMath.min(
                    vars.remainingToWithdraw,
                    vars.withdrawable - vars.toWithdraw
                );
                delta.p2pSupplyDelta -= matchedDelta.div(vars.poolSupplyIndex);
                delta.p2pSupplyAmount -= matchedDelta.div(vars.p2pSupplyIndex);
                vars.toWithdraw += matchedDelta;
                vars.remainingToWithdraw -= matchedDelta;
            } else {
                vars.toWithdraw += deltaInUnderlying;
                vars.remainingToWithdraw -= deltaInUnderlying;
                delta.p2pSupplyDelta = 0;
                delta.p2pSupplyAmount -= deltaInUnderlying.div(vars.p2pSupplyIndex);
            }
            emit P2PSupplyDeltaUpdated(_poolTokenAddress, delta.p2pSupplyDelta);
            emit P2PAmountsUpdated(_poolTokenAddress, delta.p2pSupplyAmount, delta.p2pBorrowAmount);
        }
        if (
            vars.remainingToWithdraw > 0 &&
            !p2pDisabled[_poolTokenAddress] &&
            suppliersOnPool[_poolTokenAddress].getHead() != address(0)
        ) {
            (uint256 matched, uint256 gasConsumedInMatching) = _matchSuppliers(
                _poolTokenAddress,
                CompoundMath.min(vars.remainingToWithdraw, vars.withdrawable - vars.toWithdraw),
                vars.remainingGasForMatching
            );
            if (vars.remainingGasForMatching <= gasConsumedInMatching)
                vars.remainingGasForMatching = 0;
            else vars.remainingGasForMatching -= gasConsumedInMatching;
            if (matched > 0) {
                vars.remainingToWithdraw -= matched;
                vars.toWithdraw += matched;
            }
        }
        if (vars.toWithdraw.div(vars.poolSupplyIndex) > 0)
            _withdrawFromPool(_poolTokenAddress, vars.toWithdraw); 
        if (vars.remainingToWithdraw > 0) {
            uint256 unmatched = _unmatchBorrowers(
                _poolTokenAddress,
                vars.remainingToWithdraw,
                vars.remainingGasForMatching
            );
            if (unmatched < vars.remainingToWithdraw) {
                delta.p2pBorrowDelta += (vars.remainingToWithdraw - unmatched).div(
                    ICToken(_poolTokenAddress).borrowIndex()
                );
                emit P2PBorrowDeltaUpdated(_poolTokenAddress, delta.p2pBorrowDelta);
            }
            delta.p2pSupplyAmount -= vars.remainingToWithdraw.div(vars.p2pSupplyIndex);
            delta.p2pBorrowAmount -= unmatched.div(p2pBorrowIndex[_poolTokenAddress]);
            emit P2PAmountsUpdated(_poolTokenAddress, delta.p2pSupplyAmount, delta.p2pBorrowAmount);
            _borrowFromPool(_poolTokenAddress, vars.remainingToWithdraw); 
        }
        _leaveMarketIfNeeded(_poolTokenAddress, _supplier);
        vars.underlyingToken.safeTransfer(_receiver, _amount);
        emit Withdrawn(
            _supplier,
            _receiver,
            _poolTokenAddress,
            _amount,
            supplyBalanceInOf[_poolTokenAddress][_supplier].onPool,
            supplyBalanceInOf[_poolTokenAddress][_supplier].inP2P
        );
    }
    function _safeRepayLogic(
        address _poolTokenAddress,
        address _repayer,
        address _onBehalf,
        uint256 _amount,
        uint256 _maxGasForMatching
    ) internal {
        if (lastBorrowBlock[_onBehalf] == block.number) revert SameBlockBorrowRepay();
        ERC20 underlyingToken = _getUnderlying(_poolTokenAddress);
        underlyingToken.safeTransferFrom(_repayer, address(this), _amount);
        RepayVars memory vars;
        vars.remainingToRepay = _amount;
        vars.remainingGasForMatching = _maxGasForMatching;
        vars.poolBorrowIndex = ICToken(_poolTokenAddress).borrowIndex();
        vars.borrowedOnPool = borrowBalanceInOf[_poolTokenAddress][_onBehalf].onPool;
        if (vars.borrowedOnPool > 0) {
            vars.maxToRepayOnPool = vars.borrowedOnPool.mul(vars.poolBorrowIndex);
            if (vars.maxToRepayOnPool > vars.remainingToRepay) {
                vars.toRepay = vars.remainingToRepay;
                borrowBalanceInOf[_poolTokenAddress][_onBehalf].onPool -= CompoundMath.min(
                    vars.borrowedOnPool,
                    vars.toRepay.div(vars.poolBorrowIndex)
                ); 
                _updateBorrowerInDS(_poolTokenAddress, _onBehalf);
                _repayToPool(_poolTokenAddress, underlyingToken, vars.toRepay); 
                _leaveMarketIfNeeded(_poolTokenAddress, _onBehalf);
                emit Repaid(
                    _repayer,
                    _onBehalf,
                    _poolTokenAddress,
                    _amount,
                    borrowBalanceInOf[_poolTokenAddress][_onBehalf].onPool,
                    borrowBalanceInOf[_poolTokenAddress][_onBehalf].inP2P
                );
                return;
            } else {
                vars.toRepay = vars.maxToRepayOnPool;
                vars.remainingToRepay -= vars.toRepay;
                borrowBalanceInOf[_poolTokenAddress][_onBehalf].onPool = 0;
            }
        }
        Types.Delta storage delta = deltas[_poolTokenAddress];
        vars.p2pSupplyIndex = p2pSupplyIndex[_poolTokenAddress];
        vars.p2pBorrowIndex = p2pBorrowIndex[_poolTokenAddress];
        borrowBalanceInOf[_poolTokenAddress][_onBehalf].inP2P -= CompoundMath.min(
            borrowBalanceInOf[_poolTokenAddress][_onBehalf].inP2P,
            vars.remainingToRepay.div(vars.p2pBorrowIndex)
        ); 
        _updateBorrowerInDS(_poolTokenAddress, _onBehalf);
        if (vars.remainingToRepay > 0 && delta.p2pBorrowDelta > 0) {
            uint256 deltaInUnderlying = delta.p2pBorrowDelta.mul(vars.poolBorrowIndex);
            if (deltaInUnderlying > vars.remainingToRepay) {
                delta.p2pBorrowDelta -= vars.remainingToRepay.div(vars.poolBorrowIndex);
                delta.p2pBorrowAmount -= vars.remainingToRepay.div(vars.p2pBorrowIndex);
                vars.toRepay += vars.remainingToRepay;
                vars.remainingToRepay = 0;
            } else {
                delta.p2pBorrowDelta = 0;
                delta.p2pBorrowAmount -= deltaInUnderlying.div(vars.p2pBorrowIndex);
                vars.toRepay += deltaInUnderlying;
                vars.remainingToRepay -= deltaInUnderlying;
            }
            emit P2PBorrowDeltaUpdated(_poolTokenAddress, delta.p2pBorrowDelta);
            emit P2PAmountsUpdated(_poolTokenAddress, delta.p2pSupplyAmount, delta.p2pBorrowAmount);
        }
        if (vars.remainingToRepay > 0) {
            vars.feeToRepay = CompoundMath.safeSub(
                delta.p2pBorrowAmount.mul(vars.p2pBorrowIndex),
                (delta.p2pSupplyAmount.mul(vars.p2pSupplyIndex) -
                    delta.p2pSupplyDelta.mul(ICToken(_poolTokenAddress).exchangeRateStored()))
            );
            if (vars.feeToRepay > 0) {
                uint256 feeRepaid = CompoundMath.min(vars.feeToRepay, vars.remainingToRepay);
                vars.remainingToRepay -= feeRepaid;
                delta.p2pBorrowAmount -= feeRepaid.div(vars.p2pBorrowIndex);
                emit P2PAmountsUpdated(
                    _poolTokenAddress,
                    delta.p2pSupplyAmount,
                    delta.p2pBorrowAmount
                );
            }
        }
        if (
            vars.remainingToRepay > 0 &&
            !p2pDisabled[_poolTokenAddress] &&
            borrowersOnPool[_poolTokenAddress].getHead() != address(0)
        ) {
            (uint256 matched, uint256 gasConsumedInMatching) = _matchBorrowers(
                _poolTokenAddress,
                vars.remainingToRepay,
                vars.remainingGasForMatching
            );
            if (vars.remainingGasForMatching <= gasConsumedInMatching)
                vars.remainingGasForMatching = 0;
            else vars.remainingGasForMatching -= gasConsumedInMatching;
            if (matched > 0) {
                vars.remainingToRepay -= matched;
                vars.toRepay += matched;
            }
        }
        _repayToPool(_poolTokenAddress, underlyingToken, vars.toRepay); 
        if (vars.remainingToRepay > 0) {
            uint256 unmatched = _unmatchSuppliers(
                _poolTokenAddress,
                vars.remainingToRepay,
                vars.remainingGasForMatching
            );
            if (unmatched < vars.remainingToRepay) {
                delta.p2pSupplyDelta += (vars.remainingToRepay - unmatched).div(
                    ICToken(_poolTokenAddress).exchangeRateStored() 
                );
                emit P2PSupplyDeltaUpdated(_poolTokenAddress, delta.p2pSupplyDelta);
            }
            delta.p2pSupplyAmount -= unmatched.div(vars.p2pSupplyIndex);
            delta.p2pBorrowAmount -= vars.remainingToRepay.div(vars.p2pBorrowIndex);
            emit P2PAmountsUpdated(_poolTokenAddress, delta.p2pSupplyAmount, delta.p2pBorrowAmount);
            _supplyToPool(_poolTokenAddress, underlyingToken, vars.remainingToRepay); 
        }
        _leaveMarketIfNeeded(_poolTokenAddress, _onBehalf);
        emit Repaid(
            _repayer,
            _onBehalf,
            _poolTokenAddress,
            _amount,
            borrowBalanceInOf[_poolTokenAddress][_onBehalf].onPool,
            borrowBalanceInOf[_poolTokenAddress][_onBehalf].inP2P
        );
    }
    function _supplyToPool(
        address _poolTokenAddress,
        ERC20 _underlyingToken,
        uint256 _amount
    ) internal {
        if (_poolTokenAddress == cEth) {
            IWETH(wEth).withdraw(_amount); 
            ICEther(_poolTokenAddress).mint{value: _amount}();
        } else {
            _underlyingToken.safeApprove(_poolTokenAddress, _amount);
            if (ICToken(_poolTokenAddress).mint(_amount) != 0) revert MintOnCompoundFailed();
        }
    }
    function _withdrawFromPool(address _poolTokenAddress, uint256 _amount) internal {
        if (ICToken(_poolTokenAddress).redeemUnderlying(_amount) != 0)
            revert RedeemOnCompoundFailed();
        if (_poolTokenAddress == cEth) IWETH(address(wEth)).deposit{value: _amount}(); 
    }
    function _borrowFromPool(address _poolTokenAddress, uint256 _amount) internal {
        if ((ICToken(_poolTokenAddress).borrow(_amount) != 0)) revert BorrowOnCompoundFailed();
        if (_poolTokenAddress == cEth) IWETH(address(wEth)).deposit{value: _amount}(); 
    }
    function _repayToPool(
        address _poolTokenAddress,
        ERC20 _underlyingToken,
        uint256 _amount
    ) internal {
        _amount = Math.min(
            _amount,
            ICToken(_poolTokenAddress).borrowBalanceCurrent(address(this)) 
        );
        if (_amount > 0) {
            if (_poolTokenAddress == cEth) {
                IWETH(wEth).withdraw(_amount); 
                ICEther(_poolTokenAddress).repayBorrow{value: _amount}();
            } else {
                _underlyingToken.safeApprove(_poolTokenAddress, _amount);
                if (ICToken(_poolTokenAddress).repayBorrow(_amount) != 0)
                    revert RepayOnCompoundFailed();
            }
        }
    }
    function _enterMarketIfNeeded(address _poolTokenAddress, address _user) internal {
        if (!userMembership[_poolTokenAddress][_user]) {
            userMembership[_poolTokenAddress][_user] = true;
            enteredMarkets[_user].push(_poolTokenAddress);
        }
    }
    function _leaveMarketIfNeeded(address _poolTokenAddress, address _user) internal {
        if (
            userMembership[_poolTokenAddress][_user] &&
            supplyBalanceInOf[_poolTokenAddress][_user].inP2P == 0 &&
            supplyBalanceInOf[_poolTokenAddress][_user].onPool == 0 &&
            borrowBalanceInOf[_poolTokenAddress][_user].inP2P == 0 &&
            borrowBalanceInOf[_poolTokenAddress][_user].onPool == 0
        ) {
            uint256 index;
            while (enteredMarkets[_user][index] != _poolTokenAddress) {
                unchecked {
                    ++index;
                }
            }
            userMembership[_poolTokenAddress][_user] = false;
            uint256 length = enteredMarkets[_user].length;
            if (index != length - 1)
                enteredMarkets[_user][index] = enteredMarkets[_user][length - 1];
            enteredMarkets[_user].pop();
        }
    }
}