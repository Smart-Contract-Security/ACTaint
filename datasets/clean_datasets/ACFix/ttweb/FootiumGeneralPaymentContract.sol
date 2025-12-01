pragma solidity ^0.8.16;
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IFootiumClub} from "./interfaces/IFootiumClub.sol";
import "./common/Errors.sol";
contract FootiumGeneralPaymentContract is
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    IFootiumClub public footiumClub;
    address public paymentReceiverAddress;
    event PaymentReceiverUpdated(address indexed paymentReceiverAddress);
    event PaymentMade(
        uint256 indexed clubId,
        uint256 indexed amount,
        string message
    );
    function initialize(
        address _paymentReceiverAddress,
        IFootiumClub _footiumClub
    ) external initializer {
        __Pausable_init();
        __ReentrancyGuard_init();
        __Ownable_init();
        paymentReceiverAddress = _paymentReceiverAddress;
        footiumClub = _footiumClub;
    }
    function setPaymentReceiverAddress(address _paymentReceiverAddress)
        external
        onlyOwner
    {
        paymentReceiverAddress = _paymentReceiverAddress;
        emit PaymentReceiverUpdated(paymentReceiverAddress);
    }
    function activateContract() external onlyOwner {
        _unpause();
    }
    function pauseContract() external onlyOwner {
        _pause();
    }
    function makePayment(uint256 _clubId, string calldata _message)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        if (msg.sender != footiumClub.ownerOf(_clubId)) {
            revert NotClubOwner(_clubId, msg.sender);
        }
        if (msg.value <= 0) {
            revert IncorrectETHAmount(msg.value);
        }
        (bool sent, ) = paymentReceiverAddress.call{value: msg.value}("");
        if (!sent) {
            revert FailedToSendETH(msg.value);
        }
        emit PaymentMade(_clubId, msg.value, _message);
    }
}