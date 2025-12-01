pragma solidity 0.8.9;
import "../utils/Errors.sol";
import "./Types.sol";
library Position {
    function _openPosition(Types.State storage state, address trader) internal {
        state.openPositions[trader].push(msg.sender);
    }
    function _realizePnl(
        Types.State storage state,
        address trader,
        int256 pnl
    ) internal {
        state.primaryCredit[trader] += pnl;
        state.positionSerialNum[trader][msg.sender] += 1;
        address[] storage positionList = state.openPositions[trader];
        for (uint256 i = 0; i < positionList.length;) {
            if (positionList[i] == msg.sender) {
                positionList[i] = positionList[positionList.length - 1];
                positionList.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
    }
}