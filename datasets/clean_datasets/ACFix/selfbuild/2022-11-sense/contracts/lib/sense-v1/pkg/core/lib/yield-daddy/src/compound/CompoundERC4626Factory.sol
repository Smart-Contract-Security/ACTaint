pragma solidity ^0.8.13;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ICERC20} from "./external/ICERC20.sol";
import {CompoundERC4626} from "./CompoundERC4626.sol";
import {IComptroller} from "./external/IComptroller.sol";
import {ERC4626Factory} from "../base/ERC4626Factory.sol";
contract CompoundERC4626Factory is ERC4626Factory {
    error CompoundERC4626Factory__CTokenNonexistent();
    ERC20 public immutable comp;
    address public immutable rewardRecipient;
    IComptroller public immutable comptroller;
    mapping(ERC20 => ICERC20) public underlyingToCToken;
    constructor(IComptroller comptroller_, address cEtherAddress, address rewardRecipient_) {
        comptroller = comptroller_;
        rewardRecipient = rewardRecipient_;
        comp = ERC20(comptroller_.getCompAddress());
        ICERC20[] memory allCTokens = comptroller_.getAllMarkets();
        uint256 numCTokens = allCTokens.length;
        ICERC20 cToken;
        for (uint256 i; i < numCTokens;) {
            cToken = allCTokens[i];
            if (address(cToken) != cEtherAddress) {
                underlyingToCToken[cToken.underlying()] = cToken;
            }
            unchecked {
                ++i;
            }
        }
    }
    function createERC4626(ERC20 asset) external virtual override returns (ERC4626 vault) {
        ICERC20 cToken = underlyingToCToken[asset];
        if (address(cToken) == address(0)) {
            revert CompoundERC4626Factory__CTokenNonexistent();
        }
        vault = new CompoundERC4626{salt: bytes32(0)}(asset, comp, cToken, rewardRecipient, comptroller);
        emit CreateERC4626(asset, vault);
    }
    function computeERC4626Address(ERC20 asset) external view virtual override returns (ERC4626 vault) {
        vault = ERC4626(
            _computeCreate2Address(
                keccak256(
                    abi.encodePacked(
                        type(CompoundERC4626).creationCode,
                        abi.encode(asset, comp, underlyingToCToken[asset], rewardRecipient, comptroller)
                    )
                )
            )
        );
    }
    function updateUnderlyingToCToken(uint256[] memory newCTokenIndices) public {
        uint256 numCTokens = newCTokenIndices.length;
        ICERC20 cToken;
        uint256 index;
        for (uint256 i; i < numCTokens;) {
            index = newCTokenIndices[i];
            cToken = comptroller.allMarkets(index);
            underlyingToCToken[cToken.underlying()] = cToken;
            unchecked {
                ++i;
            }
        }
    }
}