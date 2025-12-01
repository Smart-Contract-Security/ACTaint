pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../../token/FortaBridgedPolygon.sol";
import "../../components/staking/FortaStaking.sol";
import "../../components/utils/ForwardedContext.sol";
import "../../components/staking/rewards/IRewardReceiver.sol";
import "../../errors/GeneralErrors.sol";
contract StakingEscrow is Initializable, ERC165, IRewardReceiver, ForwardedContext, ERC1155Receiver {
    FortaBridgedPolygon public immutable l2token;
    FortaStaking public immutable l2staking;
    address      public           l1vesting;
    address      public           l2manager;
    uint256      public           pendingReward;
    error DontBridgeOrStakeRewards();
    modifier onlyManager() {
        if (_msgSender() != l2manager) revert DoesNotHaveAccess(_msgSender(), "l2Manager");
        _;
    }
    modifier vestingBalance(uint256 amount) {
        if (l2token.balanceOf(address(this)) < amount + pendingReward) revert DontBridgeOrStakeRewards();
        _;
    }
    constructor(
        address      __trustedForwarder,
        FortaBridgedPolygon __token,
        FortaStaking __staking
    ) ForwardedContext(__trustedForwarder) initializer() {
        l2token   = __token;
        l2staking = __staking;
    }
    function initialize(
        address __l1vesting,
        address __l2manager
    ) public initializer {
        if (__l1vesting == address(0)) revert ZeroAddress("__l1vesting");
        if (__l2manager == address(0)) revert ZeroAddress("__l2manager");
        l1vesting = __l1vesting;
        l2manager = __l2manager;
    }
    function deposit(uint8 subjectType, uint256 subject, uint256 stakeValue) public onlyManager() vestingBalance(stakeValue) returns (uint256) {
        IERC20(address(l2token)).approve(address(l2staking), stakeValue);
        uint256 shares = l2staking.deposit(subjectType, subject, stakeValue);
        IERC20(address(l2token)).approve(address(l2staking), 0);
        return shares;
    }
    function deposit(uint8 subjectType, uint256 subject) public returns (uint256) {
        return deposit(subjectType, subject, l2token.balanceOf(address(this)) - pendingReward);
    }
    function initiateWithdrawal(uint8 subjectType, uint256 subject, uint256 sharesValue) public onlyManager() returns (uint64) {
        return l2staking.initiateWithdrawal(subjectType, subject, sharesValue);
    }
    function initiateWithdrawal(uint8 subjectType, uint256 subject) public returns (uint64) {
        return initiateWithdrawal(
            subjectType,
            subject,
            l2staking.sharesOf(subjectType, subject, address(this))
        );
    }
    function withdraw(uint8 subjectType, uint256 subject) public onlyManager() returns (uint256) {
        return l2staking.withdraw(subjectType, subject);
    }
    function claimReward(uint8 subjectType, uint256 subject) public returns (uint256) {
    }
    function release(address releaseToken, address receiver, uint256 amount) public onlyManager() {
        if (address(l2token) == releaseToken) {
            pendingReward -= amount; 
        }
        SafeERC20.safeTransfer(
            IERC20(releaseToken),
            receiver,
            amount
        );
    }
    function releaseAllReward(address receiver) public {
        release(address(l2token), receiver, pendingReward);
    }
    function bridge(uint256 amount) public onlyManager() vestingBalance(amount) {
        if (amount == 0) revert ZeroAmount("amount");
        l2token.withdrawTo(amount, l1vesting);
    }
    function bridge() public {
        bridge(l2token.balanceOf(address(this)) - pendingReward);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, ERC1155Receiver) returns (bool) {
        return
            interfaceId == type(IRewardReceiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }
    function onRewardReceived(uint8, uint256, uint256 amount) public {
        if (msg.sender != address(l2staking)) revert DoesNotHaveAccess(msg.sender, "l2staking");
        pendingReward += amount;
    }
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external view returns (bytes4) {
        if (msg.sender != address(l2staking)) revert DoesNotHaveAccess(msg.sender, "l2staking");
        return this.onERC1155Received.selector;
    }
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external view returns (bytes4) {
        if (msg.sender != address(l2staking)) revert DoesNotHaveAccess(msg.sender, "l2staking");
        return this.onERC1155BatchReceived.selector;
    }
}