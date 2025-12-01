pragma solidity ^0.8.1;
interface IRoyaltyRegistry {
    function addRegistrant(address registrant) external;
    function removeRegistrant(address registrant) external;
    function setRoyalty(address _erc721address, address payable _payoutAddress, uint256 _payoutPerMille) external;
    function getRoyaltyPayoutAddress(address _erc721address) external view returns (address payable);
    function getRoyaltyPayoutRate(address _erc721address) external view returns (uint256);
}
pragma solidity ^0.8.0;
interface ICancellationRegistry {
    function addRegistrant(address registrant) external;
    function removeRegistrant(address registrant) external;
    function cancelOrder(bytes memory signature) external;
    function isOrderCancelled(bytes memory signature) external view returns (bool);
    function cancelPreviousSellOrders(address seller, address tokenAddr, uint256 tokenId) external;
    function getSellOrderCancellationBlockNumber(address addr, address tokenAddr, uint256 tokenId) external view returns (uint256);
}
pragma solidity ^0.8.0;
interface IPaymentERC20Registry {  
  function isApprovedERC20(address _token) external view returns (bool);
  function addApprovedERC20(address _token) external;
  function removeApprovedERC20(address _token) external;
}
pragma solidity ^0.8.0;
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
pragma solidity ^0.8.0;
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        _transferOwnership(_msgSender());
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
pragma solidity ^0.8.0;
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
pragma solidity ^0.8.0;
interface IERC721 is IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool _approved) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
pragma solidity ^0.8.0;
pragma solidity ^0.8.0;
interface IERC1155 is IERC165 {
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}
pragma solidity ^0.8.0;
pragma solidity ^0.8.0;
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
pragma solidity ^0.8.0;
pragma solidity ^0.8.0;
library ERC165Checker {
    bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;
    function supportsERC165(address account) internal view returns (bool) {
        return
            _supportsERC165Interface(account, type(IERC165).interfaceId) &&
            !_supportsERC165Interface(account, _INTERFACE_ID_INVALID);
    }
    function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
        return supportsERC165(account) && _supportsERC165Interface(account, interfaceId);
    }
    function getSupportedInterfaces(address account, bytes4[] memory interfaceIds)
        internal
        view
        returns (bool[] memory)
    {
        bool[] memory interfaceIdsSupported = new bool[](interfaceIds.length);
        if (supportsERC165(account)) {
            for (uint256 i = 0; i < interfaceIds.length; i++) {
                interfaceIdsSupported[i] = _supportsERC165Interface(account, interfaceIds[i]);
            }
        }
        return interfaceIdsSupported;
    }
    function supportsAllInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool) {
        if (!supportsERC165(account)) {
            return false;
        }
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (!_supportsERC165Interface(account, interfaceIds[i])) {
                return false;
            }
        }
        return true;
    }
    function _supportsERC165Interface(address account, bytes4 interfaceId) private view returns (bool) {
        bytes memory encodedParams = abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId);
        (bool success, bytes memory result) = account.staticcall{gas: 30000}(encodedParams);
        if (result.length < 32) return false;
        return success && abi.decode(result, (bool));
    }
}
pragma solidity ^0.8.0;
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}
pragma solidity ^0.8.0;
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }
    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; 
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }
        return (signer, RecoverError.NoError);
    }
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}
pragma solidity ^0.8.1;
library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
pragma solidity ^0.8.0;
abstract contract Pausable is Context {
    event Paused(address account);
    event Unpaused(address account);
    bool private _paused;
    constructor() {
        _paused = false;
    }
    function paused() public view virtual returns (bool) {
        return _paused;
    }
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}
pragma solidity ^0.8.0;
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    constructor() {
        _status = _NOT_ENTERED;
    }
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}
pragma solidity ^0.8.0;
library SafeERC20 {
    using Address for address;
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }
    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }
    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}
