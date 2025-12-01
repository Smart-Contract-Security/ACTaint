pragma solidity =0.8.15;
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '../libraries/ChainId.sol';
import '../interfaces/external/IERC1271.sol';
import '../interfaces/IERC721Permit.sol';
import './BlockTimestamp.sol';
abstract contract ERC721Permit is BlockTimestamp, ERC721Enumerable, IERC721Permit {
    function _getAndIncrementNonce(uint256 tokenId) internal virtual returns (uint256);
    bytes32 private immutable nameHash;
    bytes32 private immutable versionHash;
    constructor(
        string memory name_,
        string memory symbol_,
        string memory version_
    ) ERC721(name_, symbol_) {
        nameHash = keccak256(bytes(name_));
        versionHash = keccak256(bytes(version_));
    }
    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                    nameHash,
                    versionHash,
                    ChainId.get(),
                    address(this)
                )
            );
    }
    bytes32 public constant override PERMIT_TYPEHASH =
        0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;
    function permit(
        address spender,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable override {
        require(_blockTimestamp() <= deadline, 'Permit expired');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(PERMIT_TYPEHASH, spender, tokenId, _getAndIncrementNonce(tokenId), deadline))
            )
        );
        address owner = ownerOf(tokenId);
        require(spender != owner, 'ERC721Permit: approval to current owner');
        if (Address.isContract(owner)) {
            require(IERC1271(owner).isValidSignature(digest, abi.encodePacked(r, s, v)) == 0x1626ba7e, 'Unauthorized');
        } else {
            address recoveredAddress = ecrecover(digest, v, r, s);
            require(recoveredAddress != address(0), 'Invalid signature');
            require(recoveredAddress == owner, 'Unauthorized');
        }
        _approve(spender, tokenId);
    }
}