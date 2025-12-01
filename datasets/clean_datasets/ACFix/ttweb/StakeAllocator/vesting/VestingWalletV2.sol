pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./escrow/StakingEscrowUtils.sol";
import "./IRootChainManager.sol";
import "./VestingWalletV1.sol";
contract VestingWalletV2 is VestingWalletV1 {
    using SafeCast for int256;
    using SafeCast for uint256;
    IRootChainManager public immutable rootChainManager;
    address           public immutable l1Token;
    address           public immutable l2EscrowFactory;
    address           public immutable l2EscrowTemplate;
    uint256           public           historicalBalanceMin;
    event TokensBridged(address indexed l2Escrow, address indexed l2Manager, uint256 amount);
    event HistoricalBalanceMinChanged(uint256 newValue, uint256 oldValue);
    error BridgingToContract();
    constructor(
        address _rootChainManager,
        address _l1Token,
        address _l2EscrowFactory,
        address _l2EscrowTemplate
    ) { 
        rootChainManager = IRootChainManager(_rootChainManager);
        l1Token          = _l1Token;
        l2EscrowFactory  = _l2EscrowFactory;
        l2EscrowTemplate = _l2EscrowTemplate;
    }
    function bridge(uint256 amount)
        public
        virtual
    {
        if (Address.isContract(beneficiary())) revert BridgingToContract();
        bridge(amount, beneficiary());
    }
    function bridge(uint256 amount, address l2Manager)
        public
        virtual
        onlyBeneficiary()
    {
        if (amount == 0) revert ZeroAmount("");
        if (l2Manager== address(0)) revert ZeroAddress("l2Manager");
        historicalBalanceMin = _historicalBalance(l1Token);
        address l2Escrow = Clones.predictDeterministicAddress(
            l2EscrowTemplate,
            StakingEscrowUtils.computeSalt(address(this), l2Manager),
            l2EscrowFactory
        );
        address predicate = rootChainManager.typeToPredicate(rootChainManager.tokenToType(l1Token));
        IERC20(l1Token).approve(predicate, amount);
        rootChainManager.depositFor(l2Escrow, l1Token, abi.encode(amount));
        IERC20(address(l1Token)).approve(predicate, 0);
        emit TokensBridged(l2Escrow, l2Manager, amount);
    }
    function _historicalBalance(address token)
        internal
        virtual
        override
        view
        returns (uint256)
    {
        if (token == l1Token) {
            return Math.max(super._historicalBalance(token), historicalBalanceMin);
        } else {
            return super._historicalBalance(token);
        }
    }
    function setHistoricalBalanceMin(uint256 value)
        public
        onlyOwner()
    {
        emit HistoricalBalanceMinChanged(value, historicalBalanceMin);
        historicalBalanceMin = value;
    }
    function updateHistoricalBalanceMin(int256 update)
        public
        onlyOwner()
    {
        setHistoricalBalanceMin((historicalBalanceMin.toInt256() + update).toUint256());
    }
    uint256[45] private __gap;
}