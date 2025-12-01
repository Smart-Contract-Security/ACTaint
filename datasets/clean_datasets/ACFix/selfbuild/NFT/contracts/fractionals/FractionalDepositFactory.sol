pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../libs/CloneFactory.sol";
import "./FractionalDeposit.sol";
import "../DInterest.sol";
import "../NFT.sol";
import "../rewards/MPHToken.sol";
contract FractionalDepositFactory is CloneFactory, IERC721Receiver {
    address public template;
    MPHToken public mph;
    event CreateClone(address _clone);
    constructor(address _template, address _mph) public {
        template = _template;
        mph = MPHToken(_mph);
    }
    function createFractionalDeposit(
        address _pool,
        uint256 _nftID,
        string calldata _tokenName,
        string calldata _tokenSymbol
    ) external returns (FractionalDeposit) {
        FractionalDeposit clone = FractionalDeposit(createClone(template));
        DInterest pool = DInterest(_pool);
        NFT nft = NFT(pool.depositNFT());
        nft.safeTransferFrom(msg.sender, address(this), _nftID);
        nft.safeTransferFrom(address(this), address(clone), _nftID);
        DInterest.Deposit memory deposit = pool.getDeposit(_nftID);
        uint256 mintMPHAmount = deposit.mintMPHAmount;
        mph.transferFrom(msg.sender, address(this), mintMPHAmount);
        mph.increaseAllowance(address(clone), mintMPHAmount);
        clone.init(
            msg.sender,
            _pool,
            address(mph),
            _nftID,
            _tokenName,
            _tokenSymbol
        );
        emit CreateClone(address(clone));
        return clone;
    }
    function isFractionalDeposit(address query) external view returns (bool) {
        return isClone(template, query);
    }
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public returns (bytes4) {
        return this.onERC721Received.selector;
    }
}