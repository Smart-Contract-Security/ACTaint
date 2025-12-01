function buyItem(
        address _nftAddress,
        uint256 _tokenId,
        address _owner,
        uint256 _quantity
    )
        external
        nonReentrant
        isListed(_nftAddress, _tokenId, _owner)
        validListing(_nftAddress, _tokenId, _owner)
    {
        require(_msgSender() != _owner, "Cannot buy your own item");

        Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];
        require(listedItem.quantity >= _quantity, "not enough quantity");  //vulnerable point, insufficient validation.

        // Transfer NFT to buyer
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(_nftAddress).safeTransferFrom(_owner, _msgSender(), _tokenId);
        } else {
            IERC1155(_nftAddress).safeTransferFrom(_owner, _msgSender(), _tokenId, _quantity, bytes(""));
        }

        if (listedItem.quantity == _quantity) {
            delete (listings[_nftAddress][_tokenId][_owner]);
        } else {
            listings[_nftAddress][_tokenId][_owner].quantity -= _quantity;
        }

        emit ItemSold(
            _owner,
            _msgSender(),
            _nftAddress,
            _tokenId,
            _quantity,
            listedItem.pricePerItem
        );

        TreasureNFTOracle(oracle).reportSale(_nftAddress, _tokenId, paymentToken, listedItem.pricePerItem);
        _buyItem(listedItem.pricePerItem, _quantity, _owner);
    }

function _buyItem(
        uint256 _pricePerItem,
        uint256 _quantity,
        address _owner
    ) internal {
        uint256 totalPrice = _pricePerItem * _quantity; // since _quantity can be zero, so attacker can buy NFT for free
        uint256 feeAmount = totalPrice * fee / BASIS_POINTS;
        IERC20(paymentToken).safeTransferFrom(_msgSender(), feeReceipient, feeAmount);
        IERC20(paymentToken).safeTransferFrom(_msgSender(), _owner, totalPrice - feeAmount);
    }