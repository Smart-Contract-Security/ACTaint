pragma solidity ^0.8.13;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {AaveV2ERC4626} from "./AaveV2ERC4626.sol";
import {IAaveMining} from "./external/IAaveMining.sol";
import {ILendingPool} from "./external/ILendingPool.sol";
import {ERC4626Factory} from "../base/ERC4626Factory.sol";
contract AaveV2ERC4626Factory is ERC4626Factory {
    error AaveV2ERC4626Factory__ATokenNonexistent();
    IAaveMining public immutable aaveMining;
    address public immutable rewardRecipient;
    ILendingPool public immutable lendingPool;
    constructor(IAaveMining aaveMining_, address rewardRecipient_, ILendingPool lendingPool_) {
        aaveMining = aaveMining_;
        lendingPool = lendingPool_;
        rewardRecipient = rewardRecipient_;
    }
    function createERC4626(ERC20 asset) external virtual override returns (ERC4626 vault) {
        ILendingPool.ReserveData memory reserveData = lendingPool.getReserveData(address(asset));
        address aTokenAddress = reserveData.aTokenAddress;
        if (aTokenAddress == address(0)) {
            revert AaveV2ERC4626Factory__ATokenNonexistent();
        }
        vault =
            new AaveV2ERC4626{salt: bytes32(0)}(asset, ERC20(aTokenAddress), aaveMining, rewardRecipient, lendingPool);
        emit CreateERC4626(asset, vault);
    }
    function computeERC4626Address(ERC20 asset) external view virtual override returns (ERC4626 vault) {
        ILendingPool.ReserveData memory reserveData = lendingPool.getReserveData(address(asset));
        address aTokenAddress = reserveData.aTokenAddress;
        vault = ERC4626(
            _computeCreate2Address(
                keccak256(
                    abi.encodePacked(
                        type(AaveV2ERC4626).creationCode,
                        abi.encode(asset, ERC20(aTokenAddress), aaveMining, rewardRecipient, lendingPool)
                    )
                )
            )
        );
    }
}