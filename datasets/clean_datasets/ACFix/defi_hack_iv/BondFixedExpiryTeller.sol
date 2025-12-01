pragma solidity 0.8.15;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ClonesWithImmutableArgs} from "clones/ClonesWithImmutableArgs.sol";
import {BondBaseTeller, IBondAggregator, Authority} from "./bases/BondBaseTeller.sol";
import {IBondFixedExpiryTeller} from "./interfaces/IBondFixedExpiryTeller.sol";
import {ERC20BondToken} from "./ERC20BondToken.sol";
import {TransferHelper} from "./lib/TransferHelper.sol";
import {FullMath} from "./lib/FullMath.sol";
contract BondFixedExpiryTeller is BondBaseTeller, IBondFixedExpiryTeller {
    using TransferHelper for ERC20;
    using FullMath for uint256;
    using ClonesWithImmutableArgs for address;
    event ERC20BondTokenCreated(
        ERC20BondToken bondToken,
        ERC20 indexed underlying,
        uint48 indexed expiry
    );
    mapping(ERC20 => mapping(uint48 => ERC20BondToken)) public bondTokens;
    ERC20BondToken public immutable bondTokenImplementation;
    constructor(
        address protocol_,
        IBondAggregator aggregator_,
        address guardian_,
        Authority authority_
    ) BondBaseTeller(protocol_, aggregator_, guardian_, authority_) {
        bondTokenImplementation = new ERC20BondToken();
    }
    function _handlePayout(
        address recipient_,
        uint256 payout_,
        ERC20 underlying_,
        uint48 vesting_
    ) internal override returns (uint48 expiry) {
        if (vesting_ > uint48(block.timestamp)) {
            expiry = vesting_;
            bondTokens[underlying_][expiry].mint(recipient_, payout_);
        } else {
            underlying_.safeTransfer(recipient_, payout_);
        }
    }
    function create(
        ERC20 underlying_,
        uint48 expiry_,
        uint256 amount_
    ) external override nonReentrant returns (ERC20BondToken, uint256) {
        ERC20BondToken bondToken = bondTokens[underlying_][expiry_];
        if (bondToken == ERC20BondToken(address(0x00)))
            revert Teller_TokenDoesNotExist(underlying_, expiry_);
        uint256 oldBalance = underlying_.balanceOf(address(this));
        underlying_.transferFrom(msg.sender, address(this), amount_);
        if (underlying_.balanceOf(address(this)) < oldBalance + amount_)
            revert Teller_UnsupportedToken();
        if (protocolFee > createFeeDiscount) {
            uint256 feeAmount = amount_.mulDiv(protocolFee - createFeeDiscount, FEE_DECIMALS);
            rewards[_protocol][underlying_] += feeAmount;
            bondToken.mint(msg.sender, amount_ - feeAmount);
            return (bondToken, amount_ - feeAmount);
        } else {
            bondToken.mint(msg.sender, amount_);
            return (bondToken, amount_);
        }
    }
    function redeem(ERC20BondToken token_, uint256 amount_) external override nonReentrant {
        if (uint48(block.timestamp) < token_.expiry())
            revert Teller_TokenNotMatured(token_.expiry());
        token_.burn(msg.sender, amount_);
        token_.underlying().transfer(msg.sender, amount_);
    }
    function deploy(ERC20 underlying_, uint48 expiry_)
        external
        override
        nonReentrant
        returns (ERC20BondToken)
    {
        ERC20BondToken bondToken = bondTokens[underlying_][expiry_];
        if (bondToken == ERC20BondToken(address(0))) {
            (string memory name, string memory symbol) = _getNameAndSymbol(underlying_, expiry_);
            bytes memory tokenData = abi.encodePacked(
                bytes32(bytes(name)),
                bytes32(bytes(symbol)),
                underlying_.decimals(),
                underlying_,
                uint256(expiry_),
                address(this)
            );
            bondToken = ERC20BondToken(address(bondTokenImplementation).clone(tokenData));
            bondTokens[underlying_][expiry_] = bondToken;
            emit ERC20BondTokenCreated(bondToken, underlying_, expiry_);
        }
        return bondToken;
    }
    function getBondTokenForMarket(uint256 id_) external view override returns (ERC20BondToken) {
        (, , ERC20 underlying, , uint48 vesting, ) = _aggregator
            .getAuctioneer(id_)
            .getMarketInfoForPurchase(id_);
        return bondTokens[underlying][vesting];
    }
}