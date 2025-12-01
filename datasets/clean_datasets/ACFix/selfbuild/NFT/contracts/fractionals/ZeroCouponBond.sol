pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../DInterest.sol";
import "./FractionalDeposit.sol";
import "./FractionalDepositFactory.sol";
contract ClonedReentrancyGuard {
    bool internal _notEntered;
    modifier nonReentrant() {
        require(_notEntered, "ReentrancyGuard: reentrant call");
        _notEntered = false;
        _;
        _notEntered = true;
    }
}
contract ZeroCouponBond is ERC20, ClonedReentrancyGuard, IERC721Receiver {
    using SafeERC20 for ERC20;
    bool public initialized;
    DInterest public pool;
    FractionalDepositFactory public fractionalDepositFactory;
    ERC20 public stablecoin;
    uint256 public maturationTimestamp;
    string public name;
    string public symbol;
    uint8 public decimals;
    event Mint(
        address indexed sender,
        address indexed fractionalDepositAddress,
        uint256 amount
    );
    event RedeemFractionalDepositShares(
        address indexed sender,
        address indexed fractionalDepositAddress,
        uint256 fundingID
    );
    event RedeemStablecoin(address indexed sender, uint256 amount);
    function init(
        address _pool,
        address _fractionalDepositFactory,
        uint256 _maturationTimestamp,
        string calldata _tokenName,
        string calldata _tokenSymbol
    ) external {
        require(!initialized, "ZeroCouponBond: initialized");
        initialized = true;
        _notEntered = true;
        pool = DInterest(_pool);
        fractionalDepositFactory = FractionalDepositFactory(
            _fractionalDepositFactory
        );
        stablecoin = pool.stablecoin();
        maturationTimestamp = _maturationTimestamp;
        name = _tokenName;
        symbol = _tokenSymbol;
        decimals = ERC20Detailed(address(pool.stablecoin())).decimals();
        pool.depositNFT().setApprovalForAll(_fractionalDepositFactory, true);
        fractionalDepositFactory.mph().approve(
            _fractionalDepositFactory,
            uint256(-1)
        );
    }
    function mintWithDepositNFT(
        uint256 nftID,
        string calldata fractionalDepositName,
        string calldata fractionalDepositSymbol
    )
        external
        nonReentrant
        returns (
            uint256 zeroCouponBondsAmount,
            FractionalDeposit fractionalDeposit
        )
    {
        DInterest.Deposit memory depositStruct = pool.getDeposit(nftID);
        uint256 depositMaturationTimestamp = depositStruct.maturationTimestamp;
        require(
            depositMaturationTimestamp <= maturationTimestamp,
            "ZeroCouponBonds: maturation too late"
        );
        MPHToken mph = fractionalDepositFactory.mph();
        mph.transferFrom(
            msg.sender,
            address(this),
            depositStruct.mintMPHAmount
        );
        NFT depositNFT = pool.depositNFT();
        depositNFT.safeTransferFrom(msg.sender, address(this), nftID);
        fractionalDeposit = fractionalDepositFactory.createFractionalDeposit(
            address(pool),
            nftID,
            fractionalDepositName,
            fractionalDepositSymbol
        );
        fractionalDeposit.transferOwnership(msg.sender);
        zeroCouponBondsAmount = fractionalDeposit.totalSupply();
        _mint(msg.sender, zeroCouponBondsAmount);
        emit Mint(
            msg.sender,
            address(fractionalDeposit),
            zeroCouponBondsAmount
        );
    }
    function redeemFractionalDepositShares(
        address fractionalDepositAddress,
        uint256 fundingID
    ) external nonReentrant {
        FractionalDeposit fractionalDeposit =
            FractionalDeposit(fractionalDepositAddress);
        uint256 balance = fractionalDeposit.balanceOf(address(this));
        fractionalDeposit.redeemShares(balance, fundingID);
        emit RedeemFractionalDepositShares(
            msg.sender,
            fractionalDepositAddress,
            fundingID
        );
    }
    function redeemStablecoin(uint256 amount)
        external
        nonReentrant
        returns (uint256 actualRedeemedAmount)
    {
        require(now >= maturationTimestamp, "ZeroCouponBond: not mature");
        uint256 stablecoinBalance = stablecoin.balanceOf(address(this));
        actualRedeemedAmount = amount > stablecoinBalance
            ? stablecoinBalance
            : amount;
        _burn(msg.sender, actualRedeemedAmount);
        stablecoin.safeTransfer(msg.sender, actualRedeemedAmount);
        emit RedeemStablecoin(msg.sender, actualRedeemedAmount);
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