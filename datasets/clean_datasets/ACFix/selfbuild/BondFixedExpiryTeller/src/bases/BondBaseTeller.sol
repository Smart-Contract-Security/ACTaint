pragma solidity 0.8.15;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";
import {IBondTeller} from "../interfaces/IBondTeller.sol";
import {IBondCallback} from "../interfaces/IBondCallback.sol";
import {IBondAggregator} from "../interfaces/IBondAggregator.sol";
import {IBondAuctioneer} from "../interfaces/IBondAuctioneer.sol";
import {TransferHelper} from "../lib/TransferHelper.sol";
import {FullMath} from "../lib/FullMath.sol";
abstract contract BondBaseTeller is IBondTeller, Auth, ReentrancyGuard {
    using TransferHelper for ERC20;
    using FullMath for uint256;
    error Teller_InvalidCallback();
    error Teller_TokenNotMatured(uint48 maturesOn);
    error Teller_NotAuthorized();
    error Teller_TokenDoesNotExist(ERC20 underlying, uint48 expiry);
    error Teller_UnsupportedToken();
    error Teller_InvalidParams();
    event Bonded(uint256 indexed id, address indexed referrer, uint256 amount, uint256 payout);
    mapping(address => uint48) public referrerFees;
    uint48 public protocolFee;
    uint48 public createFeeDiscount;
    uint48 public constant FEE_DECIMALS = 1e5; 
    mapping(address => mapping(ERC20 => uint256)) public rewards;
    address internal immutable _protocol;
    IBondAggregator internal immutable _aggregator;
    constructor(
        address protocol_,
        IBondAggregator aggregator_,
        address guardian_,
        Authority authority_
    ) Auth(guardian_, authority_) {
        _protocol = protocol_;
        _aggregator = aggregator_;
        protocolFee = 0;
    }
    function setReferrerFee(uint48 fee_) external override {
        if (fee_ > 5e4) revert Teller_InvalidParams();
        referrerFees[msg.sender] = fee_;
    }
    function setProtocolFee(uint48 fee_) external override requiresAuth {
        protocolFee = fee_;
    }
    function claimFees(ERC20[] memory tokens_, address to_) external override {
        uint256 len = tokens_.length;
        for (uint256 i; i < len; ++i) {
            ERC20 token = tokens_[i];
            uint256 send = rewards[msg.sender][token];
            rewards[msg.sender][token] = 0;
            token.safeTransfer(to_, send);
        }
    }
    function getFee(address referrer_) external view returns (uint48) {
        return protocolFee + referrerFees[referrer_];
    }
    function purchase(
        address recipient_,
        address referrer_,
        uint256 id_,
        uint256 amount_,
        uint256 minAmountOut_
    ) external virtual nonReentrant returns (uint256, uint48) {
        ERC20 payoutToken;
        ERC20 quoteToken;
        uint48 vesting;
        uint256 payout;
        uint256 toReferrer = amount_.mulDiv(referrerFees[referrer_], FEE_DECIMALS);
        uint256 toProtocol = amount_.mulDiv(protocolFee + referrerFees[referrer_], FEE_DECIMALS) -
            toReferrer;
        {
            IBondAuctioneer auctioneer = _aggregator.getAuctioneer(id_);
            address owner;
            (owner, , payoutToken, quoteToken, vesting, ) = auctioneer.getMarketInfoForPurchase(
                id_
            );
            uint256 amountLessFee = amount_ - toReferrer - toProtocol;
            payout = auctioneer.purchaseBond(id_, amountLessFee, minAmountOut_);
        }
        rewards[referrer_][quoteToken] += toReferrer;
        rewards[_protocol][quoteToken] += toProtocol;
        _handleTransfers(id_, amount_, payout, toReferrer + toProtocol);
        uint48 expiry = _handlePayout(recipient_, payout, payoutToken, vesting);
        emit Bonded(id_, referrer_, amount_, payout);
        return (payout, expiry);
    }
    function _handleTransfers(
        uint256 id_,
        uint256 amount_,
        uint256 payout_,
        uint256 feePaid_
    ) internal {
        (address owner, address callbackAddr, ERC20 payoutToken, ERC20 quoteToken, , ) = _aggregator
            .getAuctioneer(id_)
            .getMarketInfoForPurchase(id_);
        uint256 amountLessFee = amount_ - feePaid_;
        uint256 quoteBalance = quoteToken.balanceOf(address(this));
        quoteToken.safeTransferFrom(msg.sender, address(this), amount_);
        if (quoteToken.balanceOf(address(this)) < quoteBalance + amount_)
            revert Teller_UnsupportedToken();
        if (callbackAddr != address(0)) {
            quoteToken.safeTransfer(callbackAddr, amountLessFee);
            uint256 payoutBalance = payoutToken.balanceOf(address(this));
            IBondCallback(callbackAddr).callback(id_, amountLessFee, payout_);
            if (payoutToken.balanceOf(address(this)) < (payoutBalance + payout_))
                revert Teller_InvalidCallback();
        } else {
            uint256 payoutBalance = payoutToken.balanceOf(address(this));
            payoutToken.safeTransferFrom(owner, address(this), payout_);
            if (payoutToken.balanceOf(address(this)) < (payoutBalance + payout_))
                revert Teller_UnsupportedToken();
            quoteToken.safeTransfer(owner, amountLessFee);
        }
    }
    function _handlePayout(
        address recipient_,
        uint256 payout_,
        ERC20 underlying_,
        uint48 vesting_
    ) internal virtual returns (uint48 expiry);
    function _getNameAndSymbol(ERC20 underlying_, uint256 expiry_)
        internal
        view
        returns (string memory name, string memory symbol)
    {
        uint256 year;
        uint256 month;
        uint256 day;
        {
            int256 __days = int256(expiry_ / 1 days);
            int256 num1 = __days + 68569 + 2440588; 
            int256 num2 = (4 * num1) / 146097;
            num1 = num1 - (146097 * num2 + 3) / 4;
            int256 _year = (4000 * (num1 + 1)) / 1461001;
            num1 = num1 - (1461 * _year) / 4 + 31;
            int256 _month = (80 * num1) / 2447;
            int256 _day = num1 - (2447 * _month) / 80;
            num1 = _month / 11;
            _month = _month + 2 - 12 * num1;
            _year = 100 * (num2 - 49) + _year + num1;
            year = uint256(_year);
            month = uint256(_month);
            day = uint256(_day);
        }
        string memory yearStr = _uint2str(year % 10000);
        string memory monthStr = month < 10
            ? string(abi.encodePacked("0", _uint2str(month)))
            : _uint2str(month);
        string memory dayStr = day < 10
            ? string(abi.encodePacked("0", _uint2str(day)))
            : _uint2str(day);
        name = string(
            abi.encodePacked(underlying_.name(), " ", yearStr, "-", monthStr, "-", dayStr)
        );
        symbol = string(abi.encodePacked(underlying_.symbol(), "-", yearStr, monthStr, dayStr));
    }
    function _uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}