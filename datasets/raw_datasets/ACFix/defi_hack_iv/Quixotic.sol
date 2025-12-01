/*
    * @dev External trade function. This accepts the details of the sell order and signed sell
    * order (the signature) as a meta-transaction.
    *
    * Emits a {SellOrderFilled} event via `_fillSellOrder`.
    */
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
        // If the payment ERC20 is the zero address, we check that enough native ETH has been sent
        // with the transaction. Otherwise, we use the supplied ERC20 payment token.
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

        /* Make sure the order is not cancelled */
        require(
            cancellationRegistry.getSellOrderCancellationBlockNumber(seller, contractAddress, tokenId) < createdAtBlockNumber,
            "This order has been cancelled."
        );

        /* Check signature */
        require(_validateSellerSignature(sellOrder, signature), "Signature is not valid for SellOrder."); //vulnerable point

        // Check has started
        require((block.timestamp > startTime), "SellOrder start time is in the future.");

        // Check not expired
        require((block.timestamp < expiration), "This sell order has expired.");

        _fillSellOrder(sellOrder, buyer);
    }