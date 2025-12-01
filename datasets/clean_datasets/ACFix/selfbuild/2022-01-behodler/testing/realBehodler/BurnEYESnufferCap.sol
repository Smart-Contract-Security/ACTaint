pragma solidity ^0.8.4;
enum FeeExemption{
    NO_EXEMPTIONS,
    SENDER_EXEMPT,
    SENDER_AND_RECEIVER_EXEMPT,
    REDEEM_EXEMPT_AND_SENDER_EXEMPT,
    REDEEM_EXEMPT_AND_SENDER_AND_RECEIVER_EXEMPT,
    RECEIVER_EXEMPT,
    REDEEM_EXEMPT_AND_RECEIVER_EXEMPT,
    REDEEM_EXEMPT_ONLY
}
abstract contract LiquidityReceiverLike {
    function setFeeExemptionStatusOnPyroForContract(
        address pyroToken,
        address target,
        FeeExemption exemption
    ) public virtual;
    function setPyroTokenLoanOfficer(address pyroToken, address loanOfficer)
        public
        virtual;
    function getPyroToken(address baseToken)
        public
        view
        virtual
        returns (address);
    function registerPyroToken(
        address baseToken,
        string memory name,
        string memory symbol
    ) public virtual;
    function drain(address baseToken) external virtual returns (uint);
}
abstract contract SnufferCap {
    LiquidityReceiverLike public _liquidityReceiver;
    constructor(address liquidityReceiver) {
        _liquidityReceiver = LiquidityReceiverLike(liquidityReceiver);
    }
    function snuff (address pyroToken, address targetContract, FeeExemption exempt) public virtual returns (bool);
    function _snuff(address pyroToken, address targetContract, FeeExemption exempt)
        internal
    {
        _liquidityReceiver.setFeeExemptionStatusOnPyroForContract(pyroToken,targetContract,exempt);
    }
}
interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    event Transfer(
        address indexed from,
        address indexed to,
        uint128 value,
        uint128 burnt
    );
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}
abstract contract Burnable is IERC20 {
    function burn (uint value) public virtual;
}
contract BurnEYESnufferCap is SnufferCap {
    Burnable eye;
    constructor(address EYE, address receiver) SnufferCap(receiver) {
        eye = Burnable(EYE);
    }
    function snuff(
        address pyroToken,
        address targetContract,
        FeeExemption exempt
    ) public override returns (bool) {
        require(eye.transferFrom(msg.sender,address(this), 1000 * (1 ether)),"ERC20: transfer failed.");
        uint balance = eye.balanceOf(address(this));
        eye.burn(balance);
        _snuff(pyroToken, targetContract, exempt);
        return true;
    }
}