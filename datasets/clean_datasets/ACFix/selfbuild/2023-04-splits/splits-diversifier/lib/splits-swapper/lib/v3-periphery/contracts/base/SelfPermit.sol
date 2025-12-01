pragma solidity >=0.5.0;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol';
import '../interfaces/ISelfPermit.sol';
import '../interfaces/external/IERC20PermitAllowed.sol';
abstract contract SelfPermit is ISelfPermit {
    function selfPermit(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable override {
        IERC20Permit(token).permit(msg.sender, address(this), value, deadline, v, r, s);
    }
    function selfPermitIfNecessary(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable override {
        if (IERC20(token).allowance(msg.sender, address(this)) < value) selfPermit(token, value, deadline, v, r, s);
    }
    function selfPermitAllowed(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable override {
        IERC20PermitAllowed(token).permit(msg.sender, address(this), nonce, expiry, true, v, r, s);
    }
    function selfPermitAllowedIfNecessary(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable override {
        if (IERC20(token).allowance(msg.sender, address(this)) < type(uint256).max)
            selfPermitAllowed(token, nonce, expiry, v, r, s);
    }
}