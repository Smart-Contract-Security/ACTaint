pragma solidity ^0.8.22;
import "./IStakeAllocator.sol";
import "../SubjectTypeValidator.sol";
import "../FortaStakingUtils.sol";
import "../rewards/IRewardsDistributor.sol";
import "../stake_subjects/IStakeSubjectGateway.sol";
import "../../BaseComponentUpgradeable.sol";
import "../../../tools/Distributions.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
contract StakeAllocator is BaseComponentUpgradeable, SubjectTypeValidator, IStakeAllocator {
    using Distributions for Distributions.Balances;
    string public constant version = "0.1.0";
    IStakeSubjectGateway private immutable _subjectGateway;
    IRewardsDistributor public immutable rewardsDistributor;
    Distributions.Balances private _allocatedStake;
    Distributions.Balances private _unallocatedStake;
    event AllocatedStake(uint8 indexed subjectType, uint256 indexed subject, bool increase, uint256 amount, uint256 totalAllocated);
    event UnallocatedStake(uint8 indexed subjectType, uint256 indexed subject, bool increase, uint256 amount, uint256 totalAllocated);
    error SenderCannotAllocateFor(uint8 subjectType, uint256 subject);
    error CannotDelegateStakeUnderMin(uint8 subjectType, uint256 subject);
    error CannotDelegateNoEnabledSubjects(uint8 subjectType, uint256 subject);
    constructor(address _forwarder, address __subjectGateway, address _rewardsDistributor) initializer ForwardedContext(_forwarder) {
        if (__subjectGateway == address(0)) revert ZeroAddress("__subjectGateway");
        if (_rewardsDistributor == address(0)) revert ZeroAddress("_rewardsDistributor");
        _subjectGateway = IStakeSubjectGateway(__subjectGateway);
        rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
    }
    function initialize(address __manager) public initializer {
        __BaseComponentUpgradeable_init(__manager);
    }
    function allocatedStakeFor(uint8 subjectType, uint256 subject) public view returns (uint256) {
        return _allocatedStake.balanceOf(FortaStakingUtils.subjectToActive(subjectType, subject));
    }
    function allocatedManagedStake(uint8 subjectType, uint256 subject) public view returns (uint256) {
        if (getSubjectTypeAgency(subjectType) == SubjectStakeAgency.DELEGATED) {
            return
                _allocatedStake.balanceOf(FortaStakingUtils.subjectToActive(subjectType, subject)) +
                _allocatedStake.balanceOf(FortaStakingUtils.subjectToActive(getDelegatorSubjectType(subjectType), subject));
        }
        return 0;
    }
    function allocatedStakePerManaged(uint8 subjectType, uint256 subject) external view returns (uint256) {
        if (getSubjectTypeAgency(subjectType) != SubjectStakeAgency.DELEGATED || _subjectGateway.totalManagedSubjects(subjectType, subject) == 0) {
            return 0;
        }
        return allocatedManagedStake(subjectType, subject) / _subjectGateway.totalManagedSubjects(subjectType, subject);
    }
    function allocatedOwnStakePerManaged(uint8 subjectType, uint256 subject) public view returns (uint256) {
        if (getSubjectTypeAgency(subjectType) != SubjectStakeAgency.DELEGATED) {
            return 0;
        }
        return allocatedStakeFor(subjectType, subject) / _subjectGateway.totalManagedSubjects(subjectType, subject);
    }
    function allocatedDelegatorsStakePerManaged(uint8 subjectType, uint256 subject) public view returns (uint256) {
        if (getSubjectTypeAgency(subjectType) != SubjectStakeAgency.DELEGATED) {
            return 0;
        }
        return allocatedStakeFor(getDelegatorSubjectType(subjectType), subject) / _subjectGateway.totalManagedSubjects(subjectType, subject);
    }
    function unallocatedStakeFor(uint8 subjectType, uint256 subject) external view returns (uint256) {
        return _unallocatedStake.balanceOf(FortaStakingUtils.subjectToActive(subjectType, subject));
    }
    function allocateOwnStake(
        uint8 subjectType,
        uint256 subject,
        uint256 amount
    ) external onlyAgencyType(subjectType, SubjectStakeAgency.DELEGATED) {
        if (!_subjectGateway.canManageAllocation(subjectType, subject, _msgSender())) revert SenderCannotAllocateFor(subjectType, subject);
        _allocateStake(subjectType, subject, _msgSender(), amount);
    }
    function unallocateOwnStake(
        uint8 subjectType,
        uint256 subject,
        uint256 amount
    ) external onlyAgencyType(subjectType, SubjectStakeAgency.DELEGATED) {
        if (!_subjectGateway.canManageAllocation(subjectType, subject, _msgSender())) revert SenderCannotAllocateFor(subjectType, subject);
        _unallocateStake(subjectType, subject, amount);
    }
    function allocateDelegatorStake(
        uint8 subjectType,
        uint256 subject,
        uint256 amount
    ) external onlyAgencyType(subjectType, SubjectStakeAgency.DELEGATED) {
        if (!_subjectGateway.canManageAllocation(subjectType, subject, _msgSender())) revert SenderCannotAllocateFor(subjectType, subject);
        _allocateStake(getDelegatorSubjectType(subjectType), subject, _msgSender(), amount);
    }
    function unallocateDelegatorStake(
        uint8 subjectType,
        uint256 subject,
        uint256 amount
    ) external onlyAgencyType(subjectType, SubjectStakeAgency.DELEGATED) {
        if (!_subjectGateway.canManageAllocation(subjectType, subject, _msgSender())) revert SenderCannotAllocateFor(subjectType, subject);
        _unallocateStake(getDelegatorSubjectType(subjectType), subject, amount);
    }
    function _allocateStake(
        uint8 subjectType,
        uint256 subject,
        address allocator,
        uint256 amount
    ) private {
        uint256 activeSharesId = FortaStakingUtils.subjectToActive(subjectType, subject);
        if (_unallocatedStake.balanceOf(activeSharesId) < amount) revert AmountTooLarge(amount, _unallocatedStake.balanceOf(activeSharesId));
        (int256 extra, uint256 max) = _allocationIncreaseChecks(subjectType, subject, getSubjectTypeAgency(subjectType), allocator, amount);
        if (extra > 0) revert AmountTooLarge(amount, max);
        _allocatedStake.mint(activeSharesId, amount);
        _unallocatedStake.burn(activeSharesId, amount);
        rewardsDistributor.didAllocate(subjectType, subject, amount, 0, address(0));
        emit AllocatedStake(subjectType, subject, true, amount, _allocatedStake.balanceOf(activeSharesId));
        emit UnallocatedStake(subjectType, subject, false, amount, _unallocatedStake.balanceOf(activeSharesId));
    }
    function _unallocateStake(
        uint8 subjectType,
        uint256 subject,
        uint256 amount
    ) private {
        uint256 activeSharesId = FortaStakingUtils.subjectToActive(subjectType, subject);
        if (_allocatedStake.balanceOf(activeSharesId) < amount) revert AmountTooLarge(amount, _allocatedStake.balanceOf(activeSharesId));
        _allocatedStake.burn(activeSharesId, amount);
        _unallocatedStake.mint(activeSharesId, amount);
        rewardsDistributor.didUnallocate(subjectType, subject, amount, 0, address(0));
        emit AllocatedStake(subjectType, subject, false, amount, _allocatedStake.balanceOf(activeSharesId));
        emit UnallocatedStake(subjectType, subject, true, amount, _unallocatedStake.balanceOf(activeSharesId));
    }
    function depositAllocation(
        uint256 activeSharesId,
        uint8 subjectType,
        uint256 subject,
        address allocator,
        uint256 stakeAmount,
        uint256 sharesAmount
    ) external override onlyRole(STAKING_CONTRACT_ROLE) {
        SubjectStakeAgency agency = getSubjectTypeAgency(subjectType);
        if (agency != SubjectStakeAgency.DELEGATED && agency != SubjectStakeAgency.DELEGATOR) {
            return;
        }
        (int256 extra, ) = _allocationIncreaseChecks(subjectType, subject, agency, allocator, stakeAmount);
        if (extra > 0) {
            _allocatedStake.mint(activeSharesId, stakeAmount - uint256(extra));
            rewardsDistributor.didAllocate(subjectType, subject, stakeAmount - uint256(extra), sharesAmount, allocator);
            emit AllocatedStake(subjectType, subject, true, stakeAmount - uint256(extra), _allocatedStake.balanceOf(activeSharesId));
            _unallocatedStake.mint(activeSharesId, uint256(extra));
            emit UnallocatedStake(subjectType, subject, true, uint256(extra), _unallocatedStake.balanceOf(activeSharesId));
        } else {
            _allocatedStake.mint(activeSharesId, stakeAmount);
            rewardsDistributor.didAllocate(subjectType, subject, stakeAmount, sharesAmount, allocator);
            emit AllocatedStake(subjectType, subject, true, stakeAmount, _allocatedStake.balanceOf(activeSharesId));
        }
    }
    function withdrawAllocation(
        uint256 activeSharesId,
        uint8 subjectType,
        uint256 subject,
        address allocator,
        uint256 stakeAmount,
        uint256 sharesAmount
    ) external onlyRole(STAKING_CONTRACT_ROLE) {
        uint256 oldUnallocated = _unallocatedStake.balanceOf(activeSharesId);
        int256 fromAllocated = int256(stakeAmount) - int256(oldUnallocated);
        if (fromAllocated > 0) {
            _allocatedStake.burn(activeSharesId, uint256(fromAllocated));
            rewardsDistributor.didUnallocate(subjectType, subject, uint256(fromAllocated), sharesAmount, allocator);
            emit AllocatedStake(subjectType, subject, false, uint256(fromAllocated), _allocatedStake.balanceOf(activeSharesId));
            _unallocatedStake.burn(activeSharesId, _unallocatedStake.balanceOf(activeSharesId));
            emit UnallocatedStake(subjectType, subject, false, oldUnallocated, 0);
        } else {
            _unallocatedStake.burn(activeSharesId, stakeAmount);
            rewardsDistributor.didUnallocate(subjectType, subject, 0, sharesAmount, allocator);
            emit UnallocatedStake(subjectType, subject, false, stakeAmount, _unallocatedStake.balanceOf(activeSharesId));
        }
    }
    function _allocationIncreaseChecks(
        uint8 subjectType,
        uint256 subject,
        SubjectStakeAgency agency,
        address allocator,
        uint256 amount
    ) private view returns (int256 extra, uint256 max) {
        uint256 subjects = 0;
        uint256 maxPerManaged = 0;
        uint256 currentlyAllocated = 0;
        if (agency == SubjectStakeAgency.DELEGATED) {
            if (!_subjectGateway.canManageAllocation(subjectType, subject, allocator)) revert SenderCannotAllocateFor(subjectType, subject);
            subjects = _subjectGateway.totalManagedSubjects(subjectType, subject);
            maxPerManaged = _subjectGateway.maxManagedStakeFor(subjectType, subject);
            currentlyAllocated = allocatedManagedStake(subjectType, subject);
        } else if (agency == SubjectStakeAgency.DELEGATOR) {
            uint8 delegatedSubjectType = getDelegatedSubjectType(subjectType);
            subjects = _subjectGateway.totalManagedSubjects(delegatedSubjectType, subject);
            if (subjects == 0) {
                revert CannotDelegateNoEnabledSubjects(delegatedSubjectType, subject);
            }
            maxPerManaged = _subjectGateway.maxManagedStakeFor(delegatedSubjectType, subject);
            if (
                allocatedStakeFor(delegatedSubjectType, subject) / subjects <
                _subjectGateway.minManagedStakeFor(delegatedSubjectType, subject)
            ) {
                revert CannotDelegateStakeUnderMin(delegatedSubjectType, subject);
            }
            currentlyAllocated = allocatedManagedStake(delegatedSubjectType, subject);
        }
        return (int256(currentlyAllocated + amount) - int256(maxPerManaged * subjects), maxPerManaged * subjects);
    }
    function didTransferShares(
        uint256 sharesId,
        uint8 subjectType,
        address from,
        address to,
        uint256 sharesAmount
    ) external {
        rewardsDistributor.didTransferShares(sharesId, subjectType, from, to, sharesAmount);
    }
}