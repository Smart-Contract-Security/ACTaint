// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IFootiumClub} from "./interfaces/IFootiumClub.sol";
import "./common/Errors.sol";

/**
 * @title General Payment Contract
 * @notice The contract is used to pay for future features
 */
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

    /**
     * @dev Initializes the FootiumGeneralPaymentContract contract.
     * @param _paymentReceiverAddress The address of the payment receiver (Footium Prize Distributor).
     * @param _footiumClub The address of the Footium clubs contract.
     */
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

    /**
     * @notice Updates payment receiver address.
     * @param _paymentReceiverAddress Payment receiver address ty be set.
     * @dev Only the contract owner can set a new URI.
     * Emits a {PaymentReceiverUpdated} event.
     */
    function setPaymentReceiverAddress(address _paymentReceiverAddress)
        external
        onlyOwner
    {
        paymentReceiverAddress = _paymentReceiverAddress;

        emit PaymentReceiverUpdated(paymentReceiverAddress);
    }

    /**
     * @notice Unpause the contract
     * @dev Only owner address allowed.
     */
    function activateContract() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Pause the contract
     * @dev Only owner address allowed.
     */
    function pauseContract() external onlyOwner {
        _pause();
    }

    /**
     * @notice Makes a payment for the given feature.
     * @param _clubId Club ID.
     * @param _message A message describing a feature to pay for.
     * @dev This function is payable.
     * Emits a {PaymentMade} event.
     */
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