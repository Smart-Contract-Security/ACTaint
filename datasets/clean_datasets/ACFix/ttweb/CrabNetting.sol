pragma solidity ^0.8.13;
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";
import {IOracle} from "../src/interfaces/IOracle.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {ICrabStrategyV2} from "../src/interfaces/ICrabStrategyV2.sol";
import {IController} from "../src/interfaces/IController.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {EIP712} from "openzeppelin/utils/cryptography/draft-EIP712.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
struct Order {
    uint256 bidId;
    address trader;
    uint256 quantity;
    uint256 price;
    bool isBuying;
    uint256 expiry;
    uint256 nonce;
    uint8 v;
    bytes32 r;
    bytes32 s;
}
struct Portion {
    uint256 crab;
    uint256 eth;
    uint256 sqth;
}
struct DepositAuctionParams {
    uint256 depositsQueued;
    uint256 minEth;
    uint256 totalDeposit;
    Order[] orders;
    uint256 clearingPrice;
    uint256 ethToFlashDeposit;
    uint24 ethUSDFee;
    uint24 flashDepositFee;
}
struct WithdrawAuctionParams {
    uint256 crabToWithdraw;
    Order[] orders;
    uint256 clearingPrice;
    uint256 minUSDC;
    uint24 ethUSDFee;
}
struct Receipt {
    address sender;
    uint256 amount;
}
contract CrabNetting is Ownable, EIP712 {
    bytes32 private constant _CRAB_NETTING_TYPEHASH = keccak256(
        "Order(uint256 bidId,address trader,uint256 quantity,uint256 price,bool isBuying,uint256 expiry,uint256 nonce)"
    );
    bool public isAuctionLive;
    uint32 public immutable sqthTwapPeriod;
    uint32 public auctionTwapPeriod = 420 seconds;
    uint256 public minUSDCAmount;
    uint256 public minCrabAmount;
    uint256 public otcPriceTolerance = 5e16; 
    uint256 public constant MAX_OTC_PRICE_TOLERANCE = 2e17; 
    address public immutable usdc;
    address public immutable crab;
    address public immutable weth;
    address public immutable sqth;
    ISwapRouter public immutable swapRouter;
    address public immutable oracle;
    address public immutable ethSqueethPool;
    address public immutable ethUsdcPool;
    address public immutable sqthController;
    uint256 public depositsIndex;
    uint256 public withdrawsIndex;
    Receipt[] public deposits;
    Receipt[] public withdraws;
    mapping(address => uint256) public usdBalance;
    mapping(address => uint256) public crabBalance;
    mapping(address => uint256[]) public userDepositsIndex;
    mapping(address => uint256[]) public userWithdrawsIndex;
    mapping(address => mapping(uint256 => bool)) public nonces;
    event USDCQueued(
        address indexed depositor, uint256 amount, uint256 depositorsBalance, uint256 indexed receiptIndex
    );
    event USDCDeQueued(address indexed depositor, uint256 amount, uint256 depositorsBalance);
    event CrabQueued(
        address indexed withdrawer, uint256 amount, uint256 withdrawersBalance, uint256 indexed receiptIndex
    );
    event CrabDeQueued(address indexed withdrawer, uint256 amount, uint256 withdrawersBalance);
    event USDCDeposited(
        address indexed depositor,
        uint256 usdcAmount,
        uint256 crabAmount,
        uint256 indexed receiptIndex,
        uint256 refundedETH
    );
    event CrabWithdrawn(
        address indexed withdrawer, uint256 crabAmount, uint256 usdcAmount, uint256 indexed receiptIndex
    );
    event BidTraded(uint256 indexed bidId, address indexed trader, uint256 quantity, uint256 price, bool isBuying);
    event SetAuctionTwapPeriod(uint32 previousTwap, uint32 newTwap);
    event SetOTCPriceTolerance(uint256 previousTolerance, uint256 newOtcPriceTolerance);
    event SetMinCrab(uint256 amount);
    event SetMinUSDC(uint256 amount);
    event NonceTrue(address sender, uint256 nonce);
    event ToggledAuctionLive(bool isAuctionLive);
    constructor(address _crab, address _swapRouter) EIP712("CRABNetting", "1") {
        crab = _crab;
        swapRouter = ISwapRouter(_swapRouter);
        sqthController = ICrabStrategyV2(_crab).powerTokenController();
        usdc = IController(sqthController).quoteCurrency();
        weth = ICrabStrategyV2(_crab).weth();
        sqth = ICrabStrategyV2(_crab).wPowerPerp();
        oracle = ICrabStrategyV2(_crab).oracle();
        ethSqueethPool = ICrabStrategyV2(_crab).ethWSqueethPool();
        ethUsdcPool = IController(sqthController).ethQuoteCurrencyPool();
        sqthTwapPeriod = IController(sqthController).TWAP_PERIOD();
        IERC20(sqth).approve(crab, type(uint256).max);
        IERC20(weth).approve(address(swapRouter), type(uint256).max);
        IERC20(usdc).approve(address(swapRouter), type(uint256).max);
    }
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
    function toggleAuctionLive() external onlyOwner {
        isAuctionLive = !isAuctionLive;
        emit ToggledAuctionLive(isAuctionLive);
    }
    function setNonceTrue(uint256 _nonce) external {
        nonces[msg.sender][_nonce] = true;
        emit NonceTrue(msg.sender, _nonce);
    }
    function setMinUSDC(uint256 _amount) external onlyOwner {
        minUSDCAmount = _amount;
        emit SetMinUSDC(_amount);
    }
    function setMinCrab(uint256 _amount) external onlyOwner {
        minCrabAmount = _amount;
        emit SetMinCrab(_amount);
    }
    function depositUSDC(uint256 _amount) external {
        require(_amount >= minUSDCAmount, "deposit amount smaller than minimum OTC amount");
        IERC20(usdc).transferFrom(msg.sender, address(this), _amount);
        usdBalance[msg.sender] = usdBalance[msg.sender] + _amount;
        deposits.push(Receipt(msg.sender, _amount));
        userDepositsIndex[msg.sender].push(deposits.length - 1);
        emit USDCQueued(msg.sender, _amount, usdBalance[msg.sender], deposits.length - 1);
    }
    function withdrawUSDC(uint256 _amount) external {
        require(!isAuctionLive, "auction is live");
        usdBalance[msg.sender] = usdBalance[msg.sender] - _amount;
        require(
            usdBalance[msg.sender] >= minUSDCAmount || usdBalance[msg.sender] == 0,
            "remaining amount smaller than minimum, consider removing full balance"
        );
        uint256 toRemove = _amount;
        uint256 lastIndexP1 = userDepositsIndex[msg.sender].length;
        for (uint256 i = lastIndexP1; i > 0; i--) {
            Receipt storage r = deposits[userDepositsIndex[msg.sender][i - 1]];
            if (r.amount > toRemove) {
                r.amount -= toRemove;
                toRemove = 0;
                break;
            } else {
                toRemove -= r.amount;
                delete deposits[userDepositsIndex[msg.sender][i - 1]];
            }
        }
        IERC20(usdc).transfer(msg.sender, _amount);
        emit USDCDeQueued(msg.sender, _amount, usdBalance[msg.sender]);
    }
    function queueCrabForWithdrawal(uint256 _amount) external {
        require(_amount >= minCrabAmount, "withdraw amount smaller than minimum OTC amount");
        IERC20(crab).transferFrom(msg.sender, address(this), _amount);
        crabBalance[msg.sender] = crabBalance[msg.sender] + _amount;
        withdraws.push(Receipt(msg.sender, _amount));
        userWithdrawsIndex[msg.sender].push(withdraws.length - 1);
        emit CrabQueued(msg.sender, _amount, crabBalance[msg.sender], withdraws.length - 1);
    }
    function dequeueCrab(uint256 _amount) external {
        require(!isAuctionLive, "auction is live");
        crabBalance[msg.sender] = crabBalance[msg.sender] - _amount;
        require(
            crabBalance[msg.sender] >= minCrabAmount || crabBalance[msg.sender] == 0,
            "remaining amount smaller than minimum, consider removing full balance"
        );
        uint256 toRemove = _amount;
        uint256 lastIndexP1 = userWithdrawsIndex[msg.sender].length;
        for (uint256 i = lastIndexP1; i > 0; i--) {
            Receipt storage r = withdraws[userWithdrawsIndex[msg.sender][i - 1]];
            if (r.amount > toRemove) {
                r.amount -= toRemove;
                toRemove = 0;
                break;
            } else {
                toRemove -= r.amount;
                delete withdraws[userWithdrawsIndex[msg.sender][i - 1]];
            }
        }
        IERC20(crab).transfer(msg.sender, _amount);
        emit CrabDeQueued(msg.sender, _amount, crabBalance[msg.sender]);
    }
    function netAtPrice(uint256 _price, uint256 _quantity) external onlyOwner {
        _checkCrabPrice(_price);
        uint256 crabQuantity = (_quantity * 1e18) / _price;
        require(_quantity <= IERC20(usdc).balanceOf(address(this)), "Not enough deposits to net");
        require(crabQuantity <= IERC20(crab).balanceOf(address(this)), "Not enough withdrawals to net");
        uint256 i = depositsIndex;
        uint256 amountToSend;
        while (_quantity > 0) {
            Receipt memory deposit = deposits[i];
            if (deposit.amount == 0) {
                i++;
                continue;
            }
            if (deposit.amount <= _quantity) {
                _quantity = _quantity - deposit.amount;
                usdBalance[deposit.sender] -= deposit.amount;
                amountToSend = (deposit.amount * 1e18) / _price;
                IERC20(crab).transfer(deposit.sender, amountToSend);
                emit USDCDeposited(deposit.sender, deposit.amount, amountToSend, i, 0);
                delete deposits[i];
                i++;
            } else {
                deposits[i].amount = deposit.amount - _quantity;
                usdBalance[deposit.sender] -= _quantity;
                amountToSend = (_quantity * 1e18) / _price;
                IERC20(crab).transfer(deposit.sender, amountToSend);
                emit USDCDeposited(deposit.sender, _quantity, amountToSend, i, 0);
                _quantity = 0;
            }
        }
        depositsIndex = i;
        i = withdrawsIndex;
        while (crabQuantity > 0) {
            Receipt memory withdraw = withdraws[i];
            if (withdraw.amount == 0) {
                i++;
                continue;
            }
            if (withdraw.amount <= crabQuantity) {
                crabQuantity = crabQuantity - withdraw.amount;
                crabBalance[withdraw.sender] -= withdraw.amount;
                amountToSend = (withdraw.amount * _price) / 1e18;
                IERC20(usdc).transfer(withdraw.sender, amountToSend);
                emit CrabWithdrawn(withdraw.sender, withdraw.amount, amountToSend, i);
                delete withdraws[i];
                i++;
            } else {
                withdraws[i].amount = withdraw.amount - crabQuantity;
                crabBalance[withdraw.sender] -= crabQuantity;
                amountToSend = (crabQuantity * _price) / 1e18;
                IERC20(usdc).transfer(withdraw.sender, amountToSend);
                emit CrabWithdrawn(withdraw.sender, withdraw.amount, amountToSend, i);
                crabQuantity = 0;
            }
        }
        withdrawsIndex = i;
    }
    function depositsQueued() external view returns (uint256) {
        uint256 j = depositsIndex;
        uint256 sum;
        while (j < deposits.length) {
            sum = sum + deposits[j].amount;
            j++;
        }
        return sum;
    }
    function withdrawsQueued() external view returns (uint256) {
        uint256 j = withdrawsIndex;
        uint256 sum;
        while (j < withdraws.length) {
            sum = sum + withdraws[j].amount;
            j++;
        }
        return sum;
    }
    function checkOrder(Order memory _order) external {
        return _checkOrder(_order);
    }
    function _checkOrder(Order memory _order) internal {
        _useNonce(_order.trader, _order.nonce);
        bytes32 structHash = keccak256(
            abi.encode(
                _CRAB_NETTING_TYPEHASH,
                _order.bidId,
                _order.trader,
                _order.quantity,
                _order.price,
                _order.isBuying,
                _order.expiry,
                _order.nonce
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address offerSigner = ECDSA.recover(hash, _order.v, _order.r, _order.s);
        require(offerSigner == _order.trader, "Signature not correct");
        require(_order.expiry >= block.timestamp, "order expired");
    }
    function _debtToMint(uint256 _amount) internal view returns (uint256) {
        uint256 feeAdjustment = _calcFeeAdjustment();
        (,, uint256 collateral, uint256 debt) = ICrabStrategyV2(crab).getVaultDetails();
        uint256 wSqueethToMint = (_amount * debt) / (collateral + (debt * feeAdjustment));
        return wSqueethToMint;
    }
    function depositAuction(DepositAuctionParams calldata _p) external onlyOwner {
        _checkOTCPrice(_p.clearingPrice, false);
        uint256 initCrabBalance = IERC20(crab).balanceOf(address(this));
        uint256 initEthBalance = address(this).balance;
        uint256 sqthToSell = _debtToMint(_p.totalDeposit);
        uint256 remainingToSell = sqthToSell;
        for (uint256 i = 0; i < _p.orders.length; i++) {
            require(_p.orders[i].isBuying, "auction order not buying sqth");
            require(_p.orders[i].price >= _p.clearingPrice, "buy order price less than clearing");
            _checkOrder(_p.orders[i]);
            if (_p.orders[i].quantity >= remainingToSell) {
                IWETH(weth).transferFrom(
                    _p.orders[i].trader, address(this), (remainingToSell * _p.clearingPrice) / 1e18
                );
                remainingToSell = 0;
                break;
            } else {
                IWETH(weth).transferFrom(
                    _p.orders[i].trader, address(this), (_p.orders[i].quantity * _p.clearingPrice) / 1e18
                );
                remainingToSell -= _p.orders[i].quantity;
            }
        }
        require(remainingToSell == 0, "not enough buy orders for sqth");
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: usdc,
            tokenOut: weth,
            fee: _p.ethUSDFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _p.depositsQueued,
            amountOutMinimum: _p.minEth,
            sqrtPriceLimitX96: 0
        });
        swapRouter.exactInputSingle(params);
        IWETH(weth).withdraw(IWETH(weth).balanceOf(address(this)));
        ICrabStrategyV2(crab).deposit{value: _p.totalDeposit}();
        Portion memory to_send;
        to_send.eth = address(this).balance - initEthBalance;
        if (to_send.eth > 0 && _p.ethToFlashDeposit > 0) {
            if (to_send.eth <= _p.ethToFlashDeposit) {
                ICrabStrategyV2(crab).flashDeposit{value: to_send.eth}(_p.ethToFlashDeposit, _p.flashDepositFee);
            }
        }
        to_send.sqth = IERC20(sqth).balanceOf(address(this));
        remainingToSell = to_send.sqth;
        for (uint256 j = 0; j < _p.orders.length; j++) {
            if (_p.orders[j].quantity < remainingToSell) {
                IERC20(sqth).transfer(_p.orders[j].trader, _p.orders[j].quantity);
                remainingToSell -= _p.orders[j].quantity;
                emit BidTraded(_p.orders[j].bidId, _p.orders[j].trader, _p.orders[j].quantity, _p.clearingPrice, true);
            } else {
                IERC20(sqth).transfer(_p.orders[j].trader, remainingToSell);
                emit BidTraded(_p.orders[j].bidId, _p.orders[j].trader, remainingToSell, _p.clearingPrice, true);
                break;
            }
        }
        uint256 remainingDeposits = _p.depositsQueued;
        uint256 k = depositsIndex;
        to_send.crab = IERC20(crab).balanceOf(address(this)) - initCrabBalance;
        to_send.eth = address(this).balance - initEthBalance;
        IWETH(weth).deposit{value: to_send.eth}();
        while (remainingDeposits > 0) {
            uint256 queuedAmount = deposits[k].amount;
            Portion memory portion;
            if (queuedAmount == 0) {
                k++;
                continue;
            }
            if (queuedAmount <= remainingDeposits) {
                remainingDeposits = remainingDeposits - queuedAmount;
                usdBalance[deposits[k].sender] -= queuedAmount;
                portion.crab = (((queuedAmount * 1e18) / _p.depositsQueued) * to_send.crab) / 1e18;
                IERC20(crab).transfer(deposits[k].sender, portion.crab);
                portion.eth = (((queuedAmount * 1e18) / _p.depositsQueued) * to_send.eth) / 1e18;
                if (portion.eth > 1e12) {
                    IWETH(weth).transfer(deposits[k].sender, portion.eth);
                } else {
                    portion.eth = 0;
                }
                emit USDCDeposited(deposits[k].sender, queuedAmount, portion.crab, k, portion.eth);
                delete deposits[k];
                k++;
            } else {
                usdBalance[deposits[k].sender] -= remainingDeposits;
                portion.crab = (((remainingDeposits * 1e18) / _p.depositsQueued) * to_send.crab) / 1e18;
                IERC20(crab).transfer(deposits[k].sender, portion.crab);
                portion.eth = (((remainingDeposits * 1e18) / _p.depositsQueued) * to_send.eth) / 1e18;
                if (portion.eth > 1e12) {
                    IWETH(weth).transfer(deposits[k].sender, portion.eth);
                } else {
                    portion.eth = 0;
                }
                emit USDCDeposited(deposits[k].sender, remainingDeposits, portion.crab, k, portion.eth);
                deposits[k].amount -= remainingDeposits;
                remainingDeposits = 0;
            }
        }
        depositsIndex = k;
        isAuctionLive = false;
    }
    function withdrawAuction(WithdrawAuctionParams calldata _p) public onlyOwner {
        _checkOTCPrice(_p.clearingPrice, true);
        uint256 initWethBalance = IERC20(weth).balanceOf(address(this));
        uint256 initEthBalance = address(this).balance;
        uint256 sqthRequired = ICrabStrategyV2(crab).getWsqueethFromCrabAmount(_p.crabToWithdraw);
        uint256 toPull = sqthRequired;
        for (uint256 i = 0; i < _p.orders.length && toPull > 0; i++) {
            _checkOrder(_p.orders[i]);
            require(!_p.orders[i].isBuying, "auction order is not selling");
            require(_p.orders[i].price <= _p.clearingPrice, "sell order price greater than clearing");
            if (_p.orders[i].quantity < toPull) {
                toPull -= _p.orders[i].quantity;
                IERC20(sqth).transferFrom(_p.orders[i].trader, address(this), _p.orders[i].quantity);
            } else {
                IERC20(sqth).transferFrom(_p.orders[i].trader, address(this), toPull);
                toPull = 0;
            }
        }
        ICrabStrategyV2(crab).withdraw(_p.crabToWithdraw);
        IWETH(weth).deposit{value: address(this).balance - initEthBalance}();
        toPull = sqthRequired;
        uint256 sqthQuantity;
        for (uint256 i = 0; i < _p.orders.length && toPull > 0; i++) {
            if (_p.orders[i].quantity < toPull) {
                sqthQuantity = _p.orders[i].quantity;
            } else {
                sqthQuantity = toPull;
            }
            IERC20(weth).transfer(_p.orders[i].trader, (sqthQuantity * _p.clearingPrice) / 1e18);
            toPull -= sqthQuantity;
            emit BidTraded(_p.orders[i].bidId, _p.orders[i].trader, sqthQuantity, _p.clearingPrice, false);
        }
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(weth),
            tokenOut: address(usdc),
            fee: _p.ethUSDFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: (IERC20(weth).balanceOf(address(this)) - initWethBalance),
            amountOutMinimum: _p.minUSDC,
            sqrtPriceLimitX96: 0
        });
        uint256 usdcReceived = swapRouter.exactInputSingle(params);
        uint256 remainingWithdraws = _p.crabToWithdraw;
        uint256 j = withdrawsIndex;
        uint256 usdcAmount;
        while (remainingWithdraws > 0) {
            Receipt memory withdraw = withdraws[j];
            if (withdraw.amount == 0) {
                j++;
                continue;
            }
            if (withdraw.amount <= remainingWithdraws) {
                remainingWithdraws -= withdraw.amount;
                crabBalance[withdraw.sender] -= withdraw.amount;
                usdcAmount = (((withdraw.amount * 1e18) / _p.crabToWithdraw) * usdcReceived) / 1e18;
                IERC20(usdc).transfer(withdraw.sender, usdcAmount);
                emit CrabWithdrawn(withdraw.sender, withdraw.amount, usdcAmount, j);
                delete withdraws[j];
                j++;
            } else {
                withdraws[j].amount -= remainingWithdraws;
                crabBalance[withdraw.sender] -= remainingWithdraws;
                usdcAmount = (((remainingWithdraws * 1e18) / _p.crabToWithdraw) * usdcReceived) / 1e18;
                IERC20(usdc).transfer(withdraw.sender, usdcAmount);
                emit CrabWithdrawn(withdraw.sender, remainingWithdraws, usdcAmount, j);
                remainingWithdraws = 0;
            }
        }
        withdrawsIndex = j;
        isAuctionLive = false;
    }
    function setAuctionTwapPeriod(uint32 _auctionTwapPeriod) external onlyOwner {
        require(_auctionTwapPeriod >= 180, "twap period cannot be less than 180");
        uint32 previousTwap = auctionTwapPeriod;
        auctionTwapPeriod = _auctionTwapPeriod;
        emit SetAuctionTwapPeriod(previousTwap, _auctionTwapPeriod);
    }
    function setOTCPriceTolerance(uint256 _otcPriceTolerance) external onlyOwner {
        require(_otcPriceTolerance <= MAX_OTC_PRICE_TOLERANCE, "Price tolerance has to be less than 20%");
        uint256 previousOtcTolerance = auctionTwapPeriod;
        otcPriceTolerance = _otcPriceTolerance;
        emit SetOTCPriceTolerance(previousOtcTolerance, _otcPriceTolerance);
    }
    function _useNonce(address _trader, uint256 _nonce) internal {
        require(!nonces[_trader][_nonce], "Nonce already used");
        nonces[_trader][_nonce] = true;
    }
    function _checkOTCPrice(uint256 _price, bool _isAuctionBuying) internal view {
        uint256 squeethEthPrice = IOracle(oracle).getTwap(ethSqueethPool, sqth, weth, auctionTwapPeriod, true);
        if (_isAuctionBuying) {
            require(
                _price <= (squeethEthPrice * (1e18 + otcPriceTolerance)) / 1e18,
                "Price too high relative to Uniswap twap."
            );
        } else {
            require(
                _price >= (squeethEthPrice * (1e18 - otcPriceTolerance)) / 1e18,
                "Price too low relative to Uniswap twap."
            );
        }
    }
    function _checkCrabPrice(uint256 _price) internal view {
        uint256 squeethEthPrice = IOracle(oracle).getTwap(ethSqueethPool, sqth, weth, auctionTwapPeriod, true);
        uint256 usdcEthPrice = IOracle(oracle).getTwap(ethUsdcPool, weth, usdc, auctionTwapPeriod, true);
        (,, uint256 collateral, uint256 debt) = ICrabStrategyV2(crab).getVaultDetails();
        uint256 crabFairPrice =
            ((collateral - ((debt * squeethEthPrice) / 1e18)) * usdcEthPrice) / ICrabStrategyV2(crab).totalSupply();
        crabFairPrice = crabFairPrice / 1e12; 
        require(_price <= (crabFairPrice * (1e18 + otcPriceTolerance)) / 1e18, "Crab Price too high");
        require(_price >= (crabFairPrice * (1e18 - otcPriceTolerance)) / 1e18, "Crab Price too low");
    }
    function _calcFeeAdjustment() internal view returns (uint256) {
        uint256 feeRate = IController(sqthController).feeRate();
        if (feeRate == 0) return 0;
        uint256 squeethEthPrice = IOracle(oracle).getTwap(ethSqueethPool, sqth, weth, sqthTwapPeriod, true);
        return (squeethEthPrice * feeRate) / 10000;
    }
    receive() external payable {
        require(msg.sender == weth || msg.sender == crab, "only weth and crab can send me monies");
    }
}