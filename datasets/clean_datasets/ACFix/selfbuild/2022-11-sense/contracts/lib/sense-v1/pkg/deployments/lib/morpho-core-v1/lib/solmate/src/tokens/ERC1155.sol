pragma solidity >=0.8.0;
abstract contract ERC1155 {
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);
    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    function uri(uint256 id) public view virtual returns (string memory);
    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual {
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");
        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;
        emit TransferSingle(msg.sender, from, to, id, amount);
        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual {
        uint256 idsLength = ids.length; 
        require(idsLength == amounts.length, "LENGTH_MISMATCH");
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");
        uint256 id;
        uint256 amount;
        for (uint256 i = 0; i < idsLength; ) {
            id = ids[i];
            amount = amounts[i];
            balanceOf[from][id] -= amount;
            balanceOf[to][id] += amount;
            unchecked {
                ++i;
            }
        }
        emit TransferBatch(msg.sender, from, to, ids, amounts);
        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }
    function balanceOfBatch(address[] memory owners, uint256[] memory ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        uint256 ownersLength = owners.length; 
        require(ownersLength == ids.length, "LENGTH_MISMATCH");
        balances = new uint256[](ownersLength);
        unchecked {
            for (uint256 i = 0; i < ownersLength; ++i) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || 
            interfaceId == 0xd9b67a26 || 
            interfaceId == 0x0e89341c; 
    }
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        balanceOf[to][id] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);
        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        uint256 idsLength = ids.length; 
        require(idsLength == amounts.length, "LENGTH_MISMATCH");
        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[to][ids[i]] += amounts[i];
            unchecked {
                ++i;
            }
        }
        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }
    function _batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal {
        uint256 idsLength = ids.length; 
        require(idsLength == amounts.length, "LENGTH_MISMATCH");
        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[from][ids[i]] -= amounts[i];
            unchecked {
                ++i;
            }
        }
        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal {
        balanceOf[from][id] -= amount;
        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }
}
interface ERC1155TokenReceiver {
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external returns (bytes4);
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external returns (bytes4);
}