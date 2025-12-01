pragma solidity ^0.8.9;
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./StakingEscrow.sol";
import "./StakingEscrowUtils.sol";
import "../../errors/GeneralErrors.sol";
contract StakingEscrowFactory {
    FortaBridgedPolygon  public immutable token;
    FortaStaking  public immutable staking;
    address public immutable template;
    event NewStakingEscrow(address indexed escrow, address indexed vesting, address indexed manager);
    constructor(address __trustedForwarder, FortaStaking __staking) {
        if (__trustedForwarder == address(0)) revert ZeroAddress("__trustedForwarder");
        token    = FortaBridgedPolygon(address(__staking.stakedToken()));
        staking  = __staking;
        template = address(new StakingEscrow(
            __trustedForwarder,
            token,
            staking
        ));
    }
    function newWallet(
        address vesting,
        address manager
    ) public returns (address) {
        if (vesting == address(0)) revert ZeroAddress("vesting");
        if (manager == address(0)) revert ZeroAddress("manager");
        address instance = Clones.cloneDeterministic(
            template,
            StakingEscrowUtils.computeSalt(vesting, manager)
        );
        StakingEscrow(instance).initialize(vesting, manager);
        token.grantRole(token.WHITELIST_ROLE(), instance);
        emit NewStakingEscrow(instance, vesting, manager);
        return instance;
    }
    function predictWallet(
        address vesting,
        address manager
    ) public view returns (address) {
        return Clones.predictDeterministicAddress(
            template,
            StakingEscrowUtils.computeSalt(vesting, manager)
        );
    }
}