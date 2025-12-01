pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;
import {Auth, Authority} from "solmate/auth/Auth.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC721} from "gpl/ERC721.sol";
import {IAuctionHouse} from "gpl/interfaces/IAuctionHouse.sol";
import {IERC721, IERC165} from "gpl/interfaces/IERC721.sol";
import {ITransferProxy} from "gpl/interfaces/ITransferProxy.sol";
import {SafeCastLib} from "gpl/utils/SafeCastLib.sol";
import {Base64} from "./libraries/Base64.sol";
import {CollateralLookup} from "./libraries/CollateralLookup.sol";
import {IAstariaRouter} from "./interfaces/IAstariaRouter.sol";
import {ICollateralToken} from "./interfaces/ICollateralToken.sol";
import {ILienBase, ILienToken} from "./interfaces/ILienToken.sol";
import {IPublicVault} from "./PublicVault.sol";
import {VaultImplementation} from "./VaultImplementation.sol";
contract TransferAgent {
  address public immutable WETH;
  ITransferProxy public immutable TRANSFER_PROXY;
  constructor(ITransferProxy _TRANSFER_PROXY, address _WETH) {
    TRANSFER_PROXY = _TRANSFER_PROXY;
    WETH = _WETH;
  }
}
contract LienToken is ERC721, ILienToken, Auth, TransferAgent {
  using FixedPointMathLib for uint256;
  using CollateralLookup for address;
  using SafeCastLib for uint256;
  IAuctionHouse public AUCTION_HOUSE;
  IAstariaRouter public ASTARIA_ROUTER;
  ICollateralToken public COLLATERAL_TOKEN;
  uint256 INTEREST_DENOMINATOR = 1e18; 
  uint256 constant MAX_LIENS = uint256(5);
  mapping(uint256 => Lien) public lienData;
  mapping(uint256 => uint256[]) public liens;
  constructor(
    Authority _AUTHORITY,
    ITransferProxy _TRANSFER_PROXY,
    address _WETH
  )
    Auth(address(msg.sender), _AUTHORITY)
    TransferAgent(_TRANSFER_PROXY, _WETH)
    ERC721("Astaria Lien Token", "ALT")
  {}
  function file(bytes32 what, bytes calldata data) external requiresAuth {
    if (what == "setAuctionHouse") {
      address addr = abi.decode(data, (address));
      AUCTION_HOUSE = IAuctionHouse(addr);
    } else if (what == "setCollateralToken") {
      address addr = abi.decode(data, (address));
      COLLATERAL_TOKEN = ICollateralToken(addr);
    } else if (what == "setAstariaRouter") {
      address addr = abi.decode(data, (address));
      ASTARIA_ROUTER = IAstariaRouter(addr);
    } else {
      revert UnsupportedFile();
    }
    emit File(what, data);
  }
  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, IERC165)
    returns (bool)
  {
    return
      interfaceId == type(ILienToken).interfaceId ||
      super.supportsInterface(interfaceId);
  }
  function buyoutLien(ILienToken.LienActionBuyout calldata params) external {
    (bool valid, IAstariaRouter.LienDetails memory ld) = ASTARIA_ROUTER
      .validateCommitment(params.incoming);
    if (!valid) {
      revert InvalidTerms();
    }
    uint256 collateralId = params.incoming.tokenContract.computeId(
      params.incoming.tokenId
    );
    (uint256 owed, uint256 buyout) = getBuyout(collateralId, params.position);
    uint256 lienId = liens[collateralId][params.position];
    if (ld.maxAmount < owed) {
      revert InvalidBuyoutDetails(ld.maxAmount, owed);
    }
    if (!ASTARIA_ROUTER.isValidRefinance(lienData[lienId], ld)) {
      revert InvalidRefinance();
    }
    TRANSFER_PROXY.tokenTransferFrom(
      WETH,
      address(msg.sender),
      getPayee(lienId),
      uint256(buyout)
    );
    lienData[lienId].last = block.timestamp.safeCastTo32();
    lienData[lienId].start = block.timestamp.safeCastTo32();
    lienData[lienId].rate = ld.rate.safeCastTo240();
    lienData[lienId].duration = ld.duration.safeCastTo32();
    _transfer(ownerOf(lienId), address(params.receiver), lienId);
  }
  function getInterest(uint256 collateralId, uint256 position)
    public
    view
    returns (uint256)
  {
    uint256 lien = liens[collateralId][position];
    return _getInterest(lienData[lien], block.timestamp);
  }
  function _getInterest(Lien memory lien, uint256 timestamp)
    internal
    view
    returns (uint256)
  {
    if (!lien.active) {
      return uint256(0);
    }
    uint256 delta_t;
    if (block.timestamp >= lien.start + lien.duration) {
      delta_t = uint256(lien.start + lien.duration - lien.last);
    } else {
      delta_t = uint256(timestamp.safeCastTo32() - lien.last);
    }
    return
      delta_t.mulDivDown(lien.rate, 1).mulDivDown(
        lien.amount,
        INTEREST_DENOMINATOR
      );
  }
  function stopLiens(uint256 collateralId)
    external
    requiresAuth
    returns (uint256 reserve, uint256[] memory lienIds)
  {
    reserve = 0;
    lienIds = liens[collateralId];
    for (uint256 i = 0; i < lienIds.length; ++i) {
      Lien storage lien = lienData[lienIds[i]];
      unchecked {
        lien.amount = _getOwed(lien);
        reserve += lien.amount;
      }
      lien.active = false;
    }
  }
  function tokenURI(uint256 tokenId)
    public
    pure
    override
    returns (string memory)
  {
    return "";
  }
  function createLien(ILienBase.LienActionEncumber memory params)
    external
    requiresAuth
    returns (uint256 lienId)
  {
    uint256 collateralId = params.tokenContract.computeId(params.tokenId);
    if (AUCTION_HOUSE.auctionExists(collateralId)) {
      revert InvalidCollateralState(InvalidStates.AUCTION);
    }
    (address tokenContract, ) = COLLATERAL_TOKEN.getUnderlying(collateralId);
    if (tokenContract == address(0)) {
      revert InvalidCollateralState(InvalidStates.NO_DEPOSIT);
    }
    uint256 totalDebt = getTotalDebtForCollateralToken(collateralId);
    uint256 impliedRate = getImpliedRate(collateralId);
    uint256 potentialDebt = totalDebt *
      (impliedRate + 1) *
      params.terms.duration;
    if (potentialDebt > params.terms.maxPotentialDebt) {
      revert InvalidCollateralState(InvalidStates.DEBT_LIMIT);
    }
    lienId = uint256(
      keccak256(
        abi.encodePacked(
          abi.encode(
            bytes32(collateralId),
            params.vault,
            WETH,
            params.terms.maxAmount,
            params.terms.rate,
            params.terms.duration,
            params.terms.maxPotentialDebt
          ),
          params.strategyRoot
        )
      )
    );
    require(
      uint256(liens[collateralId].length) < MAX_LIENS,
      "too many liens active"
    );
    uint8 newPosition = uint8(liens[collateralId].length);
    _mint(VaultImplementation(params.vault).recipient(), lienId);
    lienData[lienId] = Lien({
      collateralId: collateralId,
      position: newPosition,
      amount: params.amount,
      active: true,
      rate: params.terms.rate.safeCastTo240(),
      last: block.timestamp.safeCastTo32(),
      start: block.timestamp.safeCastTo32(),
      duration: params.terms.duration.safeCastTo32(),
      payee: address(0)
    });
    liens[collateralId].push(lienId);
    emit NewLien(lienId, lienData[lienId]);
  }
  function removeLiens(uint256 collateralId, uint256[] memory remainingLiens)
    external
    requiresAuth
  {
    for (uint256 i = 0; i < remainingLiens.length; i++) {
      delete lienData[remainingLiens[i]];
      _burn(remainingLiens[i]);
    }
    delete liens[collateralId];
    emit RemovedLiens(collateralId);
  }
  function getLiens(uint256 collateralId)
    public
    view
    returns (uint256[] memory)
  {
    return liens[collateralId];
  }
  function getLien(uint256 lienId) public view returns (Lien memory lien) {
    lien = lienData[lienId];
    lien.amount = _getOwed(lien);
    lien.last = block.timestamp.safeCastTo32();
  }
  function getLien(uint256 collateralId, uint256 position)
    public
    view
    returns (Lien memory)
  {
    uint256 lienId = liens[collateralId][position];
    return getLien(lienId);
  }
  function getBuyout(uint256 collateralId, uint256 position)
    public
    view
    returns (uint256, uint256)
  {
    Lien memory lien = getLien(collateralId, position);
    uint256 remainingInterest = _getRemainingInterest(lien, true);
    uint256 buyoutTotal = lien.amount +
      ASTARIA_ROUTER.getBuyoutFee(remainingInterest);
    return (lien.amount, buyoutTotal);
  }
  function makePayment(uint256 collateralId, uint256 paymentAmount) public {
    _makePayment(collateralId, paymentAmount);
  }
  function makePayment(
    uint256 collateralId,
    uint256 paymentAmount,
    uint8 position
  ) external {
    _payment(collateralId, position, paymentAmount, address(msg.sender));
  }
  function _makePayment(uint256 collateralId, uint256 totalCapitalAvailable)
    internal
  {
    uint256[] memory openLiens = liens[collateralId];
    uint256 paymentAmount = totalCapitalAvailable;
    for (uint256 i = 0; i < openLiens.length; ++i) {
      uint256 capitalSpent = _payment(
        collateralId,
        uint8(i),
        paymentAmount,
        address(msg.sender)
      );
      paymentAmount -= capitalSpent;
    }
  }
  function makePayment(
    uint256 collateralId,
    uint256 paymentAmount,
    uint8 position,
    address payer
  ) public requiresAuth {
    _payment(collateralId, position, paymentAmount, payer);
  }
  function calculateSlope(uint256 lienId) public view returns (uint256) {
    Lien memory lien = lienData[lienId];
    uint256 end = (lien.start + lien.duration);
    uint256 owedAtEnd = _getOwed(lien, end);
    return (owedAtEnd - lien.amount).mulDivDown(1, end - lien.last);
  }
  function changeInSlope(uint256 lienId, uint256 paymentAmount)
    public
    view
    returns (uint256 slope)
  {
    Lien memory lien = lienData[lienId];
    uint256 oldSlope = calculateSlope(lienId);
    uint256 newAmount = (lien.amount - paymentAmount);
    uint256 newSlope = newAmount.mulDivDown(
      (uint256(lien.rate).mulDivDown(lien.duration, 1) - 1),
      lien.duration
    );
    slope = oldSlope - newSlope;
  }
  function getTotalDebtForCollateralToken(uint256 collateralId)
    public
    view
    returns (uint256 totalDebt)
  {
    uint256[] memory openLiens = getLiens(collateralId);
    totalDebt = 0;
    for (uint256 i = 0; i < openLiens.length; ++i) {
      totalDebt += _getOwed(lienData[openLiens[i]]);
    }
  }
  function getTotalDebtForCollateralToken(
    uint256 collateralId,
    uint256 timestamp
  ) public view returns (uint256 totalDebt) {
    uint256[] memory openLiens = getLiens(collateralId);
    totalDebt = 0;
    for (uint256 i = 0; i < openLiens.length; ++i) {
      totalDebt += _getOwed(lienData[openLiens[i]], timestamp);
    }
  }
  function getImpliedRate(uint256 collateralId)
    public
    view
    returns (uint256 impliedRate)
  {
    uint256 totalDebt = getTotalDebtForCollateralToken(collateralId);
    uint256[] memory openLiens = getLiens(collateralId);
    impliedRate = 0;
    for (uint256 i = 0; i < openLiens.length; ++i) {
      Lien memory lien = lienData[openLiens[i]];
      impliedRate += lien.rate * lien.amount;
    }
    if (totalDebt > uint256(0)) {
      impliedRate = impliedRate.mulDivDown(1, totalDebt);
    }
  }
  function _getOwed(Lien memory lien) internal view returns (uint256) {
    return _getOwed(lien, block.timestamp);
  }
  function _getOwed(Lien memory lien, uint256 timestamp)
    internal
    view
    returns (uint256)
  {
    return lien.amount + _getInterest(lien, timestamp);
  }
  function _getRemainingInterest(Lien memory lien, bool buyout)
    internal
    view
    returns (uint256)
  {
    uint256 end = lien.start + lien.duration;
    if (buyout) {
      uint32 getBuyoutInterestWindow = ASTARIA_ROUTER.getBuyoutInterestWindow();
      if (
        lien.start + lien.duration >= block.timestamp + getBuyoutInterestWindow
      ) {
        end = block.timestamp + getBuyoutInterestWindow;
      }
    }
    uint256 delta_t = end - block.timestamp;
    return
      delta_t.mulDivDown(lien.rate, 1).mulDivDown(
        lien.amount,
        INTEREST_DENOMINATOR
      );
  }
  function getInterest(uint256 lienId) public view returns (uint256) {
    return _getInterest(lienData[lienId], block.timestamp);
  }
  function _payment(
    uint256 collateralId,
    uint8 position,
    uint256 paymentAmount,
    address payer
  ) internal returns (uint256) {
    if (paymentAmount == uint256(0)) {
      return uint256(0);
    }
    uint256 lienId = liens[collateralId][position];
    Lien storage lien = lienData[lienId];
    uint256 end = (lien.start + lien.duration);
    require(
      block.timestamp < end || address(msg.sender) == address(AUCTION_HOUSE),
      "cannot pay off an expired lien"
    );
    address lienOwner = ownerOf(lienId);
    bool isPublicVault = IPublicVault(lienOwner).supportsInterface(
      type(IPublicVault).interfaceId
    );
    lien.amount = _getOwed(lien);
    address payee = getPayee(lienId);
    if (isPublicVault) {
      IPublicVault(lienOwner).beforePayment(lienId, paymentAmount);
    }
    if (lien.amount > paymentAmount) {
      lien.amount -= paymentAmount;
      lien.last = block.timestamp.safeCastTo32();
      if (isPublicVault) {
        IPublicVault(lienOwner).afterPayment(lienId);
      }
    } else {
      if (isPublicVault && !AUCTION_HOUSE.auctionExists(collateralId)) {
        IPublicVault(lienOwner).decreaseEpochLienCount(
          IPublicVault(lienOwner).getLienEpoch(end)
        );
      }
      _deleteLienPosition(collateralId, position);
      delete lienData[lienId]; 
      _burn(lienId);
    }
    TRANSFER_PROXY.tokenTransferFrom(WETH, payer, payee, paymentAmount);
    emit Payment(lienId, paymentAmount);
    return paymentAmount;
  }
  function _deleteLienPosition(uint256 collateralId, uint256 position) public {
    uint256[] storage stack = liens[collateralId];
    require(position < stack.length, "index out of bounds");
    emit RemoveLien(
      stack[position],
      lienData[stack[position]].collateralId,
      lienData[stack[position]].position
    );
    for (uint256 i = position; i < stack.length - 1; i++) {
      stack[i] = stack[i + 1];
    }
    stack.pop();
  }
  function getPayee(uint256 lienId) public view returns (address) {
    return
      lienData[lienId].payee != address(0)
        ? lienData[lienId].payee
        : ownerOf(lienId);
  }
  function setPayee(uint256 lienId, address newPayee) public {
    if (AUCTION_HOUSE.auctionExists(lienData[lienId].collateralId)) {
      revert InvalidCollateralState(InvalidStates.AUCTION);
    }
    require(
      !AUCTION_HOUSE.auctionExists(lienData[lienId].collateralId),
      "collateralId is being liquidated, cannot change payee from LiquidationAccountant"
    );
    require(
      msg.sender == ownerOf(lienId) || msg.sender == address(ASTARIA_ROUTER),
      "invalid owner"
    );
    lienData[lienId].payee = newPayee;
    emit PayeeChanged(lienId, newPayee);
  }
}