pragma solidity ^0.5.10;
import {IBondedECDSAKeepVendor} from "@keep-network/keep-ecdsa/contracts/api/IBondedECDSAKeepVendor.sol";
import {IBondedECDSAKeepFactory} from "@keep-network/keep-ecdsa/contracts/api/IBondedECDSAKeepFactory.sol";
import {VendingMachine} from "./VendingMachine.sol";
import {DepositFactory} from "../proxy/DepositFactory.sol";
import {IRelay} from "@summa-tx/relay-sol/contracts/Relay.sol";
import {ITBTCSystem} from "../interfaces/ITBTCSystem.sol";
import {IBTCETHPriceFeed} from "../interfaces/IBTCETHPriceFeed.sol";
import {DepositLog} from "../DepositLog.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
contract TBTCSystem is Ownable, ITBTCSystem, DepositLog {
    using SafeMath for uint256;
    event LotSizesUpdated(uint256[] _lotSizes);
    event AllowNewDepositsUpdated(bool _allowNewDeposits);
    event SignerFeeDivisorUpdated(uint256 _signerFeeDivisor);
    event CollateralizationThresholdsUpdated(
        uint128 _initialCollateralizedPercent,
        uint128 _undercollateralizedThresholdPercent,
        uint128 _severelyUndercollateralizedThresholdPercent
    );
    bool _initialized = false;
    uint256 pausedTimestamp;
    uint256 constant pausedDuration = 10 days;
    address public keepVendor;
    address public priceFeed;
    address public relay;
    bool private allowNewDeposits = false;
    uint256 private signerFeeDivisor = 200; 
    uint128 private initialCollateralizedPercent = 150; 
    uint128 private undercollateralizedThresholdPercent = 125;  
    uint128 private severelyUndercollateralizedThresholdPercent = 110; 
    uint256[] lotSizesSatoshis = [10**5, 10**6, 10**7, 2 * 10**7, 5 * 10**7, 10**8]; 
    constructor(address _priceFeed, address _relay) public {
        priceFeed = _priceFeed;
        relay = _relay;
    }
    function initialize(
        address _keepVendor,
        address _depositFactory,
        address payable _masterDepositAddress,
        address _tbtcToken,
        address _tbtcDepositToken,
        address _feeRebateToken,
        address _vendingMachine,
        uint256 _keepThreshold,
        uint256 _keepSize
    ) external onlyOwner {
        require(!_initialized, "already initialized");
        keepVendor = _keepVendor;
        VendingMachine(_vendingMachine).setExternalAddresses(
            _tbtcToken,
            _tbtcDepositToken,
            _feeRebateToken
        );
        DepositFactory(_depositFactory).setExternalDependencies(
            _masterDepositAddress,
            address(this),
            _tbtcToken,
            _tbtcDepositToken,
            _feeRebateToken,
            _vendingMachine,
            _keepThreshold,
            _keepSize
        );
        setTbtcDepositToken(_tbtcDepositToken);
        _initialized = true;
        allowNewDeposits = true;
    }
    function getAllowNewDeposits() external view returns (bool) { return allowNewDeposits; }
    function emergencyPauseNewDeposits() external onlyOwner returns (bool) {
        require(pausedTimestamp == 0, "emergencyPauseNewDeposits can only be called once");
        pausedTimestamp = block.timestamp;
        allowNewDeposits = false;
        emit AllowNewDepositsUpdated(false);
    }
    function resumeNewDeposits() public {
        require(allowNewDeposits == false, "New deposits are currently allowed");
        require(pausedTimestamp != 0, "Deposit has not been paused");
        require(block.timestamp.sub(pausedTimestamp) >= pausedDuration, "Deposits are still paused");
        allowNewDeposits = true;
        emit AllowNewDepositsUpdated(true);
    }
    function getRemainingPauseTerm() public view returns (uint256) {
        require(allowNewDeposits == false, "New deposits are currently allowed");
        return (block.timestamp.sub(pausedTimestamp) >= pausedDuration)?
            0:
            pausedDuration.sub(block.timestamp.sub(pausedTimestamp));
    }
    function setSignerFeeDivisor(uint256 _signerFeeDivisor)
        external onlyOwner
    {
        require(_signerFeeDivisor > 9, "Signer fee divisor must be greater than 9, for a signer fee that is <= 10%.");
        signerFeeDivisor = _signerFeeDivisor;
        emit SignerFeeDivisorUpdated(_signerFeeDivisor);
    }
    function getSignerFeeDivisor() external view returns (uint256) { return signerFeeDivisor; }
    function setLotSizes(uint256[] calldata _lotSizes) external onlyOwner {
        for( uint i = 0; i < _lotSizes.length; i++){
            if (_lotSizes[i] == 10**8){
                lotSizesSatoshis = _lotSizes;
                emit LotSizesUpdated(_lotSizes);
                return;
            }
        }
        revert("Lot size array must always contain 1BTC");
    }
    function getAllowedLotSizes() external view returns (uint256[] memory){
        return lotSizesSatoshis;
    }
    function isAllowedLotSize(uint256 _lotSizeSatoshis) external view returns (bool){
        for( uint i = 0; i < lotSizesSatoshis.length; i++){
            if (lotSizesSatoshis[i] == _lotSizeSatoshis){
                return true;
            }
        }
        return false;
    }
    function setCollateralizationThresholds(
        uint128 _initialCollateralizedPercent,
        uint128 _undercollateralizedThresholdPercent,
        uint128 _severelyUndercollateralizedThresholdPercent
    ) external onlyOwner {
        require(
            _initialCollateralizedPercent <= 300,
            "Initial collateralized percent must be <= 300%"
        );
        require(
            _initialCollateralizedPercent > _undercollateralizedThresholdPercent,
            "Undercollateralized threshold must be < initial collateralized percent"
        );
        require(
            _undercollateralizedThresholdPercent > _severelyUndercollateralizedThresholdPercent,
            "Severe undercollateralized threshold must be < undercollateralized threshold"
        );
        initialCollateralizedPercent = _initialCollateralizedPercent;
        undercollateralizedThresholdPercent = _undercollateralizedThresholdPercent;
        severelyUndercollateralizedThresholdPercent = _severelyUndercollateralizedThresholdPercent;
        emit CollateralizationThresholdsUpdated(
            _initialCollateralizedPercent,
            _undercollateralizedThresholdPercent,
            _severelyUndercollateralizedThresholdPercent
        );
    }
    function getUndercollateralizedThresholdPercent() external view returns (uint128) {
        return undercollateralizedThresholdPercent;
    }
    function getSeverelyUndercollateralizedThresholdPercent() external view returns (uint128) {
        return severelyUndercollateralizedThresholdPercent;
    }
    function getInitialCollateralizedPercent() external view returns (uint128) {
        return initialCollateralizedPercent;
    }
    function fetchBitcoinPrice() external view returns (uint256) {
        uint256 price = IBTCETHPriceFeed(priceFeed).getPrice();
        if (price == 0 || price > 10 ** 18) {
            revert("System returned a bad price");
        }
        return price;
    }
    function fetchRelayCurrentDifficulty() external view returns (uint256) {
        return IRelay(relay).getCurrentEpochDifficulty();
    }
    function fetchRelayPreviousDifficulty() external view returns (uint256) {
        return IRelay(relay).getPrevEpochDifficulty();
    }
    function createNewDepositFeeEstimate()
        external
        view
        returns (uint256)
    {
        IBondedECDSAKeepVendor _keepVendor = IBondedECDSAKeepVendor(keepVendor);
        IBondedECDSAKeepFactory _keepFactory = IBondedECDSAKeepFactory(_keepVendor.selectFactory());
        return _keepFactory.openKeepFeeEstimate();
    }
    function requestNewKeep(uint256 _m, uint256 _n, uint256 _bond)
        external
        payable
        returns (address)
    {
        IBondedECDSAKeepVendor _keepVendor = IBondedECDSAKeepVendor(keepVendor);
        IBondedECDSAKeepFactory _keepFactory = IBondedECDSAKeepFactory(_keepVendor.selectFactory());
        return _keepFactory.openKeep.value(msg.value)(_n, _m, msg.sender, _bond);
    }
}