pragma solidity ^0.8.17;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {OracleImpl} from "splits-oracle/OracleImpl.sol";
import {PausableImpl} from "splits-utils/PausableImpl.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {TokenUtils} from "splits-utils/TokenUtils.sol";
import {WalletImpl} from "splits-utils/WalletImpl.sol";
import {ISwapperFlashCallback} from "./interfaces/ISwapperFlashCallback.sol";
contract SwapperImpl is WalletImpl, PausableImpl {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using TokenUtils for address;
    error Invalid_AmountsToBeneficiary();
    error Invalid_QuoteToken();
    error InsufficientFunds_InContract();
    error InsufficientFunds_FromTrader();
    struct InitParams {
        address owner;
        bool paused;
        address beneficiary;
        address tokenToBeneficiary;
        OracleImpl oracle;
    }
    event SetBeneficiary(address beneficiary);
    event SetTokenToBeneficiary(address tokenToBeneficiary);
    event SetOracle(OracleImpl oracle);
    event ReceiveETH(uint256 amount);
    event Payback(address indexed payer, uint256 amount);
    event Flash(
        address indexed trader,
        OracleImpl.QuoteParams[] quoteParams,
        address tokenToBeneficiary,
        uint256[] amountsToBeneficiary,
        uint256 excessToBeneficiary
    );
    address public immutable swapperFactory;
    address internal $beneficiary;
    uint96 internal $_payback;
    address internal $tokenToBeneficiary;
    OracleImpl internal $oracle;
    constructor() {
        swapperFactory = msg.sender;
    }
    function initializer(InitParams calldata params_) external {
        if (msg.sender != swapperFactory) revert Unauthorized();
        __initPausable({owner_: params_.owner, paused_: params_.paused});
        $beneficiary = params_.beneficiary;
        $tokenToBeneficiary = params_.tokenToBeneficiary;
        $oracle = params_.oracle;
    }
    function setBeneficiary(address beneficiary_) external onlyOwner {
        $beneficiary = beneficiary_;
        emit SetBeneficiary(beneficiary_);
    }
    function setTokenToBeneficiary(address tokenToBeneficiary_) external onlyOwner {
        $tokenToBeneficiary = tokenToBeneficiary_;
        emit SetTokenToBeneficiary(tokenToBeneficiary_);
    }
    function setOracle(OracleImpl oracle_) external onlyOwner {
        $oracle = oracle_;
        emit SetOracle(oracle_);
    }
    function beneficiary() external view returns (address) {
        return $beneficiary;
    }
    function tokenToBeneficiary() external view returns (address) {
        return $tokenToBeneficiary;
    }
    function oracle() external view returns (OracleImpl) {
        return $oracle;
    }
    function payback() external payable {
        $_payback += msg.value.toUint96();
        emit Payback(msg.sender, msg.value);
    }
    function flash(OracleImpl.QuoteParams[] calldata quoteParams_, bytes calldata callbackData_)
        external
        payable
        pausable
    {
        address _tokenToBeneficiary = $tokenToBeneficiary;
        (uint256 amountToBeneficiary, uint256[] memory amountsToBeneficiary) =
            _transferToTrader(_tokenToBeneficiary, quoteParams_);
        ISwapperFlashCallback(msg.sender).swapperFlashCallback({
            tokenToBeneficiary: _tokenToBeneficiary,
            amountToBeneficiary: amountToBeneficiary,
            data: callbackData_
        });
        uint256 excessToBeneficiary = _transferToBeneficiary(_tokenToBeneficiary, amountToBeneficiary);
        emit Flash(msg.sender, quoteParams_, _tokenToBeneficiary, amountsToBeneficiary, excessToBeneficiary);
    }
    function _transferToTrader(address tokenToBeneficiary_, OracleImpl.QuoteParams[] calldata quoteParams_)
        internal
        returns (uint256 amountToBeneficiary, uint256[] memory amountsToBeneficiary)
    {
        amountsToBeneficiary = $oracle.getQuoteAmounts(quoteParams_);
        uint256 length = quoteParams_.length;
        if (amountsToBeneficiary.length != length) revert Invalid_AmountsToBeneficiary();
        uint128 amountToTrader;
        address tokenToTrader;
        for (uint256 i; i < length;) {
            OracleImpl.QuoteParams calldata qp = quoteParams_[i];
            if (tokenToBeneficiary_ != qp.quotePair.quote) revert Invalid_QuoteToken();
            tokenToTrader = qp.quotePair.base;
            amountToTrader = qp.baseAmount;
            if (amountToTrader > tokenToTrader._balanceOf(address(this))) {
                revert InsufficientFunds_InContract();
            }
            amountToBeneficiary += amountsToBeneficiary[i];
            tokenToTrader._safeTransfer(msg.sender, amountToTrader);
            unchecked {
                ++i;
            }
        }
    }
    function _transferToBeneficiary(address tokenToBeneficiary_, uint256 amountToBeneficiary_)
        internal
        returns (uint256 excessToBeneficiary)
    {
        address _beneficiary = $beneficiary;
        if (tokenToBeneficiary_._isETH()) {
            if ($_payback < amountToBeneficiary_) {
                revert InsufficientFunds_FromTrader();
            }
            $_payback = 0;
            uint256 ethBalance = address(this).balance;
            excessToBeneficiary = ethBalance - amountToBeneficiary_;
            _beneficiary.safeTransferETH(ethBalance);
        } else {
            tokenToBeneficiary_.safeTransferFrom(msg.sender, _beneficiary, amountToBeneficiary_);
            excessToBeneficiary = ERC20(tokenToBeneficiary_).balanceOf(address(this));
            if (excessToBeneficiary > 0) {
                tokenToBeneficiary_.safeTransfer(_beneficiary, excessToBeneficiary);
            }
        }
    }
}