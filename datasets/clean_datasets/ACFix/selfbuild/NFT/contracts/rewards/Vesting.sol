pragma solidity 0.5.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
contract Vesting {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    struct Vest {
        uint256 amount;
        uint256 vestPeriodInSeconds;
        uint256 creationTimestamp;
        uint256 withdrawnAmount;
    }
    mapping(address => Vest[]) public accountVestList;
    IERC20 public token;
    constructor(address _token) public {
        token = IERC20(_token);
    }
    function vest(
        address to,
        uint256 amount,
        uint256 vestPeriodInSeconds
    ) external returns (uint256 vestIdx) {
        require(vestPeriodInSeconds > 0, "Vesting: vestPeriodInSeconds == 0");
        token.safeTransferFrom(msg.sender, address(this), amount);
        vestIdx = accountVestList[to].length;
        accountVestList[to].push(
            Vest({
                amount: amount,
                vestPeriodInSeconds: vestPeriodInSeconds,
                creationTimestamp: now,
                withdrawnAmount: 0
            })
        );
    }
    function withdrawVested(address account, uint256 vestIdx)
        external
        returns (uint256 withdrawnAmount)
    {
        withdrawnAmount = _getVestWithdrawableAmount(account, vestIdx);
        if (withdrawnAmount == 0) {
            return 0;
        }
        uint256 recordedWithdrawnAmount = accountVestList[account][vestIdx]
            .withdrawnAmount;
        accountVestList[account][vestIdx]
            .withdrawnAmount = recordedWithdrawnAmount.add(withdrawnAmount);
        token.safeTransfer(account, withdrawnAmount);
    }
    function getVestWithdrawableAmount(address account, uint256 vestIdx)
        external
        view
        returns (uint256)
    {
        return _getVestWithdrawableAmount(account, vestIdx);
    }
    function _getVestWithdrawableAmount(address account, uint256 vestIdx)
        internal
        view
        returns (uint256)
    {
        Vest storage vest = accountVestList[account][vestIdx];
        uint256 vestFullAmount = vest.amount;
        uint256 vestCreationTimestamp = vest.creationTimestamp;
        uint256 vestPeriodInSeconds = vest.vestPeriodInSeconds;
        uint256 vestedAmount;
        if (now >= vestCreationTimestamp.add(vestPeriodInSeconds)) {
            vestedAmount = vestFullAmount;
        } else {
            vestedAmount = vestFullAmount
                .mul(now.sub(vestCreationTimestamp))
                .div(vestPeriodInSeconds);
        }
        return vestedAmount.sub(vest.withdrawnAmount);
    }
}