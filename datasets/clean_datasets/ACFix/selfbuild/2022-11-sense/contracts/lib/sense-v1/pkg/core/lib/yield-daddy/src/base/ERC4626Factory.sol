pragma solidity ^0.8.13;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";
abstract contract ERC4626Factory {
    using Bytes32AddressLib for bytes32;
    event CreateERC4626(ERC20 indexed asset, ERC4626 vault);
    function createERC4626(ERC20 asset) external virtual returns (ERC4626 vault);
    function computeERC4626Address(ERC20 asset) external view virtual returns (ERC4626 vault);
    function _computeCreate2Address(bytes32 bytecodeHash) internal view virtual returns (address) {
        return keccak256(abi.encodePacked(bytes1(0xFF), address(this), bytes32(0), bytecodeHash))
            .fromLast20Bytes(); 
    }
}