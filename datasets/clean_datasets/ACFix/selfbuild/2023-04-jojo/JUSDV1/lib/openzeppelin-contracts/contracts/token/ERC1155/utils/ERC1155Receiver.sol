pragma solidity ^0.8.0;
import "../IERC1155Receiver.sol";
import "../../../utils/introspection/ERC165.sol";
abstract contract ERC1155Receiver is ERC165, IERC1155Receiver {
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
}