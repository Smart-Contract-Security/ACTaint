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