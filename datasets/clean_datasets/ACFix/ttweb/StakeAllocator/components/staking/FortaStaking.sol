pragma solidity ^0.8.9;
import "@openzeppelin/contracts/interfaces/draft-IERC2612.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Timers.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "./IStakeMigrator.sol";
import "./FortaStakingUtils.sol";
import "./SubjectTypeValidator.sol";
import "./allocation/IStakeAllocator.sol";
import "./stake_subjects/IStakeSubjectGateway.sol";
import "./slashing/ISlashingExecutor.sol";
import "../BaseComponentUpgradeable.sol";
import "../../tools/Distributions.sol";
contract FortaStaking is BaseComponentUpgradeable, ERC1155SupplyUpgradeable, SubjectTypeValidator, ISlashingExecutor, IStakeMigrator {
    using Distributions for Distributions.Balances;
    using Distributions for Distributions.SignedBalances;
    using Timers for Timers.Timestamp;
    using ERC165Checker for address;
    IERC20 public stakedToken;
    Distributions.Balances private _activeStake;
    Distributions.Balances private _inactiveStake;
    mapping(uint256 => mapping(address => Timers.Timestamp)) private _lockingDelay;
    Distributions.Balances private _rewards;
    mapping(uint256 => Distributions.SignedBalances) private _released;
    mapping(uint256 => bool) private _frozen;
    uint64 private _withdrawalDelay;
    address private _treasury;
    IStakeSubjectGateway public subjectGateway;
    uint256 public slashDelegatorsPercent;
    IStakeAllocator public allocator;
    uint256 public constant MIN_WITHDRAWAL_DELAY = 1 days;
    uint256 public constant MAX_WITHDRAWAL_DELAY = 90 days;
    uint256 public constant MAX_SLASHABLE_PERCENT = 90;
    uint256 private constant HUNDRED_PERCENT = 100;
    event StakeDeposited(uint8 indexed subjectType, uint256 indexed subject, address indexed account, uint256 amount);
    event WithdrawalInitiated(uint8 indexed subjectType, uint256 indexed subject, address indexed account, uint64 deadline);
    event WithdrawalExecuted(uint8 indexed subjectType, uint256 indexed subject, address indexed account);
    event Froze(uint8 indexed subjectType, uint256 indexed subject, address indexed by, bool isFrozen);
    event Slashed(uint8 indexed subjectType, uint256 indexed subject, address indexed by, uint256 value);
    event SlashedShareSent(uint8 indexed subjectType, uint256 indexed subject, address indexed by, uint256 value);
    event DelaySet(uint256 newWithdrawalDelay);
    event TreasurySet(address newTreasury);
    event StakeHelpersConfigured(address indexed subjectGateway, address indexed allocator);
    event MaxStakeReached(uint8 indexed subjectType, uint256 indexed subject);
    event TokensSwept(address indexed token, address to, uint256 amount);
    event SlashDelegatorsPercentSet(uint256 percent);
    error WithdrawalNotReady();
    error SlashingOver90Percent();
    error WithdrawalSharesNotTransferible();
    error FrozenSubject();
    error NoActiveShares();
    error NoInactiveShares();
    error StakeInactiveOrSubjectNotFound();
    string public constant version = "0.1.2";
    constructor(address _forwarder) initializer ForwardedContext(_forwarder) {}
    function initialize(
        address __manager,
        IERC20 __stakedToken,
        uint64 __withdrawalDelay,
        address __treasury
    ) public initializer {
        if (__treasury == address(0)) revert ZeroAddress("__treasury");
        if (address(__stakedToken) == address(0)) revert ZeroAddress("__stakedToken");
        __BaseComponentUpgradeable_init(__manager);
        __ERC1155_init("");
        __ERC1155Supply_init();
        _withdrawalDelay = __withdrawalDelay;
        _treasury = __treasury;
        stakedToken = IERC20(__stakedToken);
        emit DelaySet(__withdrawalDelay);
        emit TreasurySet(__treasury);
    }
    function treasury() public view returns (address) {
        return _treasury;
    }
    function activeStakeFor(uint8 subjectType, uint256 subject) public view returns (uint256) {
        return _activeStake.balanceOf(FortaStakingUtils.subjectToActive(subjectType, subject));
    }
    function totalActiveStake() public view returns (uint256) {
        return _activeStake.totalSupply();
    }
    function inactiveStakeFor(uint8 subjectType, uint256 subject) external view returns (uint256) {
        return _inactiveStake.balanceOf(FortaStakingUtils.subjectToInactive(subjectType, subject));
    }
    function totalInactiveStake() public view returns (uint256) {
        return _inactiveStake.totalSupply();
    }
    function sharesOf(
        uint8 subjectType,
        uint256 subject,
        address account
    ) public view returns (uint256) {
        return balanceOf(account, FortaStakingUtils.subjectToActive(subjectType, subject));
    }
    function totalShares(uint8 subjectType, uint256 subject) external view returns (uint256) {
        return totalSupply(FortaStakingUtils.subjectToActive(subjectType, subject));
    }
    function inactiveSharesOf(
        uint8 subjectType,
        uint256 subject,
        address account
    ) external view returns (uint256) {
        return balanceOf(account, FortaStakingUtils.subjectToInactive(subjectType, subject));
    }
    function totalInactiveShares(uint8 subjectType, uint256 subject) external view returns (uint256) {
        return totalSupply(FortaStakingUtils.subjectToInactive(subjectType, subject));
    }
    function isFrozen(uint8 subjectType, uint256 subject) public view returns (bool) {
        return _frozen[FortaStakingUtils.subjectToActive(subjectType, subject)];
    }
    function deposit(
        uint8 subjectType,
        uint256 subject,
        uint256 stakeValue
    ) external onlyValidSubjectType(subjectType) notAgencyType(subjectType, SubjectStakeAgency.MANAGED) returns (uint256) {
        if (address(subjectGateway) == address(0)) revert ZeroAddress("subjectGateway");
        if (!subjectGateway.isStakeActivatedFor(subjectType, subject)) revert StakeInactiveOrSubjectNotFound();
        address staker = _msgSender();
        uint256 activeSharesId = FortaStakingUtils.subjectToActive(subjectType, subject);
        bool reachedMax;
        (stakeValue, reachedMax) = _getInboundStake(subjectType, subject, stakeValue);
        if (reachedMax) {
            emit MaxStakeReached(subjectType, subject);
        }
        uint256 sharesValue = stakeToActiveShares(activeSharesId, stakeValue);
        SafeERC20.safeTransferFrom(stakedToken, staker, address(this), stakeValue);
        _activeStake.mint(activeSharesId, stakeValue);
        _mint(staker, activeSharesId, sharesValue, new bytes(0));
        emit StakeDeposited(subjectType, subject, staker, stakeValue);
        allocator.depositAllocation(activeSharesId, subjectType, subject, staker, stakeValue, sharesValue);
        return sharesValue;
    }
    function migrate(
        uint8 oldSubjectType,
        uint256 oldSubject,
        uint8 newSubjectType,
        uint256 newSubject,
        address staker
    ) external onlyRole(SCANNER_2_SCANNER_POOL_MIGRATOR_ROLE) {
        if (oldSubjectType != SCANNER_SUBJECT) revert InvalidSubjectType(oldSubjectType); 
        if (newSubjectType != SCANNER_POOL_SUBJECT) revert InvalidSubjectType(newSubjectType); 
        if (isFrozen(oldSubjectType, oldSubject)) revert FrozenSubject();
        uint256 oldSharesId = FortaStakingUtils.subjectToActive(oldSubjectType, oldSubject);
        uint256 oldShares = balanceOf(staker, oldSharesId);
        uint256 stake = activeSharesToStake(oldSharesId, oldShares);
        uint256 newSharesId = FortaStakingUtils.subjectToActive(newSubjectType, newSubject);
        uint256 newShares = stakeToActiveShares(newSharesId, stake);
        _activeStake.burn(oldSharesId, stake);
        _activeStake.mint(newSharesId, stake);
        _burn(staker, oldSharesId, oldShares);
        _mint(staker, newSharesId, newShares, new bytes(0));
        emit StakeDeposited(newSubjectType, newSubject, staker, stake);
        allocator.depositAllocation(newSharesId, newSubjectType, newSubject, staker, stake, newShares);
    }
    function _getInboundStake(
        uint8 subjectType,
        uint256 subject,
        uint256 stakeValue
    ) private view returns (uint256, bool) {
        uint256 max = subjectGateway.maxStakeFor(subjectType, subject);
        if (activeStakeFor(subjectType, subject) >= max) {
            return (0, true);
        } else {
            uint256 stakeLeft = max - activeStakeFor(subjectType, subject);
            return (
                Math.min(
                    stakeValue, 
                    stakeLeft 
                ),
                activeStakeFor(subjectType, subject) + stakeValue >= max
            );
        }
    }
    function initiateWithdrawal(
        uint8 subjectType,
        uint256 subject,
        uint256 sharesValue
    ) external onlyValidSubjectType(subjectType) returns (uint64) {
        address staker = _msgSender();
        uint256 activeSharesId = FortaStakingUtils.subjectToActive(subjectType, subject);
        if (balanceOf(staker, activeSharesId) == 0) revert NoActiveShares();
        uint64 deadline = SafeCast.toUint64(block.timestamp) + _withdrawalDelay;
        _lockingDelay[activeSharesId][staker].setDeadline(deadline);
        uint256 activeShares = Math.min(sharesValue, balanceOf(staker, activeSharesId));
        uint256 stakeValue = activeSharesToStake(activeSharesId, activeShares);
        uint256 inactiveShares = stakeToInactiveShares(FortaStakingUtils.activeToInactive(activeSharesId), stakeValue);
        SubjectStakeAgency agency = getSubjectTypeAgency(subjectType);
        _activeStake.burn(activeSharesId, stakeValue);
        _inactiveStake.mint(FortaStakingUtils.activeToInactive(activeSharesId), stakeValue);
        _burn(staker, activeSharesId, activeShares);
        _mint(staker, FortaStakingUtils.activeToInactive(activeSharesId), inactiveShares, new bytes(0));
        if (agency == SubjectStakeAgency.DELEGATED || agency == SubjectStakeAgency.DELEGATOR) {
            allocator.withdrawAllocation(activeSharesId, subjectType, subject, staker, stakeValue, activeShares);
        }
        emit WithdrawalInitiated(subjectType, subject, staker, deadline);
        return deadline;
    }
    function withdraw(uint8 subjectType, uint256 subject) external onlyValidSubjectType(subjectType) returns (uint256) {
        address staker = _msgSender();
        uint256 inactiveSharesId = FortaStakingUtils.subjectToInactive(subjectType, subject);
        if (balanceOf(staker, inactiveSharesId) == 0) revert NoInactiveShares();
        if (_frozen[FortaStakingUtils.inactiveToActive(inactiveSharesId)]) revert FrozenSubject();
        Timers.Timestamp storage timer = _lockingDelay[FortaStakingUtils.inactiveToActive(inactiveSharesId)][staker];
        if (!timer.isExpired()) revert WithdrawalNotReady();
        timer.reset();
        emit WithdrawalExecuted(subjectType, subject, staker);
        uint256 inactiveShares = balanceOf(staker, inactiveSharesId);
        uint256 stakeValue = inactiveSharesToStake(inactiveSharesId, inactiveShares);
        _inactiveStake.burn(inactiveSharesId, stakeValue);
        _burn(staker, inactiveSharesId, inactiveShares);
        SafeERC20.safeTransfer(stakedToken, staker, stakeValue);
        return stakeValue;
    }
    function slash(
        uint8 subjectType,
        uint256 subject,
        uint256 stakeValue,
        address proposer,
        uint256 proposerPercent
    ) external override onlyRole(SLASHER_ROLE) notAgencyType(subjectType, SubjectStakeAgency.DELEGATOR) returns (uint256) {
        uint256 activeSharesId = FortaStakingUtils.subjectToActive(subjectType, subject);
        if (getSubjectTypeAgency(subjectType) == SubjectStakeAgency.DELEGATED) {
            uint256 delegatorSlashValue = Math.mulDiv(stakeValue, slashDelegatorsPercent, HUNDRED_PERCENT);
            uint256 delegatedSlashValue = stakeValue - delegatorSlashValue;
            _slash(activeSharesId, subjectType, subject, delegatedSlashValue);
            if (delegatorSlashValue > 0) {
                uint8 delegatorType = getDelegatorSubjectType(subjectType);
                uint256 activeDelegatorSharesId = FortaStakingUtils.subjectToActive(delegatorType, subject);
                _slash(activeDelegatorSharesId, delegatorType, subject, delegatorSlashValue);
            }
        } else {
            _slash(activeSharesId, subjectType, subject, stakeValue);
        }
        uint256 proposerShare = Math.mulDiv(stakeValue, proposerPercent, HUNDRED_PERCENT);
        if (proposerShare > 0) {
            if (proposer == address(0)) revert ZeroAddress("proposer");
            SafeERC20.safeTransfer(stakedToken, proposer, proposerShare);
        }
        SafeERC20.safeTransfer(stakedToken, _treasury, stakeValue - proposerShare);
        emit SlashedShareSent(subjectType, subject, proposer, proposerShare);
        return stakeValue;
    }
    function _slash(
        uint256 activeSharesId,
        uint8 subjectType,
        uint256 subject,
        uint256 stakeValue
    ) private {
        uint256 activeStake = _activeStake.balanceOf(activeSharesId);
        uint256 inactiveStake = _inactiveStake.balanceOf(FortaStakingUtils.activeToInactive(activeSharesId));
        uint256 maxSlashableStake = Math.mulDiv(activeStake + inactiveStake, MAX_SLASHABLE_PERCENT, HUNDRED_PERCENT);
        if (stakeValue > maxSlashableStake) revert SlashingOver90Percent();
        uint256 slashFromActive = Math.mulDiv(activeStake, stakeValue, activeStake + inactiveStake);
        uint256 slashFromInactive = stakeValue - slashFromActive;
        _activeStake.burn(activeSharesId, slashFromActive);
        _inactiveStake.burn(FortaStakingUtils.activeToInactive(activeSharesId), slashFromInactive);
        SubjectStakeAgency subjectAgency = getSubjectTypeAgency(subjectType);
        if (subjectAgency == SubjectStakeAgency.DELEGATED || subjectAgency == SubjectStakeAgency.DELEGATOR) {
            allocator.withdrawAllocation(activeSharesId, subjectType, subject, address(0), slashFromActive, 0);
        }
        emit Slashed(subjectType, subject, _msgSender(), stakeValue);
    }
    function freeze(
        uint8 subjectType,
        uint256 subject,
        bool frozen
    ) external override onlyRole(SLASHER_ROLE) onlyValidSubjectType(subjectType) {
        _frozen[FortaStakingUtils.subjectToActive(subjectType, subject)] = frozen;
        emit Froze(subjectType, subject, _msgSender(), frozen);
    }
    function sweep(IERC20 token, address recipient) external onlyRole(SWEEPER_ROLE) returns (uint256) {
        uint256 amount = token.balanceOf(address(this));
        if (token == stakedToken) {
            amount -= totalActiveStake();
            amount -= totalInactiveStake();
        }
        SafeERC20.safeTransfer(token, recipient, amount);
        emit TokensSwept(address(token), recipient, amount);
        return amount;
    }
    function relayPermit(
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC2612(address(stakedToken)).permit(_msgSender(), address(this), value, deadline, v, r, s);
    }
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        for (uint256 i = 0; i < ids.length; i++) {
            if (FortaStakingUtils.isActive(ids[i])) {
                uint8 subjectType = FortaStakingUtils.subjectTypeOfShares(ids[i]);
                if (subjectType == DELEGATOR_SCANNER_POOL_SUBJECT && to != address(0) && from != address(0)) {
                    allocator.didTransferShares(ids[i], subjectType, from, to, amounts[i]);
                }
            } else {
                if (!(from == address(0) || to == address(0))) revert WithdrawalSharesNotTransferible();
            }
        }
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
    function stakeToActiveShares(uint256 activeSharesId, uint256 amount) public view returns (uint256) {
        uint256 activeStake = _activeStake.balanceOf(activeSharesId);
        return activeStake == 0 ? amount : Math.mulDiv(totalSupply(activeSharesId), amount, activeStake);
    }
    function stakeToInactiveShares(uint256 inactiveSharesId, uint256 amount) public view returns (uint256) {
        uint256 inactiveStake = _inactiveStake.balanceOf(inactiveSharesId);
        return inactiveStake == 0 ? amount : Math.mulDiv(totalSupply(inactiveSharesId), amount, inactiveStake);
    }
    function activeSharesToStake(uint256 activeSharesId, uint256 amount) public view returns (uint256) {
        uint256 activeSupply = totalSupply(activeSharesId);
        return activeSupply == 0 ? 0 : Math.mulDiv(_activeStake.balanceOf(activeSharesId), amount, activeSupply);
    }
    function inactiveSharesToStake(uint256 inactiveSharesId, uint256 amount) public view returns (uint256) {
        uint256 inactiveSupply = totalSupply(inactiveSharesId);
        return inactiveSupply == 0 ? 0 : Math.mulDiv(_inactiveStake.balanceOf(inactiveSharesId), amount, inactiveSupply);
    }
    function setDelay(uint64 newDelay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newDelay < MIN_WITHDRAWAL_DELAY) revert AmountTooSmall(newDelay, MIN_WITHDRAWAL_DELAY);
        if (newDelay > MAX_WITHDRAWAL_DELAY) revert AmountTooLarge(newDelay, MAX_WITHDRAWAL_DELAY);
        _withdrawalDelay = newDelay;
        emit DelaySet(newDelay);
    }
    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress("newTreasury");
        _treasury = newTreasury;
        emit TreasurySet(newTreasury);
    }
    function configureStakeHelpers(IStakeSubjectGateway _subjectGateway, IStakeAllocator _allocator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(_subjectGateway) == address(0)) revert ZeroAddress("_subjectGateway");
        if (address(_allocator) == address(0)) revert ZeroAddress("_allocator");
        subjectGateway = _subjectGateway;
        allocator = _allocator;
        emit StakeHelpersConfigured(address(_subjectGateway), address(_allocator));
    }
    function setSlashDelegatorsPercent(uint256 percent) external onlyRole(STAKING_ADMIN_ROLE) {
        slashDelegatorsPercent = percent;
        emit SlashDelegatorsPercentSet(percent);
    }
    function setURI(string memory newUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newUri);
    }
    function _msgSender() internal view virtual override(ContextUpgradeable, BaseComponentUpgradeable) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(ContextUpgradeable, BaseComponentUpgradeable) returns (bytes calldata) {
        return super._msgData();
    }
    uint256[38] private __gap;
}