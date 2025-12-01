pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "./interfaces/ICollateralManager.sol";
import { Collateral, CollateralType, ICollateralEscrowV1 } from "./interfaces/escrow/ICollateralEscrowV1.sol";
import "./interfaces/ITellerV2.sol";
contract CollateralManager is OwnableUpgradeable, ICollateralManager {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    ITellerV2 public tellerV2;
    address private collateralEscrowBeacon; 
    mapping(uint256 => address) public _escrows; 
    mapping(uint256 => CollateralInfo) internal _bidCollaterals;
    struct CollateralInfo {
        EnumerableSetUpgradeable.AddressSet collateralAddresses;
        mapping(address => Collateral) collateralInfo;
    }
    event CollateralEscrowDeployed(uint256 _bidId, address _collateralEscrow);
    event CollateralCommitted(
        uint256 _bidId,
        CollateralType _type,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId
    );
    event CollateralClaimed(uint256 _bidId);
    event CollateralDeposited(
        uint256 _bidId,
        CollateralType _type,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId
    );
    event CollateralWithdrawn(
        uint256 _bidId,
        CollateralType _type,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId,
        address _recipient
    );
    modifier onlyTellerV2() {
        require(_msgSender() == address(tellerV2), "Sender not authorized");
        _;
    }
    function initialize(address _collateralEscrowBeacon, address _tellerV2)
        external
        initializer
    {
        collateralEscrowBeacon = _collateralEscrowBeacon;
        tellerV2 = ITellerV2(_tellerV2);
        __Ownable_init_unchained();
    }
    function setCollateralEscrowBeacon(address _collateralEscrowBeacon)
        external
        reinitializer(2)
    {
        collateralEscrowBeacon = _collateralEscrowBeacon;
    }
    function isBidCollateralBacked(uint256 _bidId)
        public
        virtual
        returns (bool)
    {
        return _bidCollaterals[_bidId].collateralAddresses.length() > 0;
    }
    function commitCollateral(
        uint256 _bidId,
        Collateral[] calldata _collateralInfo
    ) public returns (bool validation_) {
        address borrower = tellerV2.getLoanBorrower(_bidId);
        (validation_, ) = checkBalances(borrower, _collateralInfo);
        if (validation_) {
            for (uint256 i; i < _collateralInfo.length; i++) {
                Collateral memory info = _collateralInfo[i];
                _commitCollateral(_bidId, info);
            }
        }
    }
    function commitCollateral(
        uint256 _bidId,
        Collateral calldata _collateralInfo
    ) public returns (bool validation_) {
        address borrower = tellerV2.getLoanBorrower(_bidId);
        validation_ = _checkBalance(borrower, _collateralInfo);
        if (validation_) {
            _commitCollateral(_bidId, _collateralInfo);
        }
    }
    function revalidateCollateral(uint256 _bidId)
        external
        returns (bool validation_)
    {
        Collateral[] memory collateralInfos = getCollateralInfo(_bidId);
        address borrower = tellerV2.getLoanBorrower(_bidId);
        (validation_, ) = _checkBalances(borrower, collateralInfos, true);
    }
    function checkBalances(
        address _borrowerAddress,
        Collateral[] calldata _collateralInfo
    ) public returns (bool validated_, bool[] memory checks_) {
        return _checkBalances(_borrowerAddress, _collateralInfo, false);
    }
    function deployAndDeposit(uint256 _bidId) external onlyTellerV2 {
        if (isBidCollateralBacked(_bidId)) {
            (address proxyAddress, ) = _deployEscrow(_bidId);
            _escrows[_bidId] = proxyAddress;
            for (
                uint256 i;
                i < _bidCollaterals[_bidId].collateralAddresses.length();
                i++
            ) {
                _deposit(
                    _bidId,
                    _bidCollaterals[_bidId].collateralInfo[
                        _bidCollaterals[_bidId].collateralAddresses.at(i)
                    ]
                );
            }
            emit CollateralEscrowDeployed(_bidId, proxyAddress);
        }
    }
    function getEscrow(uint256 _bidId) external view returns (address) {
        return _escrows[_bidId];
    }
    function getCollateralInfo(uint256 _bidId)
        public
        view
        returns (Collateral[] memory infos_)
    {
        CollateralInfo storage collateral = _bidCollaterals[_bidId];
        address[] memory collateralAddresses = collateral
            .collateralAddresses
            .values();
        infos_ = new Collateral[](collateralAddresses.length);
        for (uint256 i; i < collateralAddresses.length; i++) {
            infos_[i] = collateral.collateralInfo[collateralAddresses[i]];
        }
    }
    function getCollateralAmount(uint256 _bidId, address _collateralAddress)
        public
        view
        returns (uint256 amount_)
    {
        amount_ = _bidCollaterals[_bidId]
            .collateralInfo[_collateralAddress]
            ._amount;
    }
    function withdraw(uint256 _bidId) external {
        BidState bidState = tellerV2.getBidState(_bidId);
        if (bidState == BidState.PAID) {
            _withdraw(_bidId, tellerV2.getLoanBorrower(_bidId));
        } else if (tellerV2.isLoanDefaulted(_bidId)) {
            _withdraw(_bidId, tellerV2.getLoanLender(_bidId));
            emit CollateralClaimed(_bidId);
        } else {
            revert("collateral cannot be withdrawn");
        }
    }
    function liquidateCollateral(uint256 _bidId, address _liquidatorAddress)
        external
        onlyTellerV2
    {
        if (isBidCollateralBacked(_bidId)) {
            BidState bidState = tellerV2.getBidState(_bidId);
            require(
                bidState == BidState.LIQUIDATED,
                "Loan has not been liquidated"
            );
            _withdraw(_bidId, _liquidatorAddress);
        }
    }
    function _deployEscrow(uint256 _bidId)
        internal
        virtual
        returns (address proxyAddress_, address borrower_)
    {
        proxyAddress_ = _escrows[_bidId];
        borrower_ = tellerV2.getLoanBorrower(_bidId);
        if (proxyAddress_ == address(0)) {
            require(borrower_ != address(0), "Bid does not exist");
            BeaconProxy proxy = new BeaconProxy(
                collateralEscrowBeacon,
                abi.encodeWithSelector(
                    ICollateralEscrowV1.initialize.selector,
                    _bidId
                )
            );
            proxyAddress_ = address(proxy);
        }
    }
    function _deposit(uint256 _bidId, Collateral memory collateralInfo)
        internal
        virtual
    {
        require(collateralInfo._amount > 0, "Collateral not validated");
        (address escrowAddress, address borrower) = _deployEscrow(_bidId);
        ICollateralEscrowV1 collateralEscrow = ICollateralEscrowV1(
            escrowAddress
        );
        if (collateralInfo._collateralType == CollateralType.ERC20) {
            IERC20Upgradeable(collateralInfo._collateralAddress).transferFrom(
                borrower,
                address(this),
                collateralInfo._amount
            );
            IERC20Upgradeable(collateralInfo._collateralAddress).approve(
                escrowAddress,
                collateralInfo._amount
            );
            collateralEscrow.depositAsset(
                CollateralType.ERC20,
                collateralInfo._collateralAddress,
                collateralInfo._amount,
                0
            );
        } else if (collateralInfo._collateralType == CollateralType.ERC721) {
            IERC721Upgradeable(collateralInfo._collateralAddress).transferFrom(
                borrower,
                address(this),
                collateralInfo._tokenId
            );
            IERC721Upgradeable(collateralInfo._collateralAddress).approve(
                escrowAddress,
                collateralInfo._tokenId
            );
            collateralEscrow.depositAsset(
                CollateralType.ERC721,
                collateralInfo._collateralAddress,
                collateralInfo._amount,
                collateralInfo._tokenId
            );
        } else if (collateralInfo._collateralType == CollateralType.ERC1155) {
            bytes memory data;
            IERC1155Upgradeable(collateralInfo._collateralAddress)
                .safeTransferFrom(
                    borrower,
                    address(this),
                    collateralInfo._tokenId,
                    collateralInfo._amount,
                    data
                );
            IERC1155Upgradeable(collateralInfo._collateralAddress)
                .setApprovalForAll(escrowAddress, true);
            collateralEscrow.depositAsset(
                CollateralType.ERC1155,
                collateralInfo._collateralAddress,
                collateralInfo._amount,
                collateralInfo._tokenId
            );
        } else {
            revert("Unexpected collateral type");
        }
        emit CollateralDeposited(
            _bidId,
            collateralInfo._collateralType,
            collateralInfo._collateralAddress,
            collateralInfo._amount,
            collateralInfo._tokenId
        );
    }
    function _withdraw(uint256 _bidId, address _receiver) internal virtual {
        for (
            uint256 i;
            i < _bidCollaterals[_bidId].collateralAddresses.length();
            i++
        ) {
            Collateral storage collateralInfo = _bidCollaterals[_bidId]
                .collateralInfo[
                    _bidCollaterals[_bidId].collateralAddresses.at(i)
                ];
            ICollateralEscrowV1(_escrows[_bidId]).withdraw(
                collateralInfo._collateralAddress,
                collateralInfo._amount,
                _receiver
            );
            emit CollateralWithdrawn(
                _bidId,
                collateralInfo._collateralType,
                collateralInfo._collateralAddress,
                collateralInfo._amount,
                collateralInfo._tokenId,
                _receiver
            );
        }
    }
    function _commitCollateral(
        uint256 _bidId,
        Collateral memory _collateralInfo
    ) internal virtual {
        CollateralInfo storage collateral = _bidCollaterals[_bidId];
        collateral.collateralAddresses.add(_collateralInfo._collateralAddress);
        collateral.collateralInfo[
            _collateralInfo._collateralAddress
        ] = _collateralInfo;
        emit CollateralCommitted(
            _bidId,
            _collateralInfo._collateralType,
            _collateralInfo._collateralAddress,
            _collateralInfo._amount,
            _collateralInfo._tokenId
        );
    }
    function _checkBalances(
        address _borrowerAddress,
        Collateral[] memory _collateralInfo,
        bool _shortCircut
    ) internal virtual returns (bool validated_, bool[] memory checks_) {
        checks_ = new bool[](_collateralInfo.length);
        validated_ = true;
        for (uint256 i; i < _collateralInfo.length; i++) {
            bool isValidated = _checkBalance(
                _borrowerAddress,
                _collateralInfo[i]
            );
            checks_[i] = isValidated;
            if (!isValidated) {
                validated_ = false;
                if (_shortCircut) {
                    return (validated_, checks_);
                }
            }
        }
    }
    function _checkBalance(
        address _borrowerAddress,
        Collateral memory _collateralInfo
    ) internal virtual returns (bool) {
        CollateralType collateralType = _collateralInfo._collateralType;
        if (collateralType == CollateralType.ERC20) {
            return
                _collateralInfo._amount <=
                IERC20Upgradeable(_collateralInfo._collateralAddress).balanceOf(
                    _borrowerAddress
                );
        } else if (collateralType == CollateralType.ERC721) {
            return
                _borrowerAddress ==
                IERC721Upgradeable(_collateralInfo._collateralAddress).ownerOf(
                    _collateralInfo._tokenId
                );
        } else if (collateralType == CollateralType.ERC1155) {
            return
                _collateralInfo._amount <=
                IERC1155Upgradeable(_collateralInfo._collateralAddress)
                    .balanceOf(_borrowerAddress, _collateralInfo._tokenId);
        } else {
            return false;
        }
    }
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
    function onERC1155Received(
        address,
        address,
        uint256 id,
        uint256 value,
        bytes calldata
    ) external returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata
    ) external returns (bytes4) {
        require(
            _ids.length == 1,
            "Only allowed one asset batch transfer per transaction."
        );
        return
            bytes4(
                keccak256(
                    "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
                )
            );
    }
}