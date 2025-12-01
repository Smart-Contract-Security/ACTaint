pragma solidity 0.5.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./imports/CurveZapIn.sol";
import "../DInterest.sol";
import "../NFT.sol";
contract ZapCurve is IERC721Receiver {
    using SafeERC20 for ERC20;
    modifier active {
        isActive = true;
        _;
        isActive = false;
    }
    CurveZapIn public constant zapper =
        CurveZapIn(0xf9A724c2607E5766a7Bbe530D6a7e173532F9f3a);
    bool public isActive;
    function zapCurveDeposit(
        address pool,
        address swapAddress,
        address inputToken,
        uint256 inputTokenAmount,
        uint256 minOutputTokenAmount,
        uint256 maturationTimestamp
    ) external active {
        DInterest poolContract = DInterest(pool);
        ERC20 stablecoin = poolContract.stablecoin();
        NFT depositNFT = poolContract.depositNFT();
        uint256 outputTokenAmount =
            _zapTokenInCurve(
                swapAddress,
                inputToken,
                inputTokenAmount,
                minOutputTokenAmount
            );
        stablecoin.safeIncreaseAllowance(pool, outputTokenAmount);
        poolContract.deposit(outputTokenAmount, maturationTimestamp);
        uint256 nftID = poolContract.depositsLength();
        depositNFT.safeTransferFrom(address(this), msg.sender, nftID);
    }
    function zapCurveFundAll(
        address pool,
        address swapAddress,
        address inputToken,
        uint256 inputTokenAmount,
        uint256 minOutputTokenAmount
    ) external active {
        DInterest poolContract = DInterest(pool);
        ERC20 stablecoin = poolContract.stablecoin();
        NFT fundingNFT = poolContract.fundingNFT();
        uint256 outputTokenAmount =
            _zapTokenInCurve(
                swapAddress,
                inputToken,
                inputTokenAmount,
                minOutputTokenAmount
            );
        stablecoin.safeIncreaseAllowance(pool, outputTokenAmount);
        poolContract.fundAll();
        uint256 nftID = poolContract.fundingListLength();
        fundingNFT.safeTransferFrom(address(this), msg.sender, nftID);
    }
    function zapCurveFundMultiple(
        address pool,
        address swapAddress,
        address inputToken,
        uint256 inputTokenAmount,
        uint256 minOutputTokenAmount,
        uint256 toDepositID
    ) external active {
        DInterest poolContract = DInterest(pool);
        ERC20 stablecoin = poolContract.stablecoin();
        NFT fundingNFT = poolContract.fundingNFT();
        uint256 outputTokenAmount =
            _zapTokenInCurve(
                swapAddress,
                inputToken,
                inputTokenAmount,
                minOutputTokenAmount
            );
        stablecoin.safeIncreaseAllowance(pool, outputTokenAmount);
        poolContract.fundMultiple(toDepositID);
        uint256 nftID = poolContract.fundingListLength();
        fundingNFT.safeTransferFrom(address(this), msg.sender, nftID);
    }
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public returns (bytes4) {
        require(isActive, "ZapCurve: inactive");
        return this.onERC721Received.selector;
    }
    function _zapTokenInCurve(
        address swapAddress,
        address inputToken,
        uint256 inputTokenAmount,
        uint256 minOutputTokenAmount
    ) internal returns (uint256 outputTokenAmount) {
        ERC20 inputTokenContract = ERC20(inputToken);
        inputTokenContract.safeTransferFrom(
            msg.sender,
            address(this),
            inputTokenAmount
        );
        inputTokenContract.safeIncreaseAllowance(
            address(zapper),
            inputTokenAmount
        );
        outputTokenAmount = zapper.ZapIn(
            address(this),
            inputToken,
            swapAddress,
            inputTokenAmount,
            minOutputTokenAmount
        );
    }
}