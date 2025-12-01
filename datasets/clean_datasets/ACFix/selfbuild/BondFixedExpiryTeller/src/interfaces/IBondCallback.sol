pragma solidity >=0.8.0;
import {ERC20} from "solmate/tokens/ERC20.sol";
interface IBondCallback {
    function callback(
        uint256 id_,
        uint256 inputAmount_,
        uint256 outputAmount_
    ) external;
    function amountsForMarket(uint256 id_) external view returns (uint256 in_, uint256 out_);
    function whitelist(address teller_, uint256 id_) external;
    function withdraw(
        address to_,
        ERC20 token_,
        uint256 amount_
    ) external;
    function deposit(ERC20 token_, uint256 amount_) external;
}