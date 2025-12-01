pragma solidity >=0.8.0;
import {ERC20} from "solmate/tokens/ERC20.sol";
interface IBondTeller {
    function purchase(
        address recipient_,
        address referrer_,
        uint256 id_,
        uint256 amount_,
        uint256 minAmountOut_
    ) external returns (uint256, uint48);
    function getFee(address referrer_) external view returns (uint48);
    function setProtocolFee(uint48 fee_) external;
    function setReferrerFee(uint48 fee_) external;
    function claimFees(ERC20[] memory tokens_, address to_) external;
}