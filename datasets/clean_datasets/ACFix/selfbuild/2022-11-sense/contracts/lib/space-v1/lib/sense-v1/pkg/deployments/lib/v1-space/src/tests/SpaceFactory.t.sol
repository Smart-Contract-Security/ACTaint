pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import {DSTest} from "@sense-finance/v1-core/src/tests/test-helpers/test.sol";
import {MockDividerSpace, MockAdapterSpace, ERC20Mintable} from "./utils/Mocks.sol";
import {VM} from "./utils/VM.sol";
import {Vault, IVault, IWETH} from "@balancer-labs/v2-vault/contracts/Vault.sol";
import {Authorizer} from "@balancer-labs/v2-vault/contracts/Authorizer.sol";
import {FixedPoint} from "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import {SpaceFactory} from "../SpaceFactory.sol";
import {Space} from "../Space.sol";
import {Errors} from "../Errors.sol";
contract SpaceFactoryTest is DSTest {
    using FixedPoint for uint256;
    VM internal constant vm = VM(HEVM_ADDRESS);
    IWETH internal constant weth =
        IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    Vault internal vault;
    SpaceFactory internal spaceFactory;
    MockDividerSpace internal divider;
    MockAdapterSpace internal adapter;
    uint256 internal maturity1;
    uint256 internal maturity2;
    uint256 internal maturity3;
    uint256 internal ts;
    uint256 internal g1;
    uint256 internal g2;
    function setUp() public {
        vm.warp(0);
        vm.roll(0);
        divider = new MockDividerSpace(18);
        adapter = new MockAdapterSpace(18);
        ts = FixedPoint.ONE.divDown(FixedPoint.ONE * 31622400); 
        g1 = (FixedPoint.ONE * 950).divDown(FixedPoint.ONE * 1000);
        g2 = (FixedPoint.ONE * 1000).divDown(FixedPoint.ONE * 950);
        maturity1 = 15811200; 
        maturity2 = 31560000; 
        maturity3 = 63120000; 
        Authorizer authorizer = new Authorizer(address(this));
        vault = new Vault(authorizer, weth, 0, 0);
        spaceFactory = new SpaceFactory(
            vault,
            address(divider),
            ts,
            g1,
            g2,
            true
        );
    }
    function testCreatePool() public {
        address space = spaceFactory.create(address(adapter), maturity1);
        assertTrue(space != address(0));
        assertEq(space, spaceFactory.pools(address(adapter), maturity1));
        try spaceFactory.create(address(adapter), maturity1) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.POOL_ALREADY_DEPLOYED);
        }
    }
    function testSetParams() public {
        Space space = Space(spaceFactory.create(address(adapter), maturity1));
        assertEq(space.ts(), ts);
        assertEq(space.g1(), g1);
        assertEq(space.g2(), g2);
        ts = FixedPoint.ONE.divDown(FixedPoint.ONE * 100);
        g1 = (FixedPoint.ONE * 900).divDown(FixedPoint.ONE * 1000);
        g2 = (FixedPoint.ONE * 1000).divDown(FixedPoint.ONE * 900);
        spaceFactory.setParams(ts, g1, g2, true);
        space = Space(spaceFactory.create(address(adapter), maturity2));
        assertEq(space.ts(), ts);
        assertEq(space.g1(), g1);
        assertEq(space.g2(), g2);
        g1 = (FixedPoint.ONE * 1000).divDown(FixedPoint.ONE * 900);
        try spaceFactory.setParams(ts, g1, g2, true) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.INVALID_G1);
        }
        g1 = (FixedPoint.ONE * 900).divDown(FixedPoint.ONE * 1000);
        g2 = (FixedPoint.ONE * 900).divDown(FixedPoint.ONE * 1000);
        try spaceFactory.setParams(ts, g1, g2, true) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.INVALID_G2);
        }
    }
}