pragma solidity ^0.8.0;
contract ExchangeV4 is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ERC165Checker for address;
    bytes4 private InterfaceId_ERC721 = 0x80ac58cd;  
    bytes4 private InterfaceId_ERC1155 = 0xd9b67a26; 
    address payable _makerWallet;
    uint256 private _makerFeePerMille = 25;
    uint256 private _maxRoyaltyPerMille = 150;
    bytes32 private EIP712_DOMAIN_TYPE_HASH = keccak256("EIP712Domain(string name,string version)");
    bytes32 private DOMAIN_SEPARATOR = keccak256(abi.encode(
            EIP712_DOMAIN_TYPE_HASH,
            keccak256(bytes("Quixotic")),
            keccak256(bytes("4"))
        ));
    IRoyaltyRegistry royaltyRegistry;
    ICancellationRegistry cancellationRegistry;
    IPaymentERC20Registry paymentERC20Registry;
    event SellOrderFilled(address indexed seller, address payable buyer, address indexed contractAddress, uint256 indexed tokenId, uint256 price);
    event BuyOrderFilled(address indexed seller, address payable buyer, address indexed contractAddress, uint256 indexed tokenId, uint256 price);
    event DutchAuctionFilled(address indexed seller, address payable buyer, address indexed contractAddress, uint256 indexed tokenId, uint256 price);
    struct SellOrder {
        address payable seller;
        address contractAddress;
        uint256 tokenId;
        uint256 startTime;
        uint256 expiration;
        uint256 price;
        uint256 quantity;
        uint256 createdAtBlockNumber;
        address paymentERC20;
    }
    struct BuyOrder {
        address payable buyer;
        address contractAddress;
        uint256 tokenId;
        uint256 startTime;
        uint256 expiration;
        uint256 price;
        uint256 quantity;
        address paymentERC20;
    }
    struct DutchAuctionOrder {
        address payable seller;
        address contractAddress;
        uint256 tokenId;
        uint256 startTime;
        uint256 endTime;
        uint256 startPrice;
        uint256 endPrice;
        uint256 quantity;
        uint256 createdAtBlockNumber;
        address paymentERC20;
    }
    function fillSellOrder(
        address payable seller,
        address contractAddress,
        uint256 tokenId,
        uint256 startTime,
        uint256 expiration,
        uint256 price,
        uint256 quantity,
        uint256 createdAtBlockNumber,
        address paymentERC20,
        bytes memory signature,
        address payable buyer
    ) external payable whenNotPaused nonReentrant {
        if (paymentERC20 == address(0)) {
            require(msg.value >= price, "Transaction doesn't have the required ETH amount.");
        } else {
            _checkValidERC20Payment(buyer, price, paymentERC20);
        }
        SellOrder memory sellOrder = SellOrder(
            seller,
            contractAddress,
            tokenId,
            startTime,
            expiration,
            price,
            quantity,
            createdAtBlockNumber,
            paymentERC20
        );
        require(
            cancellationRegistry.getSellOrderCancellationBlockNumber(seller, contractAddress, tokenId) < createdAtBlockNumber,
            "This order has been cancelled."
        );
        require(_validateSellerSignature(sellOrder, signature), "Signature is not valid for SellOrder.");
        require((block.timestamp > startTime), "SellOrder start time is in the future.");
        require((block.timestamp < expiration), "This sell order has expired.");
        _fillSellOrder(sellOrder, buyer);
    }
    function fillBuyOrder(
        address payable buyer,
        address contractAddress,
        uint256 tokenId,
        uint256 startTime,
        uint256 expiration,
        uint256 price,
        uint256 quantity,
        address paymentERC20,
        bytes memory signature,
        address payable seller
    ) external payable whenNotPaused nonReentrant {
        _checkValidERC20Payment(buyer, price, paymentERC20);
        require(!isOrderCancelled(signature), "This order has been cancelled.");
        BuyOrder memory buyOrder = BuyOrder(
            buyer,
            contractAddress,
            tokenId,
            startTime,
            expiration,
            price,
            quantity,
            paymentERC20
        );
        require(_validateBuyerSignature(buyOrder, signature), "Signature is not valid for BuyOrder.");
        require((block.timestamp > buyOrder.startTime), "This buy order's start time is in the future.");
        require((block.timestamp < buyOrder.expiration), "This buy order has expired.");
        _fillBuyOrder(buyOrder, signature, seller);
    }
    function fillDutchAuctionOrder(
        DutchAuctionOrder memory dutchAuctionOrder,
        bytes memory signature,
        address payable buyer
    ) external payable whenNotPaused nonReentrant {
        require(
            cancellationRegistry.getSellOrderCancellationBlockNumber(dutchAuctionOrder.seller, dutchAuctionOrder.contractAddress, dutchAuctionOrder.tokenId) < dutchAuctionOrder.createdAtBlockNumber,
            "This order has been cancelled."
        );
        require(_validateDutchAuctionSignature(dutchAuctionOrder, signature), "Signature is not valid for DutchAuctionOrder.");
        require((block.timestamp > dutchAuctionOrder.startTime), "This dutch auction order has not started yet.");
        require((block.timestamp < dutchAuctionOrder.endTime), "This dutch auction order has expired.");
        uint256 currentPrice = calculateCurrentPrice(
            dutchAuctionOrder.startTime, 
            dutchAuctionOrder.endTime, 
            dutchAuctionOrder.startPrice,
            dutchAuctionOrder.endPrice
        );
        if (dutchAuctionOrder.paymentERC20 == address(0)) {
            require(msg.value >= currentPrice, "The current price is higher than the payment submitted.");
        } else {
            _checkValidERC20Payment(buyer, currentPrice, dutchAuctionOrder.paymentERC20);
        }
        _fillDutchAuction(dutchAuctionOrder, buyer, currentPrice);
    }
    function setRoyalty(address contractAddress, address payable _payoutAddress, uint256 _payoutPerMille) external {
        require(_payoutPerMille <= _maxRoyaltyPerMille, "Royalty must be between 0 and 15%");
        require(contractAddress.supportsInterface(InterfaceId_ERC721) || contractAddress.supportsInterface(InterfaceId_ERC1155), "Is not ERC721 or ERC1155");
        Ownable ownableNFTContract = Ownable(contractAddress);
        require(_msgSender() == ownableNFTContract.owner());
        royaltyRegistry.setRoyalty(contractAddress, _payoutAddress, _payoutPerMille);
    }
    function cancelBuyOrder(
        address payable buyer,
        address contractAddress,
        uint256 tokenId,
        uint256 startTime,
        uint256 expiration,
        uint256 price,
        uint256 quantity,
        address paymentERC20,
        bytes memory signature
    ) external {
        require((buyer == _msgSender() || owner() == _msgSender()), "Caller must be Exchange Owner or Order Signer");
        BuyOrder memory buyOrder = BuyOrder(
            buyer,
            contractAddress,
            tokenId,
            startTime,
            expiration,
            price,
            quantity,
            paymentERC20
        );
        require(_validateBuyerSignature(buyOrder, signature), "Signature is not valid for BuyOrder.");
        cancellationRegistry.cancelOrder(signature);
    }
    function cancelPreviousSellOrders(
        address addr,
        address tokenAddr,
        uint256 tokenId
    ) external {
        require((addr == _msgSender() || owner() == _msgSender()), "Caller must be Exchange Owner or Order Signer");
        cancellationRegistry.cancelPreviousSellOrders(addr, tokenAddr, tokenId);
    }
    function calculateCurrentPrice(uint256 startTime, uint256 endTime, uint256 startPrice, uint256 endPrice) public view returns (uint256) {
        uint256 auctionDuration = (endTime - startTime);
        uint256 timeRemaining = (endTime - block.timestamp);
        uint256 perMilleRemaining = (1000000000000000 / auctionDuration) / (1000000000000 / timeRemaining);
        uint256 variableAmount = startPrice - endPrice;
        uint256 variableAmountRemaining = (perMilleRemaining * variableAmount) / 1000;
        return endPrice + variableAmountRemaining;
    }
    function getRoyaltyPayoutAddress(address contractAddress) external view returns (address) {
        return royaltyRegistry.getRoyaltyPayoutAddress(contractAddress);
    }
    function getRoyaltyPayoutRate(address contractAddress) external view returns (uint256) {
        return royaltyRegistry.getRoyaltyPayoutRate(contractAddress);
    }
    function isOrderCancelled(bytes memory signature) public view returns (bool) {
        return cancellationRegistry.isOrderCancelled(signature);
    }
    function setMakerWallet(address payable _newMakerWallet) external onlyOwner {
        _makerWallet = _newMakerWallet;
    }
    function setRegistryContracts(
        address _royaltyRegistry,
        address _cancellationRegistry,
        address _paymentERC20Registry
    ) external onlyOwner {
        royaltyRegistry = IRoyaltyRegistry(_royaltyRegistry);
        cancellationRegistry = ICancellationRegistry(_cancellationRegistry);
        paymentERC20Registry = IPaymentERC20Registry(_paymentERC20Registry);
    }
    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }
    function withdraw() external onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
    function _fillSellOrder(SellOrder memory sellOrder, address payable buyer) internal {
        cancellationRegistry.cancelPreviousSellOrders(sellOrder.seller, sellOrder.contractAddress, sellOrder.tokenId);
        emit SellOrderFilled(sellOrder.seller, buyer, sellOrder.contractAddress, sellOrder.tokenId, sellOrder.price);
        _transferNFT(sellOrder.contractAddress, sellOrder.tokenId, sellOrder.seller, buyer, sellOrder.quantity);
        if (sellOrder.paymentERC20 == address(0)) {
            _sendETHPaymentsWithRoyalties(sellOrder.contractAddress, sellOrder.seller);
        } else if (sellOrder.price > 0) {
            _sendERC20PaymentsWithRoyalties(
                sellOrder.contractAddress,
                sellOrder.seller,
                buyer,
                sellOrder.price,
                sellOrder.paymentERC20
            );
        }
    }
    function _sendETHPaymentsWithRoyalties(address contractAddress, address payable finalRecipient) internal {
        uint256 royaltyPayout = (royaltyRegistry.getRoyaltyPayoutRate(contractAddress) * msg.value) / 1000;
        uint256 makerPayout = (_makerFeePerMille * msg.value) / 1000;
        uint256 remainingPayout = msg.value - royaltyPayout - makerPayout;
        if (royaltyPayout > 0) {
            Address.sendValue(royaltyRegistry.getRoyaltyPayoutAddress(contractAddress), royaltyPayout);
        }
        Address.sendValue(_makerWallet, makerPayout);
        Address.sendValue(finalRecipient, remainingPayout);
    }
    function _sendERC20PaymentsWithRoyalties(
        address contractAddress,
        address seller,
        address buyer,
        uint256 price,
        address paymentERC20
    ) internal {
        uint256 royaltyPayout = (royaltyRegistry.getRoyaltyPayoutRate(contractAddress) * price) / 1000;
        uint256 makerPayout = (_makerFeePerMille * price) / 1000;
        uint256 remainingPayout = price - royaltyPayout - makerPayout;
        if (royaltyPayout > 0) {
            IERC20(paymentERC20).safeTransferFrom(
                buyer,
                royaltyRegistry.getRoyaltyPayoutAddress(contractAddress),
                royaltyPayout
            );
        }
        IERC20(paymentERC20).safeTransferFrom(buyer, _makerWallet, makerPayout);
        IERC20(paymentERC20).safeTransferFrom(buyer, seller, remainingPayout);
    }
    function _checkValidERC20Payment(address buyer, uint256 price, address paymentERC20) internal view {
        require(paymentERC20Registry.isApprovedERC20(paymentERC20), "Payment ERC20 is not approved.");
        require(
            IERC20(paymentERC20).balanceOf(buyer) >= price,
            "Buyer has an insufficient balance of the ERC20."
        );
        require(
            IERC20(paymentERC20).allowance(buyer, address(this)) >= price,
            "Exchange is not approved to handle a sufficient amount of the ERC20."
        );
    }
    function _validateSellerSignature(SellOrder memory sellOrder, bytes memory signature) internal view returns (bool) {
        bytes32 SELLORDER_TYPEHASH = keccak256(
            "SellOrder(address seller,address contractAddress,uint256 tokenId,uint256 startTime,uint256 expiration,uint256 price,uint256 quantity,uint256 createdAtBlockNumber,address paymentERC20)"
        );
        bytes32 structHash = keccak256(abi.encode(
                SELLORDER_TYPEHASH,
                sellOrder.seller,
                sellOrder.contractAddress,
                sellOrder.tokenId,
                sellOrder.startTime,
                sellOrder.expiration,
                sellOrder.price,
                sellOrder.quantity,
                sellOrder.createdAtBlockNumber,
                sellOrder.paymentERC20
            ));
        bytes32 digest = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, structHash);
        address recoveredAddress = ECDSA.recover(digest, signature);
        return recoveredAddress == sellOrder.seller;
    }
    function _validateBuyerSignature(BuyOrder memory buyOrder, bytes memory signature) internal view returns (bool) {
        bytes32 BUYORDER_TYPEHASH = keccak256(
            "BuyOrder(address buyer,address contractAddress,uint256 tokenId,uint256 startTime,uint256 expiration,uint256 price,uint256 quantity,address paymentERC20)"
        );
        bytes32 structHash = keccak256(abi.encode(
                BUYORDER_TYPEHASH,
                buyOrder.buyer,
                buyOrder.contractAddress,
                buyOrder.tokenId,
                buyOrder.startTime,
                buyOrder.expiration,
                buyOrder.price,
                buyOrder.quantity,
                buyOrder.paymentERC20
            ));
        bytes32 digest = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, structHash);
        address recoveredAddress = ECDSA.recover(digest, signature);
        return recoveredAddress == buyOrder.buyer;
    }
    function _fillBuyOrder(BuyOrder memory buyOrder, bytes memory signature, address payable seller) internal {
        cancellationRegistry.cancelOrder(signature);
        emit BuyOrderFilled(seller, buyOrder.buyer, buyOrder.contractAddress, buyOrder.tokenId, buyOrder.price);
        _transferNFT(buyOrder.contractAddress, buyOrder.tokenId, seller, buyOrder.buyer, buyOrder.quantity);
        if (buyOrder.price > 0) {
            _sendERC20PaymentsWithRoyalties(
                buyOrder.contractAddress,
                seller,
                buyOrder.buyer,
                buyOrder.price,
                buyOrder.paymentERC20
            );
        }
    }
    function _fillDutchAuction(
        DutchAuctionOrder memory dutchAuctionOrder,
        address payable buyer,
        uint256 currentPrice
    ) internal {
        cancellationRegistry.cancelPreviousSellOrders(dutchAuctionOrder.seller, dutchAuctionOrder.contractAddress, dutchAuctionOrder.tokenId);
        uint256 amountPaid = dutchAuctionOrder.paymentERC20 == address(0) ? msg.value : currentPrice;
        emit DutchAuctionFilled(dutchAuctionOrder.seller, buyer, dutchAuctionOrder.contractAddress, dutchAuctionOrder.tokenId, amountPaid);
        _transferNFT(dutchAuctionOrder.contractAddress, dutchAuctionOrder.tokenId, dutchAuctionOrder.seller, buyer, dutchAuctionOrder.quantity);
        if (dutchAuctionOrder.paymentERC20 == address(0)) {
            _sendETHPaymentsWithRoyalties(dutchAuctionOrder.contractAddress, dutchAuctionOrder.seller);
        } else if (currentPrice > 0) {
            _sendERC20PaymentsWithRoyalties(
                dutchAuctionOrder.contractAddress,
                dutchAuctionOrder.seller,
                buyer,
                currentPrice,
                dutchAuctionOrder.paymentERC20
            );
        }
    }
    function _validateDutchAuctionSignature(
        DutchAuctionOrder memory dutchAuctionOrder,
        bytes memory signature
    ) internal view returns (bool) {
        bytes32 DUTCHAUCTIONORDER_TYPEHASH = keccak256(
            "DutchAuctionOrder(address seller,address contractAddress,uint256 tokenId,uint256 startTime,uint256 endTime,uint256 startPrice,uint256 endPrice,uint256 quantity,uint256 createdAtBlockNumber,address paymentERC20)"
        );
        bytes32 structHash = keccak256(abi.encode(
                DUTCHAUCTIONORDER_TYPEHASH,
                dutchAuctionOrder.seller,
                dutchAuctionOrder.contractAddress,
                dutchAuctionOrder.tokenId,
                dutchAuctionOrder.startTime,
                dutchAuctionOrder.endTime,
                dutchAuctionOrder.startPrice,
                dutchAuctionOrder.endPrice,
                dutchAuctionOrder.quantity,
                dutchAuctionOrder.createdAtBlockNumber,
                dutchAuctionOrder.paymentERC20
            ));
        bytes32 digest = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, structHash);
        address recoveredAddress = ECDSA.recover(digest, signature);
        return recoveredAddress == dutchAuctionOrder.seller;
    }
    function _transferNFT(address contractAddress, uint256 tokenId, address seller, address buyer, uint256 quantity) internal {
        if (contractAddress.supportsInterface(InterfaceId_ERC721)) {
            IERC721 erc721 = IERC721(contractAddress);
            require(erc721.isApprovedForAll(seller, address(this)), "The Exchange is not approved to operate this NFT");
            erc721.transferFrom(seller, buyer, tokenId);
        } else if (contractAddress.supportsInterface(InterfaceId_ERC1155)) {
            IERC1155 erc1155 = IERC1155(contractAddress);
            erc1155.safeTransferFrom(seller, buyer, tokenId, quantity, "");
        } else {
            revert("We don't recognize the NFT as either an ERC721 or ERC1155.");
        }
    }
}