pragma solidity >=0.8.0;
import {ERC20BondToken} from "../ERC20BondToken.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
interface IBondFixedExpiryTeller {
    function redeem(ERC20BondToken token_, uint256 amount_) external;
    function create(
        ERC20 underlying_,
        uint48 expiry_,
        uint256 amount_
    ) external returns (ERC20BondToken, uint256);
    function deploy(ERC20 underlying_, uint48 expiry_) external returns (ERC20BondToken);
    function getBondTokenForMarket(uint256 id_) external view returns (ERC20BondToken);
}