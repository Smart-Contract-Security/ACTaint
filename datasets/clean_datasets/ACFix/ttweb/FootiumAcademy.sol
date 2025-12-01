pragma solidity ^0.8.16;
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IFootiumPlayer} from "./interfaces/IFootiumPlayer.sol";
import {IFootiumClub} from "./interfaces/IFootiumClub.sol";
import "./common/Errors.sol";
type SeasonID is uint256;
error GenerationIDTooHigh(uint256 generationId, uint256 maxGenerationId);
error PlayerAlreadyRedeemed(uint256 generationId);
error ClubNotInDivision(uint256 clubId, uint256 divisionTier);
error PlayerTooOld(uint256 currentSeasonId);
error PlayerTooYoung(SeasonID seasonId);
error InvalidSeasonId(SeasonID seasonId);
contract FootiumAcademy is
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    IFootiumPlayer private _footiumPlayer;
    IFootiumClub private _footiumClub;
    address private _prizeDistributorAddress;
    uint256 private _maxGenerationId;
    uint256 public currentSeasonId;
    uint256 public academyMinAge;
    uint256 public academyMaxAge;
    bytes32 private _clubDivsMerkleRoot;
    mapping(SeasonID => mapping(uint256 => mapping(uint256 => bool)))
        private redeemed;
    mapping(uint256 => uint256) public divisionToFee; 
    event ChangedMaxGenerationId(uint256 indexed maxGenerationId);
    event ChangedCurrentSeasonId(uint256 indexed currentSeasonId);
    event AcademyPlayerMinted(
        SeasonID indexed seasonId,
        uint256 indexed clubId,
        uint256 indexed generationId,
        uint256 playerId
    );
    event ChangedClubDivsMerkleRoot(bytes32 merkleRoot);
    event ChangedDivisionFees(uint256[] fees);
    function initialize(
        IFootiumPlayer footiumPlayer,
        IFootiumClub footiumClub,
        address prizeDistributorAddress,
        uint256 maxGenerationId,
        uint256[] memory fees
    ) external initializer {
        __Pausable_init();
        __ReentrancyGuard_init();
        __Ownable_init();
        _footiumPlayer = footiumPlayer;
        _footiumClub = footiumClub;
        _prizeDistributorAddress = prizeDistributorAddress;
        currentSeasonId = 1;
        academyMinAge = 18;
        academyMaxAge = 20;
        setDivisionFees(fees);
        changeMaxGenerationId(maxGenerationId);
    }
    function changeMaxGenerationId(uint256 maxGenerationId) public onlyOwner {
        _maxGenerationId = maxGenerationId;
        emit ChangedMaxGenerationId(_maxGenerationId);
    }
    function setClubDivsMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        _clubDivsMerkleRoot = _merkleRoot;
        emit ChangedClubDivsMerkleRoot(_clubDivsMerkleRoot);
    }
    function setDivisionFees(uint256[] memory _fees) public onlyOwner {
        uint256 max = _fees.length;
        for (uint256 i = 0; i < max; ) {
            uint256 fee = _fees[i];
            divisionToFee[i + 1] = fee;
            unchecked {
                i++;
            }
        }
        emit ChangedDivisionFees(_fees);
    }
    function changeCurrentSeasonId(uint256 _newSeasonId) external onlyOwner {
        currentSeasonId = _newSeasonId;
        emit ChangedCurrentSeasonId(currentSeasonId);
    }
    function activateContract() external onlyOwner {
        _unpause();
    }
    function pauseContract() external onlyOwner {
        _pause();
    }
    function mintPlayers(
        SeasonID seasonId,
        uint256 clubId,
        uint256 divisionTier,
        uint256[] calldata generationIds,
        bytes32[] calldata divisionProof
    ) external payable whenNotPaused nonReentrant {
        uint256 totalFee = _validateMintingParams(
            seasonId,
            clubId,
            divisionTier,
            generationIds,
            divisionProof
        );
        uint256 generationId;
        for (uint256 i = 0; i < generationIds.length; ) {
            generationId = generationIds[i];
            if (generationId > _maxGenerationId) {
                revert GenerationIDTooHigh(generationId, _maxGenerationId);
            }
            if (redeemed[seasonId][clubId][generationId]) {
                revert PlayerAlreadyRedeemed(generationId);
            }
            redeemed[seasonId][clubId][generationId] = true;
            uint256 playerId = _footiumPlayer.safeMint(
                _footiumClub.clubToEscrow(clubId)
            );
            emit AcademyPlayerMinted(seasonId, clubId, generationId, playerId);
            unchecked {
                i++;
            }
        }
        (bool sent, ) = _prizeDistributorAddress.call{value: totalFee}("");
        if (!sent) {
            revert FailedToSendETH(totalFee);
        }
    }
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool sent, ) = payable(owner()).call{value: balance}("");
            if (!sent) {
                revert FailedToSendETH(balance);
            }
        }
    }
    function _validateMintingParams(
        SeasonID seasonId,
        uint256 clubId,
        uint256 divisionTier,
        uint256[] calldata generationIds,
        bytes32[] calldata divisionProof
    ) private returns (uint256) {
        if (
            !MerkleProofUpgradeable.verify(
                divisionProof,
                _clubDivsMerkleRoot,
                keccak256(abi.encodePacked(clubId, divisionTier))
            )
        ) {
            revert ClubNotInDivision(clubId, divisionTier);
        }
        if (msg.sender != _footiumClub.ownerOf(clubId)) {
            revert NotClubOwner(clubId, msg.sender);
        }
        if (SeasonID.unwrap(seasonId) <= 0) {
            revert InvalidSeasonId(seasonId);
        }
        if (SeasonID.unwrap(seasonId) > currentSeasonId) {
            revert PlayerTooYoung(seasonId);
        }
        uint256 playerCount = generationIds.length;
        uint256 totalFee = playerCount * divisionToFee[divisionTier];
        if (msg.value < totalFee) {
            revert IncorrectETHAmount(msg.value);
        }
        uint256 maxSeasonId = SeasonID.unwrap(seasonId) +
            academyMaxAge -
            academyMinAge;
        if (maxSeasonId < currentSeasonId) {
            revert PlayerTooOld(currentSeasonId);
        }
        return totalFee;
    }
}