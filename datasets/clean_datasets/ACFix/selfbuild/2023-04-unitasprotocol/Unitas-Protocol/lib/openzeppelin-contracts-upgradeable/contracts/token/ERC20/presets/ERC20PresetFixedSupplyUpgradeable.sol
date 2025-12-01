pragma solidity ^0.8.0;
import "../extensions/ERC20BurnableUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
contract ERC20PresetFixedSupplyUpgradeable is Initializable, ERC20BurnableUpgradeable {
    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) public virtual initializer {
        __ERC20PresetFixedSupply_init(name, symbol, initialSupply, owner);
    }
    function __ERC20PresetFixedSupply_init(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) internal onlyInitializing {
        __ERC20_init_unchained(name, symbol);
        __ERC20PresetFixedSupply_init_unchained(name, symbol, initialSupply, owner);
    }
    function __ERC20PresetFixedSupply_init_unchained(
        string memory,
        string memory,
        uint256 initialSupply,
        address owner
    ) internal onlyInitializing {
        _mint(owner, initialSupply);
    }
    uint256[50] private __gap;
}