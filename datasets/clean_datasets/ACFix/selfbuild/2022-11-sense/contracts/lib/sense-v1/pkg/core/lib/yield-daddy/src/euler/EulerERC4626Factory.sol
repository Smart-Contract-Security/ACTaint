pragma solidity ^0.8.13;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {EulerERC4626} from "./EulerERC4626.sol";
import {IEulerEToken} from "./external/IEulerEToken.sol";
import {ERC4626Factory} from "../base/ERC4626Factory.sol";
import {IEulerMarkets} from "./external/IEulerMarkets.sol";
contract EulerERC4626Factory is ERC4626Factory {
    error EulerERC4626Factory__ETokenNonexistent();
    address public immutable euler;
    IEulerMarkets public immutable markets;
    constructor(address euler_, IEulerMarkets markets_) {
        euler = euler_;
        markets = markets_;
    }
    function createERC4626(ERC20 asset) external virtual override returns (ERC4626 vault) {
        address eTokenAddress = markets.underlyingToEToken(address(asset));
        if (eTokenAddress == address(0)) {
            revert EulerERC4626Factory__ETokenNonexistent();
        }
        vault = new EulerERC4626{salt: bytes32(0)}(asset, euler, IEulerEToken(eTokenAddress));
        emit CreateERC4626(asset, vault);
    }
    function computeERC4626Address(ERC20 asset) external view virtual override returns (ERC4626 vault) {
        vault = ERC4626(
            _computeCreate2Address(
                keccak256(
                    abi.encodePacked(
                        type(EulerERC4626).creationCode,
                        abi.encode(asset, euler, IEulerEToken(markets.underlyingToEToken(address(asset))))
                    )
                )
            )
        );
    }
}