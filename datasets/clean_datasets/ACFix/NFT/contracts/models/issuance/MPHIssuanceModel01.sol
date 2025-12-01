pragma solidity 0.5.17;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../libs/DecMath.sol";
import "./IMPHIssuanceModel.sol";
contract MPHIssuanceModel01 is Ownable, IMPHIssuanceModel {
    using Address for address;
    using DecMath for uint256;
    using SafeMath for uint256;
    uint256 internal constant PRECISION = 10**18;
    mapping(address => uint256) public poolDepositorRewardMintMultiplier;
    mapping(address => uint256) public poolDepositorRewardTakeBackMultiplier;
    mapping(address => uint256) public poolFunderRewardMultiplier;
    mapping(address => uint256) public poolDepositorRewardVestPeriod;
    mapping(address => uint256) public poolFunderRewardVestPeriod;
    uint256 public devRewardMultiplier;
    event ESetParamAddress(
        address indexed sender,
        string indexed paramName,
        address newValue
    );
    event ESetParamUint(
        address indexed sender,
        string indexed paramName,
        address indexed pool,
        uint256 newValue
    );
    constructor(uint256 _devRewardMultiplier) public {
        devRewardMultiplier = _devRewardMultiplier;
    }
    function computeDepositorReward(
        address pool,
        uint256 depositAmount,
        uint256 depositPeriodInSeconds,
        uint256 interestAmount
    )
        external
        view
        returns (
            uint256 depositorReward,
            uint256 devReward,
            uint256 govReward
        )
    {
        uint256 mintAmount = depositAmount.mul(depositPeriodInSeconds).decmul(
            poolDepositorRewardMintMultiplier[pool]
        );
        depositorReward = mintAmount;
        devReward = mintAmount.decmul(devRewardMultiplier);
        govReward = 0;
    }
    function computeTakeBackDepositorRewardAmount(
        address pool,
        uint256 mintMPHAmount,
        bool early
    )
        external
        view
        returns (
            uint256 takeBackAmount,
            uint256 devReward,
            uint256 govReward
        )
    {
        takeBackAmount = early
            ? mintMPHAmount
            : mintMPHAmount.decmul(poolDepositorRewardTakeBackMultiplier[pool]);
        devReward = 0;
        govReward = early ? 0 : takeBackAmount;
    }
    function computeFunderReward(
        address pool,
        uint256 depositAmount,
        uint256 fundingCreationTimestamp,
        uint256 maturationTimestamp,
        uint256 interestPayoutAmount,
        bool early
    )
        external
        view
        returns (
            uint256 funderReward,
            uint256 devReward,
            uint256 govReward
        )
    {
        if (early) {
            return (0, 0, 0);
        }
        funderReward = maturationTimestamp > fundingCreationTimestamp
            ? depositAmount
                .mul(maturationTimestamp.sub(fundingCreationTimestamp))
                .decmul(poolFunderRewardMultiplier[pool])
            : 0;
        devReward = funderReward.decmul(devRewardMultiplier);
        govReward = 0;
    }
    function setPoolDepositorRewardMintMultiplier(
        address pool,
        uint256 newMultiplier
    ) external onlyOwner {
        require(pool.isContract(), "MPHIssuanceModel: pool not contract");
        poolDepositorRewardMintMultiplier[pool] = newMultiplier;
        emit ESetParamUint(
            msg.sender,
            "poolDepositorRewardMintMultiplier",
            pool,
            newMultiplier
        );
    }
    function setPoolDepositorRewardTakeBackMultiplier(
        address pool,
        uint256 newMultiplier
    ) external onlyOwner {
        require(pool.isContract(), "MPHIssuanceModel: pool not contract");
        require(
            newMultiplier <= PRECISION,
            "MPHIssuanceModel: invalid multiplier"
        );
        poolDepositorRewardTakeBackMultiplier[pool] = newMultiplier;
        emit ESetParamUint(
            msg.sender,
            "poolDepositorRewardTakeBackMultiplier",
            pool,
            newMultiplier
        );
    }
    function setPoolFunderRewardMultiplier(address pool, uint256 newMultiplier)
        external
        onlyOwner
    {
        require(pool.isContract(), "MPHIssuanceModel: pool not contract");
        poolFunderRewardMultiplier[pool] = newMultiplier;
        emit ESetParamUint(
            msg.sender,
            "poolFunderRewardMultiplier",
            pool,
            newMultiplier
        );
    }
    function setPoolDepositorRewardVestPeriod(
        address pool,
        uint256 newVestPeriodInSeconds
    ) external onlyOwner {
        require(pool.isContract(), "MPHIssuanceModel: pool not contract");
        poolDepositorRewardVestPeriod[pool] = newVestPeriodInSeconds;
        emit ESetParamUint(
            msg.sender,
            "poolDepositorRewardVestPeriod",
            pool,
            newVestPeriodInSeconds
        );
    }
    function setPoolFunderRewardVestPeriod(
        address pool,
        uint256 newVestPeriodInSeconds
    ) external onlyOwner {
        require(pool.isContract(), "MPHIssuanceModel: pool not contract");
        poolFunderRewardVestPeriod[pool] = newVestPeriodInSeconds;
        emit ESetParamUint(
            msg.sender,
            "poolFunderRewardVestPeriod",
            pool,
            newVestPeriodInSeconds
        );
    }
    function setDevRewardMultiplier(uint256 newMultiplier) external onlyOwner {
        require(
            newMultiplier <= PRECISION,
            "MPHIssuanceModel: invalid multiplier"
        );
        devRewardMultiplier = newMultiplier;
        emit ESetParamUint(
            msg.sender,
            "devRewardMultiplier",
            address(0),
            newMultiplier
        );
    }
}