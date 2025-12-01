pragma solidity >=0.8.0;
import {ERC1155TokenReceiver} from "./ERC1155.sol";
abstract contract ERC1155B {
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
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(uint256 => address) public ownerOf;
    function balanceOf(address owner, uint256 id) public view virtual returns (uint256 bal) {
        address idOwner = ownerOf[id];
        assembly {
            bal := eq(idOwner, owner)
        }
    }
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
        bytes calldata data
    ) public virtual {
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");
        require(from == ownerOf[id], "WRONG_FROM"); 
        require(amount == 1, "INVALID_AMOUNT");
        ownerOf[id] = to;
        emit TransferSingle(msg.sender, from, to, id, amount);
        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");
        uint256 id;
        uint256 amount;
        unchecked {
            for (uint256 i = 0; i < ids.length; i++) {
                id = ids[i];
                amount = amounts[i];
                require(from == ownerOf[id], "WRONG_FROM");
                require(amount == 1, "INVALID_AMOUNT");
                ownerOf[id] = to;
            }
        }
        emit TransferBatch(msg.sender, from, to, ids, amounts);
        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }
    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        require(owners.length == ids.length, "LENGTH_MISMATCH");
        balances = new uint256[](owners.length);
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = balanceOf(owners[i], ids[i]);
            }
        }
    }
    function _mint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        require(ownerOf[id] == address(0), "ALREADY_MINTED");
        ownerOf[id] = to;
        emit TransferSingle(msg.sender, address(0), to, id, 1);
        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, 1, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }
    function _batchMint(
        address to,
        uint256[] memory ids,
        bytes memory data
    ) internal virtual {
        uint256 idsLength = ids.length; 
        uint256[] memory amounts = new uint256[](idsLength);
        uint256 id; 
        unchecked {
            for (uint256 i = 0; i < idsLength; ++i) {
                id = ids[i];
                require(ownerOf[id] == address(0), "ALREADY_MINTED");
                ownerOf[id] = to;
                amounts[i] = 1;
            }
        }
        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }
    function _batchBurn(address from, uint256[] memory ids) internal virtual {
        require(from != address(0), "INVALID_FROM");
        uint256 idsLength = ids.length; 
        uint256[] memory amounts = new uint256[](idsLength);
        uint256 id; 
        unchecked {
            for (uint256 i = 0; i < idsLength; ++i) {
                id = ids[i];
                require(ownerOf[id] == from, "WRONG_FROM");
                ownerOf[id] = address(0);
                amounts[i] = 1;
            }
        }
        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }
    function _burn(uint256 id) internal virtual {
        address owner = ownerOf[id];
        require(owner != address(0), "NOT_MINTED");
        ownerOf[id] = address(0);
        emit TransferSingle(msg.sender, owner, address(0), id, 1);
    }
}