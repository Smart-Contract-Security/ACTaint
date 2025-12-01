pragma solidity 0.8.17;
import "@prb/math/contracts/PRBMathSD59x18.sol";
import {UUPSUpgradeableBase} from "../UUPSUpgradeableBase.sol";
import {IPremiumCalculator} from "../interfaces/IPremiumCalculator.sol";
import {ProtectionPoolParams} from "../interfaces/IProtectionPool.sol";
import "../libraries/Constants.sol";
import "../libraries/RiskFactorCalculator.sol";
import "hardhat/console.sol";
contract PremiumCalculator is UUPSUpgradeableBase, IPremiumCalculator {
  using PRBMathSD59x18 for int256;
  function initialize() external initializer {
    __UUPSUpgradeableBase_init();
  }
  function calculatePremium(
    uint256 _protectionDurationInSeconds,
    uint256 _protectionAmount,
    uint256 _protectionBuyerApy,
    uint256 _leverageRatio,
    uint256 _totalCapital,
    ProtectionPoolParams calldata _poolParameters
  )
    external
    view
    virtual
    override
    returns (uint256 _premiumAmount, bool _isMinPremium)
  {
    console.log(
      "Calculating premium... protection duration in seconds: %s, protection amount: %s, leverage ratio: %s",
      _protectionDurationInSeconds,
      _protectionAmount,
      _leverageRatio
    );
    int256 _carapacePremiumRate;
    uint256 _durationInYears = _calculateDurationInYears(
      _protectionDurationInSeconds
    );
    if (
      RiskFactorCalculator.canCalculateRiskFactor(
        _totalCapital,
        _leverageRatio,
        _poolParameters.leverageRatioFloor,
        _poolParameters.leverageRatioCeiling,
        _poolParameters.minRequiredCapital
      )
    ) {
      int256 _riskFactor = RiskFactorCalculator.calculateRiskFactor(
        _leverageRatio,
        _poolParameters.leverageRatioFloor,
        _poolParameters.leverageRatioCeiling,
        _poolParameters.leverageRatioBuffer,
        _poolParameters.curvature
      );
      _carapacePremiumRate = _calculateCarapacePremiumRate(
        _durationInYears,
        _riskFactor
      );
      console.logInt(_carapacePremiumRate);
    } else {
      _isMinPremium = true;
    }
    int256 _minCarapaceRiskPremiumPercent = int256(
      _poolParameters.minCarapaceRiskPremiumPercent
    );
    int256 _carapacePremiumRateToUse = _carapacePremiumRate >
      _minCarapaceRiskPremiumPercent
      ? _carapacePremiumRate
      : _minCarapaceRiskPremiumPercent;
    console.logInt(_carapacePremiumRateToUse);
    uint256 _underlyingPremiumRate = _calculateUnderlyingPremiumRate(
      _durationInYears,
      _protectionBuyerApy,
      _poolParameters.underlyingRiskPremiumPercent
    );
    console.log("Underlying premium rate: %s", _underlyingPremiumRate);
    assert(_carapacePremiumRateToUse > 0);
    uint256 _premiumRate = uint256(_carapacePremiumRateToUse) +
      _underlyingPremiumRate;
    console.log("Premium rate: %s", _premiumRate);
    _premiumAmount =
      (_protectionAmount * _premiumRate) /
      Constants.SCALE_18_DECIMALS;
  }
  function _calculateCarapacePremiumRate(
    uint256 _durationInYears,
    int256 _riskFactor
  ) internal pure returns (int256) {
    int256 _power = (-1 * int256(_durationInYears) * _riskFactor) /
      Constants.SCALE_18_DECIMALS_INT;
    return Constants.SCALE_18_DECIMALS_INT - (_power.exp()); 
  }
  function _calculateUnderlyingPremiumRate(
    uint256 _durationInYears,
    uint256 _protectionBuyerApy,
    uint256 _underlyingRiskPremiumPercent
  ) internal pure returns (uint256) {
    return
      (_underlyingRiskPremiumPercent * _protectionBuyerApy * _durationInYears) /
      (Constants.SCALE_18_DECIMALS * Constants.SCALE_18_DECIMALS);
  }
  function _calculateDurationInYears(uint256 _protectionDurationInSeconds)
    internal
    pure
    returns (uint256)
  {
    return
      (_protectionDurationInSeconds * 100 * Constants.SCALE_18_DECIMALS) /
      (uint256(Constants.SECONDS_IN_DAY) * 36524);
  }
}