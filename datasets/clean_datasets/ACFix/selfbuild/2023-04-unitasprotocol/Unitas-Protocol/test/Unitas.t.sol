pragma solidity ^0.8.19;
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "forge-std/Test.sol";
import "../src/interfaces/ISwapFunctions.sol";
import "../src/interfaces/IERC20Token.sol";
import "../src/interfaces/IInsurancePool.sol";
import "../src/interfaces/IOracle.sol";
import "../src/interfaces/IUnitas.sol";
import "../src/utils/Errors.sol";
import "../src/utils/ScalingUtils.sol";
import "../src/ERC20Token.sol";
import "../src/InsurancePool.sol";
import "../src/TokenManager.sol";
import "../src/Unitas.sol";
import "../src/UnitasProxy.sol";
import "../src/UnitasProxyAdmin.sol";
import "../src/XOracle.sol";
import "./mocks/MockERC20Token.sol";
import "./utils/Functions.sol";
contract UnitasTest is Test {
    using MathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    struct SwapData {
        address account;
        address tokenIn;
        address tokenOut;
        ISwapFunctions.AmountType amountType;
        uint256 amountIn;
        uint256 amountOut;
        uint256 fee;
        uint24 feeNumerator;
        uint256 price;
        uint256 approxPrice;
    }
    IERC20Token internal _usd1;
    IERC20Token internal _usd91;
    IERC20Token internal _usd971;
    XOracle internal _oracle;
    MockERC20Token internal _usdt;
    InsurancePool internal _insurancePool;
    UnitasProxyAdmin internal _proxyAdmin;
    TokenManager internal _tokenManager;
    UnitasHarness internal _unitas;
    UnitasProxy internal _unitasProxy;
    UnitasHarness internal _unitasLogic;
    UnitasHarnessV2 internal _unitasLogicV2;
    address internal immutable _governor = vm.addr(0x1);
    address internal immutable _guardian = vm.addr(0x2);
    address internal immutable _timelock = vm.addr(0x3);
    address internal immutable _surplusPool = vm.addr(0x4);
    address internal immutable _proxyAdminOwner = vm.addr(0x5);
    event SetOracle(address indexed newOracle);
    event SetSurplusPool(address indexed newSurplusPool);
    event SetInsurancePool(address indexed newInsurancePool);
    event SetTokenManager(address indexed newTokenManager);
    event Swapped(
        address indexed tokenIn,
        address indexed tokenOut,
        address indexed sender,
        uint256 amountIn,
        uint256 amountOut,
        address feeToken,
        uint256 fee,
        uint24 feeNumerator,
        uint256 price
    );
    event SwapFeeSent(address indexed feeToken, address indexed receiver, uint256 fee);
    event BalanceUpdated(address indexed token, uint256 newBalance);
    function setUp() public virtual {
        _deployContracts();
        _initLabels();
        _updatePrice(address(_usdt), 1e18);
        _usdt.approve(address(_unitas), type(uint256).max);
        bytes32 minterRole = _usd1.MINTER_ROLE();
        vm.startPrank(_governor);
        _usd1.setMinter(address(_unitas), _governor);
        _usd91.setMinter(address(_unitas), _governor);
        _usd971.setMinter(address(_unitas), _governor);
        AccessControl(address(_usd1)).grantRole(minterRole, address(this));
        AccessControl(address(_usd91)).grantRole(minterRole, address(this));
        AccessControl(address(_usd971)).grantRole(minterRole, address(this));
        vm.stopPrank();
        bytes32 withdrawerRole = _insurancePool.WITHDRAWER_ROLE();
        vm.startPrank(_guardian);
        _insurancePool.grantRole(withdrawerRole, address(_unitas));
        vm.stopPrank();
    }
    function test_initialize_FailWhenDisabledInitializers() public {
        bytes memory message = bytes("Initializable: contract is already initialized");
        _unitasLogic = new UnitasHarness();
        vm.expectRevert(message);
        _unitasLogic.initialize(_getInitializeConfig());
    }
    function test_changeProxyAdmin_Changed() public {
        address newOwner = vm.addr(0x10001);
        UnitasProxyAdmin newProxyAdmin = new UnitasProxyAdmin(newOwner);
        vm.prank(_proxyAdminOwner);
        _proxyAdmin.changeProxyAdmin(_unitasProxy, address(newProxyAdmin));
        assertEq(newProxyAdmin.getProxyAdmin(_unitasProxy), address(newProxyAdmin), "new proxy admin");
    }
    function test_upgrade_FailWhenNotOwner() public {
        _unitasLogicV2 = new UnitasHarnessV2();
        vm.expectRevert("Ownable: caller is not the owner");
        _proxyAdmin.upgrade(_unitasProxy, address(_unitasLogicV2));
        vm.prank(_proxyAdminOwner);
        vm.expectRevert();
        _unitasProxy.upgradeTo(address(_unitasLogicV2));
    }
    function test_upgrade_UpgradedToV2() public {
        uint256 value = 100;
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountIn = 1e6;
        data.price = 1e18;
        _assertSwapWhenAssetTokenToUSD1WithAmountIn(data);
        uint256 reserve = _unitas.getReserve(address(_usdt));
        _assertUpgradedUnitasV2();
        vm.prank(_timelock);
        UnitasHarnessV2(address(_unitasProxy)).setTimelockValue(value);
        assertEq(UnitasHarnessV2(address(_unitasProxy)).timelockValue(), value, "timelock value");
        assertEq(_unitas.getReserve(address(_usdt)), reserve, "usdt reserve after upgrading");
        _assertSwapWhenAssetTokenToUSD1WithAmountIn(data);
        assertEq(_unitas.getReserve(address(_usdt)), reserve + data.amountIn, "usdt reserve after swapping again");
    }
    function test_upgradeAndCall_UpgradedToV2() public {
        uint256 value = 200;
        _unitasLogicV2 = new UnitasHarnessV2();
        vm.prank(_proxyAdminOwner);
        _proxyAdmin.upgradeAndCall(
            _unitasProxy, address(_unitasLogicV2), abi.encodeWithSignature("setValue(uint256)", value)
        );
        assertEq(UnitasHarnessV2(address(_unitasProxy)).value(), value, "value");
    }
    function test_upgradeAndCall_UpgradedToV2WithInitParentValue() public {
        uint256 value = 2000;
        _unitasLogicV2 = new UnitasHarnessV2();
        vm.prank(_proxyAdminOwner);
        _proxyAdmin.upgradeAndCall(
            _unitasProxy, address(_unitasLogicV2), abi.encodeWithSignature("setParentValue(uint256)", value)
        );
        assertEq(UnitasHarnessV2(address(_unitasProxy)).parentValue(), value, "parent value");
    }
    function test_setOracle_FailWhenNotTimelock() public {
        XOracle newOracle = new XOracle();
        vm.expectRevert(
            abi.encodeWithSignature("NotTimelock(address)", address(this))
        );
        _unitas.setOracle(address(newOracle));
    }
    function test_setOracle_FailWhenAddressZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_ZERO));
        vm.prank(_timelock);
        _unitas.setOracle(address(0));
    }
    function test_setOracle_FailWhenAddressCodeSizeZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_CODE_SIZE_ZERO));
        vm.prank(_timelock);
        _unitas.setOracle(vm.addr(0x10000));
    }
    function test_setOracle_Updated() public {
        XOracle newOracle = new XOracle();
        vm.expectEmit(true, true, true, true, address(_unitas));
        emit SetOracle(address(newOracle));
        vm.prank(_timelock);
        _unitas.setOracle(address(newOracle));
        assertEq(address(_unitas.oracle()), address(newOracle), "oracle");
    }
    function test_setSurplusPool_FailWhenNotTimelock() public {
        vm.expectRevert(
            abi.encodeWithSignature("NotTimelock(address)", address(this))
        );
        _unitas.setSurplusPool(vm.addr(0x10000));
    }
    function test_setSurplusPool_FailWhenAddressZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_ZERO));
        vm.prank(_timelock);
        _unitas.setSurplusPool(address(0));
    }
    function test_setSurplusPool_Updated() public {
        address newSurplusPool = vm.addr(0x10000);
        vm.expectEmit(true, true, true, true, address(_unitas));
        emit SetSurplusPool(address(newSurplusPool));
        vm.prank(_timelock);
        _unitas.setSurplusPool(address(newSurplusPool));
        assertEq(address(_unitas.surplusPool()), address(newSurplusPool), "surplus pool");
    }
    function test_setInsurancePool_FailWhenNotTimelock() public {
        vm.expectRevert(
            abi.encodeWithSignature("NotTimelock(address)", address(this))
        );
        _unitas.setInsurancePool(vm.addr(0x10000));
    }
    function test_setInsurancePool_FailWhenAddressZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_ZERO));
        vm.prank(_timelock);
        _unitas.setInsurancePool(address(0));
    }
    function test_setInsurancePool_FailWhenAddressCodeSizeZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_CODE_SIZE_ZERO));
        vm.prank(_timelock);
        _unitas.setInsurancePool(vm.addr(0x10000));
    }
    function test_setInsurancePool_Updated() public {
        InsurancePool newInsurancePool = new InsurancePool(_governor, _guardian, _timelock);
        vm.expectEmit(true, true, true, true, address(_unitas));
        emit SetInsurancePool(address(newInsurancePool));
        vm.prank(_timelock);
        _unitas.setInsurancePool(address(newInsurancePool));
        assertEq(address(_unitas.insurancePool()), address(newInsurancePool), "insurance pool");
    }
    function test_setTokenManager_FailWhenNotTimelock() public {
        XOracle newOracle = new XOracle();
        vm.expectRevert(
            abi.encodeWithSignature("NotTimelock(address)", address(this))
        );
        _unitas.setOracle(address(newOracle));
    }
    function test_setTokenManager_FailWhenAddressZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_ZERO));
        vm.prank(_timelock);
        _unitas.setTokenManager(ITokenManager(address(0)));
    }
    function test_setTokenManager_FailWhenAddressCodeSizeZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_CODE_SIZE_ZERO));
        vm.prank(_timelock);
        _unitas.setTokenManager(ITokenManager(vm.addr(0x10000)));
    }
    function test_setTokenManager_Updated() public {
        TokenManager newTokenManager = _deployTokenManager();
        vm.expectEmit(true, true, true, true, address(_unitas));
        emit SetTokenManager(address(newTokenManager));
        vm.prank(_timelock);
        _unitas.setTokenManager(newTokenManager);
        assertEq(address(_unitas.tokenManager()), address(newTokenManager), "token manager");
    }
    function test_pause_FailWhenNotGuardian() public {
        vm.expectRevert(
            abi.encodeWithSignature("NotGuardian(address)", address(this))
        );
        _unitas.pause();
    }
    function test_pause_PausedWhenGuardian() public {
        _assertGuardianPaused();
    }
    function test_unpause_FailWhenNotGuardian() public {
        vm.expectRevert(
            abi.encodeWithSignature("NotGuardian(address)", address(this))
        );
        _unitas.unpause();
    }
    function test_unpause_UnpausedWhenGuardian() public {
        _assertGuardianPaused();
        vm.prank(_guardian);
        _unitas.unpause();
        assertFalse(_paused(), "paused after unpause");
    }
    function test_swap_FailWhenPairInvalid() public {
        bytes memory message = _errorMessage(Errors.PAIR_INVALID);
        vm.mockCall(
            address(_tokenManager),
            abi.encodeWithSelector(TokenManager.getPair.selector, address(_usdt), address(_usd1)),
            abi.encode(address(0x0), address(0x0), 0, 0, 0, 0)
        );
        vm.expectRevert(message);
        _unitas.swap(address(_usdt), address(_usd1), ISwapFunctions.AmountType.In, 1);
        vm.mockCall(
            address(_tokenManager),
            abi.encodeWithSelector(TokenManager.getPair.selector, address(_usdt), address(_usd1)),
            abi.encode(address(_usdt), address(_usdt), 0, 0, 0, 0)
        );
        vm.expectRevert(message);
        _unitas.swap(address(_usdt), address(_usd1), ISwapFunctions.AmountType.In, 1);
        vm.mockCall(
            address(_tokenManager),
            abi.encodeWithSelector(TokenManager.getPair.selector, address(_usdt), address(_usd1)),
            abi.encode(address(_usd1), address(_usd1), 0, 0, 0, 0)
        );
        vm.expectRevert(message);
        _unitas.swap(address(_usdt), address(_usd1), ISwapFunctions.AmountType.In, 1);
        vm.mockCall(
            address(_tokenManager),
            abi.encodeWithSelector(TokenManager.getPair.selector, address(_usdt), address(_usd1)),
            abi.encode(address(_usd1), address(_usd91), 0, 0, 0, 0)
        );
        vm.expectRevert(message);
        _unitas.swap(address(_usdt), address(_usd1), ISwapFunctions.AmountType.In, 1);
        vm.mockCall(
            address(_tokenManager),
            abi.encodeWithSelector(TokenManager.getPair.selector, address(_usdt), address(_usd1)),
            abi.encode(address(_usd91), address(_usdt), 0, 0, 0, 0)
        );
        vm.expectRevert(message);
        _unitas.swap(address(_usdt), address(_usd1), ISwapFunctions.AmountType.In, 1);
    }
    function test_swap_FailWhenAmountOutZero() public {
        bytes memory message = _errorMessage(Errors.SWAP_RESULT_INVALID);
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountOut = 1;
        data.price = 1e18;
        _assertSwapWhenAssetTokenToUSD1WithAmountOut(data);
        _updatePrice(address(_usd91), 79.73e18);
        vm.expectRevert(message);
        _unitas.swap(address(_usd1), address(_usd91), ISwapFunctions.AmountType.In, data.amountOut);
    }
    function test_swap_FailWhenInsufficientBalance() public {
        bytes memory message = _errorMessage(Errors.BALANCE_INSUFFICIENT);
        uint256 amountIn = 1e6;
        _addCollateral(address(_usdt), amountIn);
        vm.expectRevert(message);
        _unitas.swap(address(_usdt), address(_usd1), ISwapFunctions.AmountType.In, amountIn);
    }
    function test_swap_FailWhenCollateralInsufficientToRedeemAssetTokenByReserveNotEnough() public {
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountIn = 100e6;
        data.price = 1e18;
        _assertSwapWhenAssetTokenToUSD1WithAmountIn(data);
        vm.prank(_timelock);
        _unitas.sendPortfolio(address(_usdt), _guardian, data.amountIn);
        uint256 usd1Amount = _usd1.balanceOf(data.account);
        vm.expectRevert(_errorMessage(Errors.POOL_BALANCE_INSUFFICIENT));
        _unitas.swap(
            address(_usd1),
            address(_usdt),
            ISwapFunctions.AmountType.In,
            usd1Amount
        );
    }
    function test_swap_FailWhenCollateralInsufficientToRedeemAssetTokenByStableTokenAppreciation() public {
        _addCollateral(address(_usdt), ScalingUtils.scaleByDecimals(31e18, 18, _usdt.decimals()));
        deal(address(_usdt), address(this), ScalingUtils.scaleByDecimals(100e18, 18, _usdt.decimals()));
        _unitas.swap(address(_usdt), address(_usd1), ISwapFunctions.AmountType.In, ScalingUtils.scaleByDecimals(100e18, 18, _usdt.decimals()));
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usd91);
        data.amountIn = 100e18;
        data.price = 100e18;
        _assertSwapWhenUSD1ToStableTokenWithAmountIn(data);
        uint256 usd91Amount = data.amountOut;
        data.tokenIn = address(_usd91);
        data.tokenOut = address(_usd1);
        data.amountIn = usd91Amount;
        data.price = 50e18;
        _assertSwapWhenStableTokenToUSD1WithAmountIn(data);
        uint256 usd1Amount = data.amountOut;
        vm.expectRevert(_errorMessage(Errors.POOL_BALANCE_INSUFFICIENT));
        _unitas.swap(
            address(_usd1),
            address(_usdt),
            ISwapFunctions.AmountType.In,
            usd1Amount
        );
    }
    function test_swap_WhenMintUSD1WithAmountIn() public {
        uint256 amountIn = 1e6;
        uint256 amountOut = 1e18;
        uint256 fee = 0;
        _addCollateral(address(_usdt), ScalingUtils.scaleByDecimals(1000e18, 18, _usdt.decimals()));
        deal(address(_usdt), address(this), amountIn);
        address user = address(this);
        address unitas = address(_unitas);
        uint256 userUSDT = _usdt.balanceOf(user);
        uint256 userUSD1 = _usd1.balanceOf(user);
        uint256 unitasUSDT = _usdt.balanceOf(unitas);
        uint256 surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        _unitas.swap(address(_usdt), address(_usd1), ISwapFunctions.AmountType.In, amountIn);
        assertEq(_usdt.balanceOf(user), userUSDT - amountIn, "user usdt balance after minted");
        assertEq(_usd1.balanceOf(user), userUSD1 + amountOut, "user usd1 balance after minted");
        assertEq(_usdt.balanceOf(unitas), unitasUSDT + amountIn, "unitas usdt balance after minted");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + fee, "surplus pool usd1 balance after minted");
        userUSDT = _usdt.balanceOf(user);
        userUSD1 = _usd1.balanceOf(user);
        unitasUSDT = _usdt.balanceOf(unitas);
        surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        amountIn = 1e18;
        amountOut = 1e6;
        fee = 0;
        _unitas.swap(address(_usd1), address(_usdt), ISwapFunctions.AmountType.In, amountIn);
        assertEq(_usdt.balanceOf(user), userUSDT + amountOut, "user usdt balance after redeemed");
        assertEq(_usd1.balanceOf(user), userUSD1 - amountIn, "user usd1 balance after redeemed");
        assertEq(_usdt.balanceOf(unitas), unitasUSDT - amountOut, "unitas usdt balance after redeemed");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + fee, "surplus pool usd1 balance after redeemed");
    }
    function test_swap_WhenMintUSD1WithAmountOut() public {
        uint256 amountIn = 1e6;
        uint256 amountOut = 1e18;
        uint256 fee = 0;
        _addCollateral(address(_usdt), ScalingUtils.scaleByDecimals(1000e18, 18, _usdt.decimals()));
        deal(address(_usdt), address(this), amountIn);
        address user = address(this);
        address unitas = address(_unitas);
        uint256 userUSDT = _usdt.balanceOf(user);
        uint256 userUSD1 = _usd1.balanceOf(user);
        uint256 unitasUSDT = _usdt.balanceOf(unitas);
        uint256 surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        _unitas.swap(address(_usdt), address(_usd1), ISwapFunctions.AmountType.Out, amountOut);
        assertEq(_usdt.balanceOf(user), userUSDT - amountIn, "user usdt balance after minted");
        assertEq(_usd1.balanceOf(user), userUSD1 + amountOut, "user usd1 balance after minted");
        assertEq(_usdt.balanceOf(unitas), unitasUSDT + amountIn, "unitas usdt balance after minted");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + fee, "surplus pool usd1 balance after minted");
        userUSDT = _usdt.balanceOf(user);
        userUSD1 = _usd1.balanceOf(user);
        unitasUSDT = _usdt.balanceOf(unitas);
        surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        amountIn = 1e18;
        amountOut = 1e6;
        fee = 0;
        _unitas.swap(address(_usd1), address(_usdt), ISwapFunctions.AmountType.Out, amountOut);
        assertEq(_usdt.balanceOf(user), userUSDT + amountOut, "user usdt balance after redeemed");
        assertEq(_usd1.balanceOf(user), userUSD1 - amountIn, "user usd1 balance after redeemed");
        assertEq(_usdt.balanceOf(unitas), unitasUSDT - amountOut, "unitas usdt balance after redeemed");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + fee, "surplus pool usd1 balance after redeemed");
    }
    function test_swap_WhenMintUSD91WithAmountIn() public {
        uint256 amountIn = 1.5e18;
        uint256 amountOut = 118.39905e18;
        uint256 fee = 0.015e18;
        _addCollateral(address(_usdt), ScalingUtils.scaleByDecimals(1000e18, 18, _usdt.decimals()));
        _usd1.mint(address(this), 2e18);
        _updatePrice(address(_usd91), 79730000000000000000, 1663559089);
        address user = address(this);
        uint256 userUSD1 = _usd1.balanceOf(user);
        uint256 userUSD91 = _usd91.balanceOf(user);
        uint256 surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        _unitas.swap(address(_usd1), address(_usd91), ISwapFunctions.AmountType.In, amountIn);
        assertEq(_usd1.balanceOf(user), userUSD1 - amountIn, "user usd1 after minted");
        assertEq(_usd91.balanceOf(user), userUSD91 + amountOut, "user usd91 balance after minted");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + fee, "surplus pool usd1 balance after minted");
        userUSD1 = _usd1.balanceOf(user);
        userUSD91 = _usd91.balanceOf(user);
        surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        amountIn = 118.39905e18;
        amountOut = 1.47015e18;
        fee = 0.01485e18;
        _unitas.swap(address(_usd91), address(_usd1), ISwapFunctions.AmountType.In, amountIn);
        assertEq(_usd1.balanceOf(user), userUSD1 + amountOut, "user usd1 balance after redeemed");
        assertEq(_usd91.balanceOf(user), userUSD91 - amountIn, "user usd91 balance after redeemed");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + fee, "surplus pool usd1 balance after redeemed");
    }
    function test_swap_WhenMintUSD91WithAmountOut() public {
        uint256 amountIn = 1.5e18;
        uint256 amountOut = 118.39905e18;
        uint256 fee = 0.015e18;
        _addCollateral(address(_usdt), ScalingUtils.scaleByDecimals(1000e18, 18, _usdt.decimals()));
        _usd1.mint(address(this), 2e18);
        _updatePrice(address(_usd91), 79730000000000000000, 1663559089);
        address user = address(this);
        uint256 userUSD1 = _usd1.balanceOf(user);
        uint256 userUSD91 = _usd91.balanceOf(user);
        uint256 surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        _unitas.swap(address(_usd1), address(_usd91), ISwapFunctions.AmountType.Out, amountOut);
        assertEq(_usd1.balanceOf(user), userUSD1 - amountIn, "user usd1 after minted");
        assertEq(_usd91.balanceOf(user), userUSD91 + amountOut, "user usd91 balance after minted");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + fee, "surplus pool usd1 balance after minted");
        userUSD1 = _usd1.balanceOf(user);
        userUSD91 = _usd91.balanceOf(user);
        surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        amountIn = 118.39905e18;
        amountOut = 1.47015e18;
        fee = 0.01485e18;
        _unitas.swap(address(_usd91), address(_usd1), ISwapFunctions.AmountType.Out, amountOut);
        assertEq(_usd1.balanceOf(user), userUSD1 + amountOut, "user usd1 balance after redeemed");
        assertEq(_usd91.balanceOf(user), userUSD91 - amountIn, "user usd91 balance after redeemed");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + fee, "surplus pool usd1 balance after redeemed");
    }
    function test_swap_WhenMintUSD971WithAmountIn() public {
        uint256 amountIn = 1.5e18;
        uint256 amountOut = 5.44995e18;
        uint256 fee = 0.015e18;
        _addCollateral(address(_usdt), ScalingUtils.scaleByDecimals(1000e18, 18, _usdt.decimals()));
        _usd1.mint(address(this), 2e18);
        _updatePrice(address(_usd971), 3670000000000000000, 1663559089); 
        address user = address(this);
        uint256 userUSD1 = _usd1.balanceOf(user);
        uint256 userUSD971 = _usd971.balanceOf(user);
        uint256 surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        _unitas.swap(address(_usd1), address(_usd971), ISwapFunctions.AmountType.In, amountIn);
        assertEq(_usd1.balanceOf(user), userUSD1 - amountIn, "user usd1 after minted");
        assertEq(_usd971.balanceOf(user), userUSD971 + amountOut, "user usd971 balance after minted");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + fee, "surplus pool usd1 balance after minted");
        userUSD1 = _usd1.balanceOf(user);
        userUSD971 = _usd971.balanceOf(user);
        surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        amountIn = 5.44995e18;
        amountOut = 1.47015e18;
        fee = 0.01485e18;
        _unitas.swap(address(_usd971), address(_usd1), ISwapFunctions.AmountType.In, amountIn);
        assertEq(_usd1.balanceOf(user), userUSD1 + amountOut, "user usd1 balance after redeemed");
        assertEq(_usd971.balanceOf(user), userUSD971 - amountIn, "user usd971 balance after redeemed");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + fee, "surplus pool usd1 balance after redeemed");
    }
    function test_swap_WhenMintUSD971WithAmountOut() public {
        uint256 amountIn = 1.5e18;
        uint256 amountOut = 5.44995e18;
        uint256 fee = 0.015e18;
        _addCollateral(address(_usdt), ScalingUtils.scaleByDecimals(1000e18, 18, _usdt.decimals()));
        _usd1.mint(address(this), 2e18);
        _updatePrice(address(_usd971), 3670000000000000000, 1663559089); 
        address user = address(this);
        uint256 userUSD1 = _usd1.balanceOf(user);
        uint256 userUSD971 = _usd971.balanceOf(user);
        uint256 surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        _unitas.swap(address(_usd1), address(_usd971), ISwapFunctions.AmountType.Out, amountOut);
        assertEq(_usd1.balanceOf(user), userUSD1 - amountIn, "user usd1 after minted");
        assertEq(_usd971.balanceOf(user), userUSD971 + amountOut, "user usd971 balance after minted");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + fee, "surplus pool usd1 balance after minted");
        userUSD1 = _usd1.balanceOf(user);
        userUSD971 = _usd971.balanceOf(user);
        surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        amountIn = 5.44995e18;
        amountOut = 1.47015e18;
        fee = 0.01485e18;
        _unitas.swap(address(_usd971), address(_usd1), ISwapFunctions.AmountType.Out, amountOut);
        assertEq(_usd1.balanceOf(user), userUSD1 + amountOut, "user usd1 balance after redeemed");
        assertEq(_usd971.balanceOf(user), userUSD971 - amountIn, "user usd971 balance after redeemed");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + fee, "surplus pool usd1 balance after redeemed");
    }
    function test_swap_RedeemedAssetTokenWithUsingCollaterals() public {
        _addCollateral(address(_usdt), ScalingUtils.scaleByDecimals(31e18, 18, _usdt.decimals()));
        deal(address(_usdt), address(this), ScalingUtils.scaleByDecimals(100e18, 18, _usdt.decimals()));
        _unitas.swap(address(_usdt), address(_usd1), ISwapFunctions.AmountType.In, ScalingUtils.scaleByDecimals(100e18, 18, _usdt.decimals()));
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usd91);
        data.amountIn = 100e18;
        data.price = 100e18;
        _assertSwapWhenUSD1ToStableTokenWithAmountIn(data);
        uint256 usd91Amount = data.amountOut;
        data.tokenIn = address(_usd91);
        data.tokenOut = address(_usd1);
        data.amountIn = usd91Amount;
        data.price = 50e18;
        _assertSwapWhenStableTokenToUSD1WithAmountIn(data);
        uint256 usd1Amount = data.amountOut;
        _addCollateral(address(_usdt), ScalingUtils.scaleByDecimals(65.02e18, 18, _usdt.decimals()));
        (, uint256 usdtAmount) = _unitas.swap(
            address(_usd1),
            address(_usdt),
            ISwapFunctions.AmountType.In,
            usd1Amount
        );
        assertEq(usdtAmount, ScalingUtils.scaleByDecimals(196.02e18, 18, _usdt.decimals()), "usdt amount out");
        assertEq(_unitas.getReserve(address(_usdt)), 0, "unitas reserve");
        assertEq(IInsurancePool(_insurancePool).getCollateral(address(_usdt)), 0, "insurance pool collateral");
        assertEq(_usdt.balanceOf(address(_insurancePool)), 0, "insurance pool balance");
        (IUnitas.ReserveStatus reserveStatus, uint256 reserves, uint256 collaterals, uint256 liabilities, uint256 reserveRatio) = _unitas.getReserveStatus();
        assertEq(uint8(reserveStatus), uint8(IUnitas.ReserveStatus.Finite), "reserve status");
        assertEq(reserves, 0, "reserves");
        assertEq(collaterals, 0, "collaterals");
        assertEq(liabilities, 2.98e18, "liabilities");
        assertEq(reserveRatio, 0, "reserve ratio");
    }
    function test_swap_WhenFeeZero() public {
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountType = ISwapFunctions.AmountType.In;
        data.amountIn = 100e6;
        data.amountOut = 100e18;
        data.price = 1e18;
        data.approxPrice = (10 ** _oracle.decimals()) ** 2 / data.price;
        data.fee = 0;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        _assertSwapFeeUpdated(data.tokenIn, data.tokenOut, 0);
        _assertReserveRatioThresholdUpdated(data.tokenIn, data.tokenOut, 1.3e18);
        _updatePrice(data.tokenIn, data.price);
        _addCollateral(address(_usdt), 31e6);
        deal(data.tokenIn, data.account, IERC20Metadata(data.tokenIn).balanceOf(data.account) + data.amountIn);
        _assertSwap(data);
    }
    function test_swap_WhenReserveRatioThresholdZero() public {
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountType = ISwapFunctions.AmountType.In;
        data.amountIn = 100e6;
        data.amountOut = 99e18;
        data.price = 1e18;
        data.approxPrice = (10 ** _oracle.decimals()) ** 2 / data.price;
        data.fee = 1e18;
        data.feeNumerator = 0.01e6;
        _assertSwapFeeUpdated(data.tokenIn, data.tokenOut, data.feeNumerator);
        _assertReserveRatioThresholdUpdated(data.tokenIn, data.tokenOut, 0);
        _updatePrice(data.tokenIn, data.price);
        deal(data.tokenIn, data.account, IERC20Metadata(data.tokenIn).balanceOf(data.account) + data.amountIn);
        _assertSwap(data);
    }
    function test_swapIn_FailWhenTokenTypeIsUndefined() public {
        MockERC20Token mockToken = new MockERC20Token("Mock Token", "MT", 18);
        address spender = vm.addr(1337);
        deal(address(mockToken), spender, 100e18);
        vm.expectRevert();
        _unitas.exposed_swapIn(address(mockToken), spender, 100e18);
    }
    function test_swapOut_FailWhenTokenTypeIsUndefined() public {
        MockERC20Token mockToken = new MockERC20Token("Mock Token", "MT", 18);
        address receiver = vm.addr(1337);
        deal(address(mockToken), address(_unitas), 100e18);
        vm.expectRevert();
        _unitas.exposed_swapOut(address(mockToken), receiver, 100e18);
    }
    function test_receivePortfolio_FailWhenNotPortfolio() public {
        vm.expectRevert(
            abi.encodeWithSignature("NotPortfolio(address)", address(this))
        );
        _unitas.receivePortfolio(address(_usdt), 100e6);
    }
    function test_receivePortfolio_Received() public {
        uint256 reserveAmount = 100e6;
        uint256 portfolioAmount = 50e6;
        uint256 receiveAmount = 40e6;
        address portfolioManager = _guardian;
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountIn = reserveAmount;
        data.price = 1e18;
        _assertSwapWhenAssetTokenToUSD1WithAmountIn(data);
        vm.prank(_timelock);
        _unitas.sendPortfolio(address(_usdt), portfolioManager, portfolioAmount);
        vm.startPrank(portfolioManager);
        IERC20(address(_usdt)).approve(address(_unitas), receiveAmount);
        _unitas.receivePortfolio(address(_usdt), receiveAmount);
        vm.stopPrank();
        assertEq(_usdt.balanceOf(address(_unitas)), reserveAmount - portfolioAmount + receiveAmount, "unitas balance");
        assertEq(_usdt.balanceOf(portfolioManager), portfolioAmount - receiveAmount, "portfolio balance");
    }
    function test_sendPortfolio_FailWhenNotTimelock() public {
        vm.expectRevert(
            abi.encodeWithSignature("NotTimelock(address)", address(this))
        );
        _unitas.sendPortfolio(address(_usdt), address(this), 100e6);
    }
    function test_sendPortfolio_FailWhenNotPortfolio() public {
        vm.expectRevert(
            abi.encodeWithSignature("NotPortfolio(address)", address(this))
        );
        vm.prank(_timelock);
        _unitas.sendPortfolio(address(_usdt), address(this), 100e6);
    }
    function test_sendPortfolio_Sent() public {
        uint256 reserveAmount = 100e6;
        uint256 portfolioAmount = 10e6;
        address portfolioManager = _guardian;
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountIn = reserveAmount;
        data.price = 1e18;
        _assertSwapWhenAssetTokenToUSD1WithAmountIn(data);
        vm.prank(_timelock);
        _unitas.sendPortfolio(address(_usdt), portfolioManager, portfolioAmount);
        assertEq(_usdt.balanceOf(address(_unitas)), reserveAmount - portfolioAmount, "unitas balance");
        assertEq(_usdt.balanceOf(portfolioManager), portfolioAmount, "portfolio balance");
    }
    function test_checkReserveRatio_FailWhenNotGreaterThanThreshold() public {
        address tokenIn = address(_usdt);
        address tokenOut = address(_usd1);
        uint256 amountIn = ScalingUtils.scaleByDecimals(100e18, 18, _usdt.decimals());
        _assertReserveRatioThresholdUpdated(tokenIn, tokenOut, 1.3e18);
        _assertReserveRatioThresholdUpdated(tokenIn, tokenOut, 1e18);
        deal(tokenIn, address(this), amountIn);
        _addCollateral(address(_usdt), ScalingUtils.scaleByDecimals(31e18, 18, _usdt.decimals()));
        _unitas.swap(tokenIn, tokenOut, ISwapFunctions.AmountType.In, amountIn);
        uint256 withdrawalCollateral = ScalingUtils.scaleByDecimals(1e18, 18, _usdt.decimals());
        vm.prank(_guardian);
        IInsurancePool(_insurancePool).withdrawCollateral(address(_usdt), withdrawalCollateral);
        bytes memory message = _errorMessage(Errors.RESERVE_RATIO_NOT_GREATER_THAN_THRESHOLD);
        vm.expectRevert(message);
        _unitas.exposed_checkReserveRatio(1.3e18);
        withdrawalCollateral = ScalingUtils.scaleByDecimals(30e18, 18, _usdt.decimals());
        vm.prank(_guardian);
        IInsurancePool(_insurancePool).withdrawCollateral(address(_usdt), withdrawalCollateral);
        vm.expectRevert(message);
        _unitas.exposed_checkReserveRatio(1e18);
    }
    function test_checkReserveRatio_ValidWhenEnough() public {
        uint232 reserveRatioThreshold = 1.3e18;
        address tokenIn = address(_usdt);
        address tokenOut = address(_usd1);
        uint256 amountIn = ScalingUtils.scaleByDecimals(100e18, 18, _usdt.decimals());
        deal(tokenIn, address(this), amountIn);
        _addCollateral(address(_usdt), ScalingUtils.scaleByDecimals(31e18, 18, _usdt.decimals()));
        _unitas.swap(tokenIn, tokenOut, ISwapFunctions.AmountType.In, amountIn);
        _unitas.exposed_checkReserveRatio(reserveRatioThreshold);
    }
    function test_checkReserveRatio_ValidWhenUnlimited() public view {
        _unitas.exposed_checkReserveRatio(0);
    }
    function test_getReserveStatus_Correct() public {
        uint256 reserves = ScalingUtils.scaleByDecimals(100e18, 18, _usd1.decimals());
        uint256 collaterals = ScalingUtils.scaleByDecimals(30e18, 18, _usd1.decimals());
        uint256 liabilities = ScalingUtils.scaleByDecimals(100e18, 18, _usd1.decimals());
        IUnitas.ReserveStatus reserveStatus;
        uint256 reserveRatio;
        (reserveStatus, reserveRatio) = _unitas.exposed_getReserveStatus(0, 0);
        assertEq(uint8(reserveStatus), uint8(IUnitas.ReserveStatus.Undefined), "reserve status when all zero");
        assertEq(reserveRatio, 0, "reserve ratio when all zero");
        (reserveStatus, reserveRatio) = _unitas.exposed_getReserveStatus(reserves + collaterals, 0);
        assertEq(uint8(reserveStatus), uint8(IUnitas.ReserveStatus.Infinite), "reserve status when liabilities zero");
        assertEq(reserveRatio, 0, "reserve ratio when liabilities zero");
        (reserveStatus, reserveRatio) = _unitas.exposed_getReserveStatus(collaterals, liabilities);
        assertEq(uint8(reserveStatus), uint8(IUnitas.ReserveStatus.Finite), "reserve status when reserves zero");
        assertEq(reserveRatio, 0.3e18, "reserve ratio when reserves zero");
        (reserveStatus, reserveRatio) = _unitas.exposed_getReserveStatus(reserves, liabilities);
        assertEq(uint8(reserveStatus), uint8(IUnitas.ReserveStatus.Finite), "reserve status when collaterals zero");
        assertEq(reserveRatio, 1e18, "reserve ratio when collaterals zero");
        (reserveStatus, reserveRatio) = _unitas.exposed_getReserveStatus(reserves + collaterals, liabilities);
        assertEq(uint8(reserveStatus), uint8(IUnitas.ReserveStatus.Finite), "reserve status when all non zero");
        assertEq(reserveRatio, 1.3e18, "reserve ratio when all non zero");
    }
    function test_getTotalReservesAndCollaterals_ReservesCorrect() public {
        MockERC20Token mockToken = new MockERC20Token("Mock Token", "MT", 18);
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](1);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(mockToken),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](1);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(mockToken),
            buyFee: 0,
            buyReserveRatioThreshold: 1.3e18,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        vm.prank(_timelock);
        _tokenManager.addTokensAndPairs(tokens, pairs);
        mockToken.approve(address(_unitas), type(uint256).max);
        _updatePriceTolerance(address(mockToken), 1, type(uint256).max);
        (uint256 reserves,) = _unitas.exposed_getTotalReservesAndCollaterals();
        assertEq(reserves, 0, "reserves before swapping");
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountIn = 100e6;
        data.price = 1e18;
        _assertSwapWhenAssetTokenToUSD1WithAmountIn(data);
        (reserves,) = _unitas.exposed_getTotalReservesAndCollaterals();
        assertEq(reserves, 100e18, "reserves after swapping usdt to usd1");
        data.tokenIn = address(mockToken);
        data.tokenOut = address(_usd1);
        data.amountIn = 100e18;
        data.price = 2e18;
        _assertSwapWhenAssetTokenToUSD1WithAmountIn(data);
        (reserves,) = _unitas.exposed_getTotalReservesAndCollaterals();
        assertEq(reserves, 150e18, "reserves after swapping mt to usd1");
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usdt);
        data.amountIn = 100e18;
        data.price = 1e18;
        _assertSwapWhenUSD1ToAssetTokenWithAmountIn(data);
        (reserves,) = _unitas.exposed_getTotalReservesAndCollaterals();
        assertEq(reserves, 50e18, "reserves after swapping usd1 to usdt");
        data.tokenIn = address(_usd1);
        data.tokenOut = address(mockToken);
        data.amountIn = 50e18;
        data.price = 2e18;
        _assertSwapWhenUSD1ToAssetTokenWithAmountIn(data);
        (reserves,) = _unitas.exposed_getTotalReservesAndCollaterals();
        assertEq(reserves, 0, "reserves after swapping usd1 to mt");
    }
    function test_getTotalReservesAndCollaterals_CollateralsCorrect() public {
        MockERC20Token mockToken = new MockERC20Token("Mock Token", "MT", 18);
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](1);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(mockToken),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](1);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(mockToken),
            buyFee: 0,
            buyReserveRatioThreshold: 1.3e18,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        vm.prank(_timelock);
        _tokenManager.addTokensAndPairs(tokens, pairs);
        (, uint256 collaterals) = _unitas.exposed_getTotalReservesAndCollaterals();
        assertEq(collaterals, 0, "collaterals before adding");
        _addCollateral(address(_usdt), 100e6);
        (, collaterals) = _unitas.exposed_getTotalReservesAndCollaterals();
        assertEq(collaterals, 100e18, "collaterals after adding usdt");
        _updatePrice(address(mockToken), 2e18);
        _addCollateral(address(mockToken), 100e18);
        (, collaterals) = _unitas.exposed_getTotalReservesAndCollaterals();
        assertEq(collaterals, 150e18, "collaterals after adding mt");
        vm.prank(_guardian);
        IInsurancePool(_insurancePool).withdrawCollateral(address(_usdt), 100e6);
        (, collaterals) = _unitas.exposed_getTotalReservesAndCollaterals();
        assertEq(collaterals, 50e18, "collaterals after withdrawing usdt");
        vm.prank(_guardian);
        IInsurancePool(_insurancePool).withdrawCollateral(address(mockToken), 100e18);
        (, collaterals) = _unitas.exposed_getTotalReservesAndCollaterals();
        assertEq(collaterals, 0, "collaterals after withdrawing mt");
    }
    function test_getTotalLiabilities_Correct() public {
        MockERC20Token mockToken = new MockERC20Token("Mock Token", "MT", 18);
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](1);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(mockToken),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](1);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(mockToken),
            buyFee: 0,
            buyReserveRatioThreshold: 1.3e18,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        vm.prank(_timelock);
        _tokenManager.addTokensAndPairs(tokens, pairs);
        mockToken.approve(address(_unitas), type(uint256).max);
        _updatePriceTolerance(address(mockToken), 1, type(uint256).max);
        assertEq(_unitas.exposed_getTotalLiabilities(), 0, "liabilities before swapping");
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountIn = 100e6;
        data.price = 1e18;
        _assertSwapWhenAssetTokenToUSD1WithAmountIn(data);
        assertEq(_unitas.exposed_getTotalLiabilities(), 100e18, "liabilities after swapping usdt to usd1");
        data.tokenIn = address(mockToken);
        data.tokenOut = address(_usd1);
        data.amountIn = 100e18;
        data.price = 2e18;
        _assertSwapWhenAssetTokenToUSD1WithAmountIn(data);
        assertEq(_unitas.exposed_getTotalLiabilities(), 150e18, "liabilities after swapping mt to usd1");
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usd91);
        data.amountIn = 100e18;
        data.price = 79.73e18;
        _assertSwapWhenUSD1ToStableTokenWithAmountIn(data);
        assertEq(_unitas.exposed_getTotalLiabilities(), 150e18, "liabilities after swapping usd1 to usd91");
        data.tokenIn = address(_usd91);
        data.tokenOut = address(_usd1);
        data.amountIn = 7893.27e18;
        data.price = 79.73e18;
        _assertSwapWhenStableTokenToUSD1WithAmountIn(data);
        assertEq(_unitas.exposed_getTotalLiabilities(), 150e18, "liabilities after swapping usd91 to usd1");
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usdt);
        data.amountIn = 98.01e18;
        data.price = 1e18;
        _assertSwapWhenUSD1ToAssetTokenWithAmountIn(data);
        assertEq(_unitas.exposed_getTotalLiabilities(), 51.99e18, "liabilities after swapping usd1 to usdt");
        data.tokenIn = address(_usd1);
        data.tokenOut = address(mockToken);
        data.amountIn = 50e18;
        data.price = 2e18;
        _assertSwapWhenUSD1ToAssetTokenWithAmountIn(data);
        assertEq(_unitas.exposed_getTotalLiabilities(), 1.99e18, "liabilities after swapping usd1 to mt");
    }
    function test_getPriceQuoteToken_FailWhenPairInvalid() public {
        bytes memory message = _errorMessage(Errors.PAIR_INVALID);
        vm.expectRevert(message);
        _unitas.exposed_getPriceQuoteToken(address(_usdt), address(_usdt));
        vm.expectRevert(message);
        _unitas.exposed_getPriceQuoteToken(address(_usd1), address(_usd1));
        vm.expectRevert(message);
        _unitas.exposed_getPriceQuoteToken(address(_usd91), address(_usd91));
        vm.expectRevert(message);
        _unitas.exposed_getPriceQuoteToken(address(_usdt), address(_usd91));
        vm.expectRevert(message);
        _unitas.exposed_getPriceQuoteToken(address(_usd91), address(_usdt));
    }
    function test_getPriceQuoteToken_FailWhenUSD1Zero() public {
        address oldToken = address(_usd1);
        _removeTokenAndPairs(oldToken);
        bytes memory message = _errorMessage(Errors.USD1_NOT_SET);
        vm.expectRevert(message);
        _unitas.exposed_getPriceQuoteToken(address(_usdt), oldToken);
        vm.expectRevert(message);
        _unitas.exposed_getPriceQuoteToken(oldToken, address(_usd91));
    }
    function test_getPriceQuoteToken_Correct() public {
        address quoteToken;
        quoteToken = _unitas.exposed_getPriceQuoteToken(address(_usdt), address(_usd1));
        assertEq(quoteToken, address(_usdt), "quote token when usdt and usd1");
        quoteToken = _unitas.exposed_getPriceQuoteToken(address(_usd1), address(_usdt));
        assertEq(quoteToken, address(_usdt), "quote token when usd1 and usdt");
        quoteToken = _unitas.exposed_getPriceQuoteToken(address(_usd1), address(_usd91));
        assertEq(quoteToken, address(_usd91), "quote token when usd1 and usd91");
        quoteToken = _unitas.exposed_getPriceQuoteToken(address(_usd91), address(_usd1));
        assertEq(quoteToken, address(_usd91), "quote token when usd91 and usd1");
    }
    function test_getReserve_Correct() public {
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountIn = 100e6;
        data.price = 1e18;
        _assertSwapWhenAssetTokenToUSD1WithAmountIn(data);
        assertEq(_unitas.getReserve(data.tokenIn), data.amountIn, "usdt reserve");
        assertEq(_unitas.getReserve(data.tokenOut), 0, "usd1 reserve");
    }
    function test_checkPrice_FailWhenInvalidTolerance() public {
        bytes memory message = _errorMessage(Errors.PRICE_TOLERANCE_INVALID);
        IERC20Token token = _deployUnitasERC20Token("Token", "TOKEN");
        vm.expectRevert(message);
        _unitas.exposed_checkPrice(address(token), 1e18);
    }
    function test_checkPrice_FailWhenNotInToleranceRange() public {
        bytes memory message = _errorMessage(Errors.PRICE_INVALID);
        address token = address(_usd91);
        uint256 minPrice = 100e18;
        uint256 maxPrice = 101e18;
        _updatePriceTolerance(token, minPrice, maxPrice);
        vm.expectRevert(message);
        _unitas.exposed_checkPrice(token, minPrice - 1);
        vm.expectRevert(message);
        _unitas.exposed_checkPrice(token, maxPrice + 1);
    }
    function test_checkPrice_Valid() public {
        address token = address(_usd91);
        uint256 minPrice = 100e18;
        uint256 maxPrice = 101e18;
        _updatePriceTolerance(token, minPrice, maxPrice);
        _unitas.exposed_checkPrice(token, minPrice);
        _unitas.exposed_checkPrice(token, (minPrice + maxPrice) / 2);
        _unitas.exposed_checkPrice(token, maxPrice);
    }
    function test_getSwapResult_FailWhenAmountZero() public {
        vm.expectRevert(_errorMessage(Errors.AMOUNT_INVALID));
        _unitas.swap(address(_usdt), address(_usd1), ISwapFunctions.AmountType.In, 0);
    }
    function test_getSwapResult_FailWhenInvalidPrice() public {
        bytes memory message = _errorMessage(Errors.PRICE_INVALID);
        uint256 minPrice = 1e18;
        uint256 maxPrice = 100e18;
        uint256 fromAmount = 0.1e18;
        address usd1Address = address(_usd1);
        address stableAddress = address(_usd91);
        ITokenManager.PairConfig memory pair = _tokenManager.getPair(usd1Address, stableAddress);
        _updatePriceTolerance(stableAddress, minPrice, maxPrice);
        _updatePrice(stableAddress, minPrice - 1);
        vm.expectRevert(message);
        _unitas.exposed_getSwapResult(pair, usd1Address, stableAddress, ISwapFunctions.AmountType.In, fromAmount);
        _updatePrice(stableAddress, maxPrice + 1);
        vm.expectRevert(message);
        _unitas.exposed_getSwapResult(pair, stableAddress, usd1Address, ISwapFunctions.AmountType.In, fromAmount);
    }
    function testFuzz_swap_RandomFeeAndReserveRatioThreshold(uint24 feeNumerator, uint64 reserveRatioThreshold, uint128 scaledAmountIn, uint112 price) public {
        feeNumerator = uint24(bound(feeNumerator, 0, 0.99e6));
        reserveRatioThreshold = uint64(bound(reserveRatioThreshold, 0, _tokenManager.RESERVE_RATIO_BASE() * 100));
        reserveRatioThreshold = reserveRatioThreshold < _tokenManager.RESERVE_RATIO_BASE() ? 0 : reserveRatioThreshold;
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        scaledAmountIn = uint128(bound(
            scaledAmountIn,
            MathUpgradeable.max((uint256(0.000001e18) * price).ceilDiv(1e18), 0.000001e18),
            type(uint128).max)
        );
        SwapData memory data;
        data.account = address(this);
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountIn = ScalingUtils.scaleByDecimals(scaledAmountIn, 18, _usdt.decimals());
        data.price = price;
        _assertSwapFeeUpdated(data.tokenIn, data.tokenOut, feeNumerator);
        _assertReserveRatioThresholdUpdated(data.tokenIn, data.tokenOut, reserveRatioThreshold);
        _assertSwapWhenAssetTokenToUSD1WithAmountIn(data);
    }
    function testFuzz_swap_WhenAssetTokenToUSD1WithAmountIn(uint128 scaledAmountIn, uint112 price, address account) public {
        _checkSkipAccount(account);
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        scaledAmountIn = uint128(bound(
            scaledAmountIn,
            MathUpgradeable.max((uint256(0.000001e18) * price).ceilDiv(1e18), 0.000001e18),
            type(uint128).max)
        );
        SwapData memory data;
        data.account = account;
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountIn = ScalingUtils.scaleByDecimals(scaledAmountIn, 18, _usdt.decimals());
        data.price = price;
        _assertSwapWhenAssetTokenToUSD1WithAmountIn(data);
    }
    function testFuzz_swap_WhenAssetTokenToUSD1WithAmountOut(uint128 amountOut, uint112 price, address account) public {
        _checkSkipAccount(account);
        amountOut = uint128(bound(amountOut, 1, type(uint128).max));
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        SwapData memory data;
        data.account = account;
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountOut = amountOut;
        data.price = price;
        _assertSwapWhenAssetTokenToUSD1WithAmountOut(data);
    }
    function testFuzz_swap_WhenUSD1ToAssetTokenWithAmountIn(uint128 amountIn, uint112 price, address account) public {
        _checkSkipAccount(account);
        uint256 feeNumerator = _getFee(address(_usd1), address(_usdt));
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        amountIn = uint128(bound(
            amountIn,
            (uint256(0.000001e18) * 1e18).ceilDiv(price) + _calculateFeeByAmountWithoutFee((uint256(0.000001e18) * 1e18).ceilDiv(price), feeNumerator, _tokenManager.SWAP_FEE_BASE()),
            type(uint128).max)
        );
        SwapData memory data;
        data.account = account;
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usdt);
        data.amountIn = amountIn;
        data.price = price;
        _assertSwapWhenUSD1ToAssetTokenWithAmountIn(data);
    }
    function testFuzz_swap_WhenUSD1ToAssetTokenWithAmountOut(uint128 amountOut, uint112 price, address account) public {
        _checkSkipAccount(account);
        amountOut = uint128(bound(amountOut, 0.000001e6, type(uint128).max));
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        SwapData memory data;
        data.account = account;
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usdt);
        data.amountOut = amountOut;
        data.price = price;
        _assertSwapWhenUSD1ToAssetTokenWithAmountOut(data);
    }
    function testFuzz_swap_WhenUSD1ToStableTokenWithAmountIn(uint128 amountIn, uint112 price, address account) public {
        _checkSkipAccount(account);
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        amountIn = uint128(bound(amountIn, uint256(1e18).ceilDiv(price) * 2, type(uint128).max));
        SwapData memory data;
        data.account = account;
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usd91);
        data.amountIn = amountIn;
        data.price = price;
        _assertSwapWhenUSD1ToStableTokenWithAmountIn(data);
    }
    function testFuzz_swap_WhenUSD1ToStableTokenWithAmountOut(uint128 amountOut, uint112 price, address account) public {
        _checkSkipAccount(account);
        amountOut = uint128(bound(amountOut, 1, type(uint128).max));
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        SwapData memory data;
        data.account = account;
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usd91);
        data.amountOut = amountOut;
        data.price = price;
        _assertSwapWhenUSD1ToStableTokenWithAmountOut(data);
    }
    function testFuzz_swap_WhenStableTokenToUSD1WithAmountIn(uint128 amountIn, uint112 price, address account) public {
        _checkSkipAccount(account);
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        amountIn = uint128(bound(amountIn, uint256(price).ceilDiv(1e18) * 2, type(uint128).max));
        SwapData memory data;
        data.account = account;
        data.tokenIn = address(_usd91);
        data.tokenOut = address(_usd1);
        data.amountIn = amountIn;
        data.price = price;
        _assertSwapWhenStableTokenToUSD1WithAmountIn(data);
    }
    function testFuzz_swap_WhenStableTokenToUSD1WithAmountOut(uint128 amountOut, uint112 price, address account) public {
        _checkSkipAccount(account);
        amountOut = uint128(bound(amountOut, 1, type(uint128).max));
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        SwapData memory data;
        data.account = account;
        data.tokenIn = address(_usd91);
        data.tokenOut = address(_usd1);
        data.amountOut = amountOut;
        data.price = price;
        _assertSwapWhenStableTokenToUSD1WithAmountOut(data);
    }
    function testFuzz_swap_WhenOneUserMultipleTimes(
        uint8 times,
        uint8[10] calldata actions,
        uint80[10] calldata amounts,
        int64[10] calldata priceDiff
    ) public {
        times = uint8(bound(times, 5, 10));
        SwapData memory data;
        data.account = address(this);
        _addCollateral(
            address(_usdt),
            ScalingUtils.scaleByDecimals(uint256(times) * 2 * type(uint80).max, 18, _usdt.decimals())
        );
        for (uint256 i = 0; i < times; i++) {
            uint8 action = actions[i];
            uint256 amount = bound(amounts[i], 100e18, 10000000e18);
            if (action % 2 == 0) {
                data.tokenIn = address(_usdt);
                data.tokenOut = address(_usd1);
                data.amountOut = ScalingUtils.scaleByDecimals(amount, 18, _usdt.decimals());
                data.price = 1e18;
                _assertSwapWhenAssetTokenToUSD1WithAmountOut(data);
            }
            if (action % 3 == 0) {
                data.tokenIn = address(_usd1);
                data.tokenOut = address(_usdt);
                data.amountType = ISwapFunctions.AmountType.Out;
                data.amountIn = amount;
                data.price = 1e18;
                _assertSwapWhenUSD1ToAssetTokenWithAmountIn(data);
            }
            if (action % 4 == 0) {
                data.tokenIn = address(_usd1);
                data.tokenOut = address(_usd91);
                data.amountIn = amount;
                data.price = uint256(int256(79.73e18) + priceDiff[i]);
                _assertSwapWhenUSD1ToStableTokenWithAmountIn(data);
            }
            if (action % 5 == 0) {
                data.tokenIn = address(_usd91);
                data.tokenOut = address(_usd1);
                data.amountIn = amount;
                data.price = uint256(int256(79.73e18) + priceDiff[i]);
                _assertSwapWhenStableTokenToUSD1WithAmountIn(data);
            }
        }
    }
    function testFuzz_swap_WhenMultipleUsers(
        address[10] calldata accounts,
        uint8[10] calldata actions,
        uint80[10] calldata amounts,
        int64[10] calldata priceDiff
    ) public {
        SwapData memory data;
        data.account = address(this);
        _addCollateral(
            address(_usdt),
            ScalingUtils.scaleByDecimals(uint256(accounts.length) * 2 * type(uint80).max, 18, _usdt.decimals())
        );
        for (uint256 i = 0; i < accounts.length; i++) {
            if (_isAccountExcluded(accounts[i])) {
                continue;
            }
            data.account = accounts[i];
            uint8 action = actions[i];
            uint256 amount = bound(amounts[i], 100e18, 10000000e18);
            if (action % 2 == 0) {
                data.tokenIn = address(_usdt);
                data.tokenOut = address(_usd1);
                data.amountOut = ScalingUtils.scaleByDecimals(amount, 18, _usdt.decimals());
                data.price = 1e18;
                _assertSwapWhenAssetTokenToUSD1WithAmountOut(data);
            }
            if (action % 3 == 0) {
                data.tokenIn = address(_usd1);
                data.tokenOut = address(_usdt);
                data.amountType = ISwapFunctions.AmountType.Out;
                data.amountIn = amount;
                data.price = 1e18;
                _assertSwapWhenUSD1ToAssetTokenWithAmountIn(data);
            }
            if (action % 4 == 0) {
                data.tokenIn = address(_usd1);
                data.tokenOut = address(_usd91);
                data.amountIn = amount;
                data.price = uint256(int256(79.73e18) + priceDiff[i]);
                _assertSwapWhenUSD1ToStableTokenWithAmountIn(data);
            }
            if (action % 5 == 0) {
                data.tokenIn = address(_usd91);
                data.tokenOut = address(_usd1);
                data.amountIn = amount;
                data.price = uint256(int256(79.73e18) + priceDiff[i]);
                _assertSwapWhenStableTokenToUSD1WithAmountIn(data);
            }
        }
    }
    function testFuzz_estimateSwapResult_WhenAssetTokenToUSD1WithAmountIn(uint128 scaledAmountIn, uint112 price) public {
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        scaledAmountIn = uint128(bound(
            scaledAmountIn,
            MathUpgradeable.max((uint256(0.000001e18) * price).ceilDiv(1e18), 0.000001e18),
            type(uint128).max)
        );
        SwapData memory data;
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountType = ISwapFunctions.AmountType.In;
        data.amountIn = ScalingUtils.scaleByDecimals(scaledAmountIn, 18, _usdt.decimals());
        data.price = price;
        data.approxPrice = (10 ** _oracle.decimals()) ** 2 / price;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        _updatePrice(data.tokenIn, price);
        (data.amountOut, data.fee) = _calculateResultWhenAssetTokenToUSD1WithAmountIn(data);
        _assertEstimateSwapResultCorrect(data);
    }
    function testFuzz_estimateSwapResult_WhenAssetTokenToUSD1WithAmountOut(uint128 amountOut, uint112 price) public {
        amountOut = uint128(bound(amountOut, 1, type(uint128).max));
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        SwapData memory data;
        data.tokenIn = address(_usdt);
        data.tokenOut = address(_usd1);
        data.amountType = ISwapFunctions.AmountType.Out;
        data.amountOut = amountOut;
        data.price = price;
        data.approxPrice = (10 ** _oracle.decimals()) ** 2 / price;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        _updatePrice(data.tokenIn, price);
        (data.amountIn, data.fee) = _calculateResultWhenAssetTokenToUSD1WithAmountOut(data);
        _assertEstimateSwapResultCorrect(data);
    }
    function testFuzz_estimateSwapResult_WhenUSD1ToAssetTokenWithAmountIn(uint128 amountIn, uint112 price) public {
        uint256 feeNumerator = _getFee(address(_usd1), address(_usdt));
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        amountIn = uint128(bound(
            amountIn,
            (uint256(0.000001e18) * 1e18).ceilDiv(price) + _calculateFeeByAmountWithoutFee((uint256(0.000001e18) * 1e18).ceilDiv(price), feeNumerator, _tokenManager.SWAP_FEE_BASE()),
            type(uint128).max)
        );
        SwapData memory data;
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usdt);
        data.amountType = ISwapFunctions.AmountType.In;
        data.amountIn = amountIn;
        data.price = price;
        data.approxPrice = price;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        _updatePrice(data.tokenOut, price);
        (data.amountOut, data.fee) = _calculateResultWhenUSD1ToAssetTokenWithAmountIn(data);
        _assertEstimateSwapResultCorrect(data);
    }
    function testFuzz_estimateSwapResult_WhenUSD1ToAssetTokenWithAmountOut(uint128 amountOut, uint112 price) public {
        amountOut = uint128(bound(amountOut, 0.000001e6, type(uint128).max));
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        SwapData memory data;
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usdt);
        data.amountType = ISwapFunctions.AmountType.Out;
        data.amountOut = amountOut;
        data.price = price;
        data.approxPrice = price;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        _updatePrice(data.tokenOut, price);
        (data.amountIn, data.fee) = _calculateResultWhenUSD1ToAssetTokenWithAmountOut(data);
        _assertEstimateSwapResultCorrect(data);
    }
    function testFuzz_estimateSwapResult_WhenUSD1ToStableTokenWithAmountIn(uint128 amountIn, uint112 price) public {
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        amountIn = uint128(bound(amountIn, uint256(1e18).ceilDiv(price) * 2, type(uint128).max));
        SwapData memory data;
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usd91);
        data.amountType = ISwapFunctions.AmountType.In;
        data.amountIn = amountIn;
        data.price = price;
        data.approxPrice = price;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        _updatePrice(data.tokenOut, price);
        (data.amountOut, data.fee) = _calculateResultWhenUSD1ToStableTokenWithAmountIn(data);
        _assertEstimateSwapResultCorrect(data);
    }
    function testFuzz_estimateSwapResult_WhenUSD1ToStableTokenWithAmountOut(uint128 amountOut, uint112 price) public {
        amountOut = uint128(bound(amountOut, 1, type(uint128).max));
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        SwapData memory data;
        data.tokenIn = address(_usd1);
        data.tokenOut = address(_usd91);
        data.amountType = ISwapFunctions.AmountType.Out;
        data.amountOut = amountOut;
        data.price = price;
        data.approxPrice = price;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        _updatePrice(data.tokenOut, price);
        (data.amountIn, data.fee) = _calculateResultWhenUSD1ToStableTokenWithAmountOut(data);
        _assertEstimateSwapResultCorrect(data);
    }
    function testFuzz_estimateSwapResult_WhenStableTokenToUSD1WithAmountIn(uint128 amountIn, uint112 price) public {
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        amountIn = uint128(bound(amountIn, uint256(price).ceilDiv(1e18) * 2, type(uint128).max));
        SwapData memory data;
        data.tokenIn = address(_usd91);
        data.tokenOut = address(_usd1);
        data.amountType = ISwapFunctions.AmountType.In;
        data.amountIn = amountIn;
        data.price = price;
        data.approxPrice = (10 ** _oracle.decimals()) ** 2 / price;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        _updatePrice(data.tokenIn, price);
        (data.amountOut, data.fee) = _calculateResultWhenStableTokenToUSD1WithAmountIn(data);
        _assertEstimateSwapResultCorrect(data);
    }
    function testFuzz_estimateSwapResult_WhenStableTokenToUSD1WithAmountOut(uint128 amountOut, uint112 price) public {
        amountOut = uint128(bound(amountOut, 1, type(uint128).max));
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        SwapData memory data;
        data.tokenIn = address(_usd91);
        data.tokenOut = address(_usd1);
        data.amountType = ISwapFunctions.AmountType.Out;
        data.amountOut = amountOut;
        data.price = price;
        data.approxPrice = (10 ** _oracle.decimals()) ** 2 / price;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        _updatePrice(data.tokenIn, price);
        (data.amountIn, data.fee) = _calculateResultWhenStableTokenToUSD1WithAmountOut(data);
        _assertEstimateSwapResultCorrect(data);
    }
    function testFuzz_estimateSwapResult_AmountTypeReverseWhenAssetTokenToUSD1WithAmountInFirst(uint128 scaledAmountIn, uint112 price) public {
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        scaledAmountIn = uint128(bound(
            scaledAmountIn,
            MathUpgradeable.max((uint256(0.000001e18) * price).ceilDiv(1e18), 0.000001e18),
            type(uint128).max)
        );
        address tokenIn = address(_usdt);
        address tokenOut = address(_usd1);
        _updatePrice(tokenIn, price);
        (uint256 amountIn, uint256 amountOut,, uint256 fee,,) = _unitas.estimateSwapResult(
            tokenIn,
            tokenOut,
            ISwapFunctions.AmountType.In,
            ScalingUtils.scaleByDecimals(scaledAmountIn, 18, IERC20Metadata(tokenIn).decimals())
        );
        (uint256 amountIn2, uint256 amountOut2,, uint256 fee2,,) = _unitas.estimateSwapResult(
            tokenIn,
            tokenOut,
            ISwapFunctions.AmountType.Out,
            amountOut
        );
        uint256 amountTolerance = amountIn == amountIn2 ?
            0 :
            uint256(price).mulDiv(2, 10 ** (18 - IERC20Metadata(tokenIn).decimals()) * 1e18, MathUpgradeable.Rounding.Up);
        uint256 amountInDiff = amountIn >= amountIn2 ? amountIn - amountIn2 : amountIn2 - amountIn;
        uint256 feeTolerance = 10 ** (18 - IERC20Metadata(tokenOut).decimals());
        uint256 feeDiff = fee >= fee2 ? fee - fee2 : fee2 - fee;
        assertLeDecimal(amountInDiff, amountTolerance, IERC20Metadata(tokenIn).decimals(), "amount in diff <= tolerance");
        assertEq(amountOut, amountOut2, "amount out");
        assertLeDecimal(feeDiff, feeTolerance, IERC20Metadata(tokenOut).decimals(), "fee diff <= tolerance");
    }
    function testFuzz_estimateSwapResult_AmountTypeReverseWhenAssetTokenToUSD1WithAmountOutFirst(uint128 scaledAmountOut, uint112 price) public {
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        scaledAmountOut = uint128(bound(scaledAmountOut, 0.000001e18, type(uint128).max));
        address tokenIn = address(_usdt);
        address tokenOut = address(_usd1);
        _updatePrice(tokenIn, price);
        (uint256 amountIn, uint256 amountOut,, uint256 fee,,) = _unitas.estimateSwapResult(
            tokenIn,
            tokenOut,
            ISwapFunctions.AmountType.Out,
            ScalingUtils.scaleByDecimals(scaledAmountOut, 18, IERC20Metadata(tokenOut).decimals())
        );
        (uint256 amountIn2, uint256 amountOut2,, uint256 fee2,,) = _unitas.estimateSwapResult(
            tokenIn,
            tokenOut,
            ISwapFunctions.AmountType.In,
            amountIn
        );
        uint256 amountTolerance = amountOut == amountOut2 ?
            0 :
            (10 ** (18 - IERC20Metadata(tokenIn).decimals()) * 1e18).ceilDiv(price);
        uint256 amountOutDiff = amountOut >= amountOut2 ? amountOut - amountOut2 : amountOut2 - amountOut;
        uint256 feeNumerator = _getFee(tokenIn, tokenOut);
        uint256 feeTolerance = 10 ** (18 - IERC20Metadata(tokenOut).decimals());
        feeTolerance += amountOut == amountOut2 ?
            0 :
            _calculateFeeByAmountWithoutFee(amountOutDiff, feeNumerator, _tokenManager.SWAP_FEE_BASE());
        uint256 feeDiff = fee >= fee2 ? fee - fee2 : fee2 - fee;
        assertEq(amountIn, amountIn2, "amount in");
        assertLeDecimal(amountOutDiff, amountTolerance, IERC20Metadata(tokenOut).decimals(), "amount out diff <= tolerance");
        assertLeDecimal(feeDiff, feeTolerance, IERC20Metadata(tokenOut).decimals(), "fee diff <= tolerance");
    }
    function testFuzz_estimateSwapResult_AmountTypeReverseWhenUSD1ToAssetTokenWithAmountInFirst(uint128 scaledAmountIn, uint112 price) public {
        address tokenIn = address(_usd1);
        address tokenOut = address(_usdt);
        uint256 feeNumerator = _getFee(tokenIn, tokenOut);
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        scaledAmountIn = uint128(bound(
            scaledAmountIn,
            (uint256(0.000001e18) * 1e18).ceilDiv(price) + _calculateFeeByAmountWithoutFee((uint256(0.000001e18) * 1e18).ceilDiv(price), feeNumerator, _tokenManager.SWAP_FEE_BASE()),
            type(uint128).max)
        );
        _updatePrice(tokenOut, price);
        (uint256 amountIn, uint256 amountOut,, uint256 fee,,) = _unitas.estimateSwapResult(
            tokenIn,
            tokenOut,
            ISwapFunctions.AmountType.In,
            ScalingUtils.scaleByDecimals(scaledAmountIn, 18, IERC20Metadata(tokenIn).decimals())
        );
        (uint256 amountIn2, uint256 amountOut2,, uint256 fee2,,) = _unitas.estimateSwapResult(
            tokenIn,
            tokenOut,
            ISwapFunctions.AmountType.Out,
            amountOut
        );
        uint256 tolerance = amountIn == amountIn2 ?
            0 :
            (10 ** (18 - IERC20Metadata(tokenOut).decimals()) * 1e18).ceilDiv(price);
        uint256 amountTolerance = tolerance + _calculateFeeByAmountWithoutFee(tolerance, feeNumerator, _tokenManager.SWAP_FEE_BASE());
        uint256 amountInDiff = amountIn >= amountIn2 ? amountIn - amountIn2 : amountIn2 - amountIn;
        uint256 feeTolerance = amountIn == amountIn2 ?
            0 :
            _calculateFee(amountInDiff, feeNumerator, _tokenManager.SWAP_FEE_BASE());
        uint256 feeDiff = fee >= fee2 ? fee - fee2 : fee2 - fee;
        assertLeDecimal(amountInDiff, amountTolerance, 18, "amount in diff <= tolerance");
        assertEq(amountOut, amountOut2, "amount out");
        assertLeDecimal(feeDiff, feeTolerance, 18, "fee diff <= tolerance");
    }
    function testFuzz_estimateSwapResult_AmountTypeReverseWhenUSD1ToAssetTokenWithAmountOutFirst(uint128 scaledAmountOut, uint112 price) public {
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        scaledAmountOut = uint128(bound(scaledAmountOut, 0.000001e18, type(uint128).max));
        address tokenIn = address(_usd1);
        address tokenOut = address(_usdt);
        _updatePrice(tokenIn, price);
        (uint256 amountIn, uint256 amountOut,, uint256 fee,,) = _unitas.estimateSwapResult(
            tokenIn,
            tokenOut,
            ISwapFunctions.AmountType.Out,
            ScalingUtils.scaleByDecimals(scaledAmountOut, 18, IERC20Metadata(tokenOut).decimals())
        );
        (uint256 amountIn2, uint256 amountOut2,, uint256 fee2,,) = _unitas.estimateSwapResult(
            tokenIn,
            tokenOut,
            ISwapFunctions.AmountType.In,
            amountIn
        );
        assertEq(amountIn, amountIn2, "amount in");
        assertEq(amountOut, amountOut2, "amount out");
        assertEq(fee, fee2, "fee");
    }
    function _deployContracts() internal {
        _proxyAdmin = new UnitasProxyAdmin(_proxyAdminOwner);
        _usd1 = _deployUnitasERC20Token("Unitas 1", "USD1");
        _usd91 = _deployUnitasERC20Token("Unitas 91", "USD91");
        _usd971 = _deployUnitasERC20Token("Unitas 971", "USD971");
        _usdt = new MockERC20Token("Tether USD", "USDT", 6);
        _oracle = new XOracle();
        _insurancePool = new InsurancePool(_governor, _guardian, _timelock);
        _tokenManager = _deployTokenManager();
        IUnitas.InitializeConfig memory config = _getInitializeConfig();
        _unitasLogic = new UnitasHarness();
        _unitasProxy = new UnitasProxy(address(_unitasLogic), address(_proxyAdmin), config);
        _unitas = UnitasHarness(address(_unitasProxy));
    }
    function _deployUnitasERC20Token(string memory name, string memory symbol) internal returns (IERC20Token) {
        ERC20Token token = new ERC20Token(name, symbol, _governor, _guardian, _governor);
        return IERC20Token(address(token));
    }
    function _deployTokenManager() internal returns (TokenManager) {
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](3);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(_usdt),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[1] = ITokenManager.TokenConfig({
            token: address(_usd91),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[2] = ITokenManager.TokenConfig({
            token: address(_usd971),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](3);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 0,
            buyReserveRatioThreshold: 1.3e18,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        pairs[1] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usd91),
            buyFee: 0.01e6,
            buyReserveRatioThreshold: 0,
            sellFee: 0.01e6,
            sellReserveRatioThreshold: 1e18
        });
        pairs[2] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usd971),
            buyFee: 0.01e6,
            buyReserveRatioThreshold: 0,
            sellFee: 0.01e6,
            sellReserveRatioThreshold: 1e18
        });
        return new TokenManager(_governor, _timelock, address(_usd1), tokens, pairs);
    }
    function _initLabels() internal {
        vm.label(address(_usd1), "USD1");
        vm.label(address(_usd91), "USD91");
        vm.label(address(_usd971), "USD971");
        vm.label(address(_usdt), "USDT");
        vm.label(address(_governor), "Governor");
        vm.label(address(_guardian), "Guardian");
        vm.label(address(_timelock), "Timelock");
        vm.label(address(_surplusPool), "SurplusPool");
    }
    function _updatePrice(address token, uint256 price) internal {
        (uint64 current_timestamp, , , ) = _oracle.getPrice(token);
        _updatePrice(token, price, current_timestamp+1);
    }
    function _updatePrice(address token, uint256 price, uint64 timestamp) internal {
        IOracle.NewPrice[] memory prices = new IOracle.NewPrice[](1);
        prices[0] = IOracle.NewPrice(token, timestamp, price);
        _oracle.updatePrices(prices);
    }
    function _updatePriceTolerance(address token, uint256 minPrice, uint256 maxPrice) internal {
        vm.prank(_timelock);
        _tokenManager.setMinMaxPriceTolerance(token, minPrice, maxPrice);
    }
    function _addCollateral(address token, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        deal(token, _guardian, amount);
        vm.startPrank(_guardian);
        IERC20(token).approve(address(_insurancePool), amount);
        _insurancePool.depositCollateral(token, amount);
        vm.stopPrank();
    }
    function _assertUpgradedUnitasV2() internal {
        _unitasLogicV2 = new UnitasHarnessV2();
        vm.prank(_proxyAdminOwner);
        _proxyAdmin.upgrade(_unitasProxy, address(_unitasLogicV2));
        assertEq(UnitasHarnessV2(address(_unitasProxy)).version(), 2, "version");
    }
    function _assertGuardianPaused() internal {
        vm.prank(_guardian);
        _unitas.pause();
        assertTrue(_paused(), "paused after pause");
    }
    function _assertSwapFeeUpdated(address tokenIn, address tokenOut, uint24 fee) public {
        ITokenManager.PairConfig memory pair = _tokenManager.getPair(tokenIn, tokenOut);
        if (tokenOut == pair.baseToken) {
            pair.buyFee = fee;
        } else {
            pair.sellFee = fee;
        }
        _assertPairUpdated(pair);
    }
    function _assertReserveRatioThresholdUpdated(address tokenIn, address tokenOut, uint232 threshold) public {
        ITokenManager.PairConfig memory pair = _tokenManager.getPair(tokenIn, tokenOut);
        if (tokenOut == pair.baseToken) {
            pair.buyReserveRatioThreshold = threshold;
        } else {
            pair.sellReserveRatioThreshold = threshold;
        }
        _assertPairUpdated(pair);
    }
    function _assertPairUpdated(ITokenManager.PairConfig memory pair) internal {
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](1);
        pairs[0] = pair;
        vm.startPrank(_timelock);
        _tokenManager.updatePairs(pairs);
        vm.stopPrank();
    }
    function _assertSwap(SwapData memory data) internal {
        uint256 balanceIn = IERC20(data.tokenIn).balanceOf(data.account);
        uint256 balanceOut = IERC20(data.tokenOut).balanceOf(data.account);
        uint256 surplusPoolUSD1 = _usd1.balanceOf(_surplusPool);
        uint256 tokenInSupply = IERC20(data.tokenIn).totalSupply();
        uint256 tokenOutSupply = IERC20(data.tokenOut).totalSupply();
        if (_tokenManager.getTokenType(data.tokenIn) == ITokenManager.TokenType.Asset) {
            if (IERC20(data.tokenIn).allowance(data.account, address(_unitas)) < data.amountIn) {
                vm.startPrank(data.account);
                IERC20(data.tokenIn).approve(address(_unitas), data.amountIn);
                vm.stopPrank();
            }
            vm.expectEmit(true, true, true, true, address(_unitas));
            emit BalanceUpdated(data.tokenIn, _unitas.getReserve(data.tokenIn) + data.amountIn);
        } else if (_tokenManager.getTokenType(data.tokenOut) == ITokenManager.TokenType.Asset) {
            uint256 reserveSubtracted = data.amountOut.min(_unitas.getReserve(data.tokenOut) - _unitas.getPortfolio(data.tokenOut));
            vm.expectEmit(true, true, true, true, address(_unitas));
            emit BalanceUpdated(data.tokenOut, _unitas.getReserve(data.tokenOut) - reserveSubtracted);
        }
        if (data.fee > 0) {
            vm.expectEmit(true, true, true, true, address(_unitas));
            emit SwapFeeSent(address(_usd1), _surplusPool, data.fee);
        }
        vm.expectEmit(true, true, true, true, address(_unitas));
        emit Swapped(
            data.tokenIn,
            data.tokenOut,
            data.account,
            data.amountIn,
            data.amountOut,
            address(_usd1),
            data.fee,
            data.feeNumerator,
            data.approxPrice
        );
        vm.startPrank(data.account);
        (uint256 amountIn, uint256 amountOut) = _unitas.swap(
            data.tokenIn,
            data.tokenOut,
            data.amountType,
            data.amountType == ISwapFunctions.AmountType.In ? data.amountIn : data.amountOut
        );
        vm.stopPrank();
        assertEq(amountIn, data.amountIn, "amount in");
        assertEq(amountOut, data.amountOut, "amount out");
        assertEq(IERC20(data.tokenIn).balanceOf(data.account), balanceIn - amountIn, "user balance in");
        assertEq(IERC20(data.tokenOut).balanceOf(data.account), balanceOut + amountOut, "user balance out");
        assertEq(_usd1.balanceOf(_surplusPool), surplusPoolUSD1 + data.fee, "unitas pending swap fee");
        if (_tokenManager.getTokenType(data.tokenIn) == ITokenManager.TokenType.Stable) {
            assertEq(
                IERC20(data.tokenIn).totalSupply(),
                tokenInSupply - amountIn + (data.tokenIn == address(_usd1) ? data.fee : 0),
                "token in liability"
            );
        }
        if (_tokenManager.getTokenType(data.tokenOut) == ITokenManager.TokenType.Stable) {
            assertEq(
                IERC20(data.tokenOut).totalSupply(),
                tokenOutSupply + amountOut + (data.tokenOut == address(_usd1) ? data.fee : 0),
                "token out liability"
            );
        }
    }
    function _assertSwapWhenAssetTokenToUSD1WithAmountIn(SwapData memory data) internal {
        _updatePrice(data.tokenIn, data.price);
        data.amountType = ISwapFunctions.AmountType.In;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        (data.amountOut, data.fee) = _calculateResultWhenAssetTokenToUSD1WithAmountIn(data);
        _assertSwapWhenAssetTokenToUSD1(data);
    }
    function _assertSwapWhenAssetTokenToUSD1WithAmountOut(SwapData memory data) internal {
        _updatePrice(data.tokenIn, data.price);
        data.amountType = ISwapFunctions.AmountType.Out;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        (data.amountIn, data.fee) = _calculateResultWhenAssetTokenToUSD1WithAmountOut(data);
        _assertSwapWhenAssetTokenToUSD1(data);
    }
    function _assertSwapWhenAssetTokenToUSD1(SwapData memory data) internal {
        data.approxPrice = (10 ** _oracle.decimals()) ** 2 / data.price;
        uint232 reserveRatioThreshold = _getReserveRatioThreshold(data.tokenIn, data.tokenOut);
        if (reserveRatioThreshold >= 1e18) {
            uint256 price = _oracle.getLatestPrice(data.tokenIn);
            uint256 collateral = ((data.amountOut + data.fee) * (reserveRatioThreshold + 0.01e18 - 1e18)).ceilDiv(1e18);
            collateral = _convertByFromPriceWhenRoundUp(
                data.tokenOut,
                data.tokenIn,
                collateral,
                price,
                18
            );
            _addCollateral(data.tokenIn, collateral);
        }
        deal(data.tokenIn, data.account, IERC20Metadata(data.tokenIn).balanceOf(address(this)) + data.amountIn);
        _assertSwap(data);
    }
    function _assertSwapWhenUSD1ToAssetTokenWithAmountIn(SwapData memory data) internal {
        _updatePrice(data.tokenOut, data.price);
        data.amountType = ISwapFunctions.AmountType.In;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        (data.amountOut, data.fee) = _calculateResultWhenUSD1ToAssetTokenWithAmountIn(data);
        _assertSwapWhenUSD1ToAssetToken(data);
    }
    function _assertSwapWhenUSD1ToAssetTokenWithAmountOut(SwapData memory data) internal {
         _updatePrice(data.tokenOut, data.price);
        data.amountType = ISwapFunctions.AmountType.Out;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        (data.amountIn, data.fee) = _calculateResultWhenUSD1ToAssetTokenWithAmountOut(data);
        _assertSwapWhenUSD1ToAssetToken(data);
    }
    function _assertSwapWhenUSD1ToAssetToken(SwapData memory data) internal {
        data.approxPrice = data.price;
        if (ERC20Token(data.tokenIn).balanceOf(data.account) < data.amountIn) {
            SwapData memory assetToUSD1Data;
            assetToUSD1Data.account = data.account;
            assetToUSD1Data.tokenIn = data.tokenOut;
            assetToUSD1Data.tokenOut = data.tokenIn;
            assetToUSD1Data.amountOut = data.amountIn;
            assetToUSD1Data.price = _oracle.getLatestPrice(data.tokenOut);
            _assertSwapWhenAssetTokenToUSD1WithAmountOut(assetToUSD1Data);
        }
        _assertSwap(data);
    }
    function _assertSwapWhenUSD1ToStableTokenWithAmountIn(SwapData memory data) internal {
        _updatePrice(data.tokenOut, data.price);
        data.amountType = ISwapFunctions.AmountType.In;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        (data.amountOut, data.fee) = _calculateResultWhenUSD1ToStableTokenWithAmountIn(data);
        _assertSwapWhenUSD1ToStableToken(data);
    }
    function _assertSwapWhenUSD1ToStableTokenWithAmountOut(SwapData memory data) internal {
        _updatePrice(data.tokenOut, data.price);
        data.amountType = ISwapFunctions.AmountType.Out;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        (data.amountIn, data.fee) = _calculateResultWhenUSD1ToStableTokenWithAmountOut(data);
        _assertSwapWhenUSD1ToStableToken(data);
    }
    function _assertSwapWhenUSD1ToStableToken(SwapData memory data) internal  {
        data.approxPrice = data.price;
        if (ERC20Token(data.tokenIn).balanceOf(data.account) < data.amountIn) {
            SwapData memory assetToUSD1Data;
            assetToUSD1Data.account = data.account;
            assetToUSD1Data.tokenIn = address(_usdt);
            assetToUSD1Data.tokenOut = data.tokenIn;
            assetToUSD1Data.amountOut = data.amountIn;
            assetToUSD1Data.price = _oracle.getLatestPrice(address(_usdt));
            _assertSwapWhenAssetTokenToUSD1WithAmountOut(assetToUSD1Data);
        }
        _assertSwap(data);
    }
    function _assertSwapWhenStableTokenToUSD1WithAmountIn(SwapData memory data) internal {
        _updatePrice(data.tokenIn, data.price);
        data.amountType = ISwapFunctions.AmountType.In;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        (data.amountOut, data.fee) = _calculateResultWhenStableTokenToUSD1WithAmountIn(data);
        _assertSwapWhenStableTokenToUSD1(data);
    }
    function _assertSwapWhenStableTokenToUSD1WithAmountOut(SwapData memory data) internal {
        _updatePrice(data.tokenIn, data.price);
        data.amountType = ISwapFunctions.AmountType.Out;
        data.feeNumerator = _getFee(data.tokenIn, data.tokenOut);
        (data.amountIn, data.fee) = _calculateResultWhenStableTokenToUSD1WithAmountOut(data);
        _assertSwapWhenStableTokenToUSD1(data);
    }
    function _assertSwapWhenStableTokenToUSD1(SwapData memory data) internal {
        data.approxPrice = (10 ** _oracle.decimals()) ** 2 / data.price;
        if (ERC20Token(data.tokenIn).balanceOf(data.account) < data.amountIn) {
            SwapData memory usd1ToStableData;
            usd1ToStableData.account = data.account;
            usd1ToStableData.tokenIn = data.tokenOut;
            usd1ToStableData.tokenOut = data.tokenIn;
            usd1ToStableData.amountOut = data.amountIn;
            usd1ToStableData.price = data.price;
            _assertSwapWhenUSD1ToStableTokenWithAmountOut(usd1ToStableData);
        }
        _assertSwap(data);
    }
    function _assertEstimateSwapResultCorrect(SwapData memory data) internal {
        (uint256 amountIn, uint256 amountOut, IERC20Token feeToken, uint256 fee, uint256 feeNumerator, uint256 approxPrice) = _unitas.estimateSwapResult(
            data.tokenIn,
            data.tokenOut,
            data.amountType,
            data.amountType == ISwapFunctions.AmountType.In ? data.amountIn : data.amountOut
        );
        assertEq(amountIn, data.amountIn, "amount in");
        assertEq(amountOut, data.amountOut, "amount out");
        assertEq(fee, data.fee, "fee");
        assertEq(feeNumerator, data.feeNumerator, "fee numerator");
        assertEq(address(feeToken), address(_usd1), "fee");
        assertEq(approxPrice, data.approxPrice, "approx price");
    }
    function _removeTokenAndPairs(address token) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        uint256 pairTokenCount = _tokenManager.pairTokenLength(address(token));
        address[] memory pairTokensX = new address[](pairTokenCount);
        address[] memory pairTokensY = _tokenManager.listPairTokensByIndexAndCount(token, 0, pairTokenCount);
        for (uint256 i = 0; i < pairTokenCount; i++) {
            pairTokensX[i] = token;
        }
        _removeTokensAndPairs(tokens, pairTokensX, pairTokensY);
    }
    function _removeTokensAndPairs(
        address[] memory tokens,
        address[] memory pairTokensX,
        address[] memory pairTokensY
    ) internal {
        assertEq(pairTokensX.length, pairTokensY.length, "pair tokens x length eq pair tokens y length");
        vm.prank(_timelock);
        _tokenManager.removeTokensAndPairs(tokens, pairTokensX, pairTokensY);
    }
    function _checkSkipAccount(address account) internal view {
        vm.assume(!_isAccountExcluded(account));
    }
    function _isAccountExcluded(address account) internal view returns (bool) {
        return account == address(0) ||
            account == address(_unitas) ||
            account == address(_insurancePool) ||
            account == address(_surplusPool) ||
            account == address(_proxyAdmin);
    }
    function _paused() internal view returns (bool) {
        return Pausable(address(_unitas)).paused();
    }
    function _getInitializeConfig() internal view returns (IUnitas.InitializeConfig memory config) {
        return IUnitas.InitializeConfig({
            governor: _governor,
            guardian: _guardian,
            timelock: _timelock,
            oracle: address(_oracle),
            surplusPool: _surplusPool,
            insurancePool: address(_insurancePool),
            tokenManager: _tokenManager
        });
    }
    function _getFee(address tokenIn, address tokenOut) internal view returns (uint24 fee) {
        ITokenManager.PairConfig memory pair = _tokenManager.getPair(tokenIn, tokenOut);
        fee = tokenOut == pair.baseToken ? pair.buyFee : pair.sellFee;
    }
    function _getReserveRatioThreshold(address tokenIn, address tokenOut) internal view returns (uint232 reserveRatioThreshold) {
        ITokenManager.PairConfig memory pair = _tokenManager.getPair(tokenIn, tokenOut);
        reserveRatioThreshold = tokenOut == pair.baseToken ? pair.buyReserveRatioThreshold : pair.sellReserveRatioThreshold;
    }
    function _convertByFromPriceWhenRoundUp(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 fromPrice,
        uint8 priceDecimals
    ) internal view returns (uint256) {
        uint8 fromDecimals = IERC20Metadata(fromToken).decimals();
        uint8 toDecimals = IERC20Metadata(toToken).decimals();
        return (fromAmount * fromPrice).ceilDiv(10 ** (fromDecimals + priceDecimals - toDecimals));
    }
    function _convertByFromPriceWhenRoundDown(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 fromPrice,
        uint8 priceDecimals
    ) internal view returns (uint256) {
        uint8 fromDecimals = IERC20Metadata(fromToken).decimals();
        uint8 toDecimals = IERC20Metadata(toToken).decimals();
        return fromAmount * fromPrice / (10 ** (fromDecimals + priceDecimals - toDecimals));
    }
    function _convertByToPriceWhenRoundUp(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 toPrice,
        uint8 priceDecimals
    ) internal view returns (uint256) {
        uint8 fromDecimals = IERC20Metadata(fromToken).decimals();
        uint8 toDecimals = IERC20Metadata(toToken).decimals();
        return (fromAmount * (10 ** (toDecimals + priceDecimals - fromDecimals))).ceilDiv(toPrice);
    }
    function _convertByToPriceWhenRoundDown(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 toPrice,
        uint8 priceDecimal
    ) internal view returns (uint256) {
        uint8 fromDecimals = IERC20Metadata(fromToken).decimals();
        uint8 toDecimals = IERC20Metadata(toToken).decimals();
        return fromAmount * (10 ** (toDecimals + priceDecimal - fromDecimals)) / toPrice;
    }
    function _calculateResultWhenAssetTokenToUSD1WithAmountIn(SwapData memory data) internal view returns (uint256 amountOut, uint256 fee) {
        amountOut = _convertByToPriceWhenRoundDown(data.tokenIn, data.tokenOut, data.amountIn, data.price, 18);
        fee = _calculateFee(amountOut, data.feeNumerator, _tokenManager.SWAP_FEE_BASE());
        amountOut -= fee;
    }
    function _calculateResultWhenAssetTokenToUSD1WithAmountOut(SwapData memory data) internal view returns (uint256 amountIn, uint256 fee) {
        fee = _calculateFeeByAmountWithoutFee(data.amountOut, data.feeNumerator, _tokenManager.SWAP_FEE_BASE());
        amountIn = _convertByFromPriceWhenRoundUp(data.tokenOut, data.tokenIn, data.amountOut + fee, data.price, 18);
    }
    function _calculateResultWhenUSD1ToAssetTokenWithAmountIn(SwapData memory data) internal view returns (uint256 amountOut, uint256 fee) {
        fee = _calculateFee(data.amountIn, data.feeNumerator, _tokenManager.SWAP_FEE_BASE());
        amountOut = _convertByFromPriceWhenRoundDown(data.tokenIn, data.tokenOut, data.amountIn - fee, data.price, 18);
    }
    function _calculateResultWhenUSD1ToAssetTokenWithAmountOut(SwapData memory data) internal view returns (uint256 amountIn, uint256 fee) {
        amountIn = _convertByToPriceWhenRoundUp(data.tokenOut, data.tokenIn, data.amountOut, data.price, 18);
        fee =  _calculateFeeByAmountWithoutFee(amountIn, data.feeNumerator, _tokenManager.SWAP_FEE_BASE());
        amountIn += fee;
    }
    function _calculateResultWhenUSD1ToStableTokenWithAmountIn(SwapData memory data) internal view returns (uint256 amountOut, uint256 fee) {
        fee = _calculateFee(data.amountIn, data.feeNumerator, _tokenManager.SWAP_FEE_BASE());
        amountOut = _convertByFromPriceWhenRoundDown(data.tokenIn, data.tokenOut, data.amountIn - fee, data.price, 18);
    }
    function _calculateResultWhenUSD1ToStableTokenWithAmountOut(SwapData memory data) internal view returns (uint256 amountIn, uint256 fee) {
        amountIn = _convertByToPriceWhenRoundUp(data.tokenOut, data.tokenIn, data.amountOut, data.price, 18);
        fee = _calculateFeeByAmountWithoutFee(amountIn, data.feeNumerator, _tokenManager.SWAP_FEE_BASE());
        amountIn += fee;
    }
    function _calculateResultWhenStableTokenToUSD1WithAmountIn(SwapData memory data) internal view returns (uint256 amountOut, uint256 fee) {
        amountOut = _convertByToPriceWhenRoundDown(data.tokenIn, data.tokenOut, data.amountIn, data.price, 18);
        fee = _calculateFee(amountOut, data.feeNumerator, _tokenManager.SWAP_FEE_BASE());
        amountOut -= fee;
    }
    function _calculateResultWhenStableTokenToUSD1WithAmountOut(SwapData memory data) internal view returns (uint256 amountIn, uint256 fee) {
        fee = _calculateFeeByAmountWithoutFee(data.amountOut, data.feeNumerator, _tokenManager.SWAP_FEE_BASE());
        amountIn = _convertByFromPriceWhenRoundUp(data.tokenOut, data.tokenIn, data.amountOut + fee, data.price, 18);
    }
    function _calculateFee(uint256 amount, uint256 feeNumerator, uint256 feeDenominator)
        internal
        pure
        returns (uint256)
    {
        return (amount * feeNumerator).ceilDiv(feeDenominator);
    }
    function _calculateFeeByAmountWithoutFee(uint256 amount, uint256 feeNumerator, uint256 feeDenominator)
        internal
        pure
        returns (uint256)
    {
        uint256 amountWithFee = (amount * feeDenominator).ceilDiv(feeDenominator - feeNumerator);
        return amountWithFee - amount;
    }
}
contract UnitasProxyUpgradedTest is UnitasTest {
    function setUp() public virtual override {
        super.setUp();
        _assertUpgradedUnitasV2();
    }
}
contract UnitasHarness is Unitas {
    constructor() {}
    function exposed_swapIn(address token, address spender, uint256 amount) external {
        return _swapIn(token, spender, amount);
    }
    function exposed_swapOut(address token, address receiver, uint256 amount) external {
        return _swapOut(token, receiver, amount);
    }
    function exposed_getSwapResult(ITokenManager.PairConfig memory pair, address tokenIn, address tokenOut, AmountType amountType, uint256 amount)
        external
        view
        returns (uint256 amountIn, uint256 amountOut, IERC20Token feeToken, uint256 fee, uint256 feeNumerator, uint256 price)
    {
        return _getSwapResult(pair, tokenIn, tokenOut, amountType, amount);
    }
    function exposed_getReserveStatus(uint256 allReserves, uint256 liabilities)
        external
        view
        returns (IUnitas.ReserveStatus reserveStatus, uint256 reserveRatio)
    {
        return _getReserveStatus(allReserves, liabilities);
    }
    function exposed_getTotalReservesAndCollaterals() external view returns (uint256 reserves, uint256 collaterals) {
        return _getTotalReservesAndCollaterals();
    }
    function exposed_getTotalLiabilities() external view returns (uint256) {
        return _getTotalLiabilities();
    }
    function exposed_checkPrice(address token, uint256 price) external view {
        return _checkPrice(token, price);
    }
    function exposed_getPriceQuoteToken(address tokenX, address tokenY) external view returns (address quoteToken) {
        return _getPriceQuoteToken(tokenX, tokenY);
    }
    function exposed_checkReserveRatio(uint232 reserveRatioThreshold) external view {
         _checkReserveRatio(reserveRatioThreshold);
    }
}
contract UnitasHarnessV2NewParent {
    uint256 internal _parentValue;
    function parentValue() external view returns (uint256) {
        return _parentValue;
    }
    function setParentValue(uint256 newValue) external {
        _parentValue = newValue;
    }
}
contract UnitasHarnessV2 is UnitasHarness, UnitasHarnessV2NewParent {
    uint256 internal _value;
    uint256 internal _timelockValue;
    function setValue(uint256 newValue) external {
        _value = newValue;
    }
    function value() external view returns (uint256) {
        return _value;
    }
    function setTimelockValue(uint256 newValue) external onlyTimelock {
        _timelockValue = newValue;
    }
    function timelockValue() external view returns (uint256) {
        return _timelockValue;
    }
    function version() external pure returns (uint256) {
        return 2;
    }
}