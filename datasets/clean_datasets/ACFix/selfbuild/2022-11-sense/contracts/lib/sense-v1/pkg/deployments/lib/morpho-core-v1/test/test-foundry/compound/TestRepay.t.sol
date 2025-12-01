pragma solidity 0.8.13;
import "./setup/TestSetup.sol";
contract TestRepay is TestSetup {
    using CompoundMath for uint256;
    function testRepay1() public {
        uint256 amount = 10_000 ether;
        uint256 collateral = 2 * amount;
        borrower1.approve(usdc, to6Decimals(collateral));
        borrower1.supply(cUsdc, to6Decimals(collateral));
        borrower1.borrow(cDai, amount);
        moveOneBlockForwardBorrowRepay();
        borrower1.approve(dai, amount);
        borrower1.repay(cDai, amount);
        (uint256 inP2P, uint256 onPool) = morpho.borrowBalanceInOf(cDai, address(borrower1));
        assertEq(inP2P, 0);
        testEqualityLarge(onPool, 0);
    }
    function testRepayAll() public {
        uint256 amount = 10_000 ether;
        uint256 collateral = 2 * amount;
        borrower1.approve(usdc, to6Decimals(collateral));
        borrower1.supply(cUsdc, to6Decimals(collateral));
        borrower1.borrow(cDai, amount);
        moveOneBlockForwardBorrowRepay();
        uint256 balanceBefore = borrower1.balanceOf(dai);
        borrower1.approve(dai, type(uint256).max);
        borrower1.repay(cDai, type(uint256).max);
        (uint256 inP2P, uint256 onPool) = morpho.borrowBalanceInOf(cDai, address(borrower1));
        uint256 balanceAfter = supplier1.balanceOf(dai);
        assertEq(inP2P, 0);
        assertEq(onPool, 0);
        testEquality(balanceBefore - balanceAfter, amount);
    }
    function testRepay2_1() public {
        uint256 suppliedAmount = 10000 ether;
        uint256 borrowedAmount = 2 * suppliedAmount;
        uint256 collateral = 2 * borrowedAmount;
        borrower1.approve(usdc, to6Decimals(collateral));
        borrower1.supply(cUsdc, to6Decimals(collateral));
        borrower1.borrow(cDai, borrowedAmount);
        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(cDai, suppliedAmount);
        (uint256 inP2PBorrower1, uint256 onPoolBorrower1) = morpho.borrowBalanceInOf(
            cDai,
            address(borrower1)
        );
        (uint256 inP2PSupplier, uint256 onPoolSupplier) = morpho.supplyBalanceInOf(
            cDai,
            address(supplier1)
        );
        assertEq(onPoolSupplier, 0, "supplier on pool");
        assertEq(
            inP2PSupplier,
            suppliedAmount.div(morpho.p2pSupplyIndex(cDai)),
            "supplier in peer-to-peer"
        );
        assertEq(
            onPoolBorrower1,
            suppliedAmount.div(ICToken(cDai).borrowIndex()),
            "borrower on pool"
        );
        assertEq(
            inP2PBorrower1,
            suppliedAmount.div(morpho.p2pBorrowIndex(cDai)),
            "borrower in peer-to-peer"
        );
        uint256 availableBorrowerAmount = borrowedAmount / 4;
        borrower2.approve(usdc, to6Decimals(collateral));
        borrower2.supply(cUsdc, to6Decimals(collateral));
        borrower2.borrow(cDai, availableBorrowerAmount);
        moveOneBlockForwardBorrowRepay();
        borrower1.approve(dai, (75 * borrowedAmount) / 100);
        borrower1.repay(cDai, (75 * borrowedAmount) / 100);
        (inP2PBorrower1, onPoolBorrower1) = morpho.borrowBalanceInOf(cDai, address(borrower1));
        (uint256 inP2PAvailableBorrower, uint256 onPoolAvailableBorrower) = morpho
        .borrowBalanceInOf(cDai, address(borrower2));
        uint256 expectedBorrowBalanceInP2P = ((25 * borrowedAmount) / 100).div(
            morpho.p2pBorrowIndex(cDai)
        );
        testEqualityLarge(inP2PBorrower1, inP2PAvailableBorrower, "available in P2P");
        testEqualityLarge(inP2PBorrower1, expectedBorrowBalanceInP2P, "borrower in P2P 2");
        assertApproxEqAbs(onPoolAvailableBorrower, 0, 1e16, "available on pool");
        assertEq(onPoolBorrower1, 0, "borrower on pool 2");
        uint256 expectedInP2P = suppliedAmount.div(morpho.p2pSupplyIndex(cDai));
        (inP2PSupplier, onPoolSupplier) = morpho.supplyBalanceInOf(cDai, address(supplier1));
        testEqualityLarge(inP2PSupplier, expectedInP2P, "supplier in P2P 2");
        assertEq(onPoolSupplier, 0, "supplier on pool 2");
    }
    function testRepay2_2() public {
        _setDefaultMaxGasForMatching(
            type(uint64).max,
            type(uint64).max,
            type(uint64).max,
            type(uint64).max
        );
        uint256 suppliedAmount = 10_000 ether;
        uint256 borrowedAmount = 2 * suppliedAmount;
        uint256 collateral = 2 * borrowedAmount;
        borrower1.approve(usdc, to6Decimals(collateral));
        borrower1.supply(cUsdc, to6Decimals(collateral));
        borrower1.borrow(cDai, borrowedAmount);
        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(cDai, suppliedAmount);
        (uint256 inP2PBorrower1, uint256 onPoolBorrower1) = morpho.borrowBalanceInOf(
            cDai,
            address(borrower1)
        );
        (uint256 inP2PSupplier, uint256 onPoolSupplier) = morpho.supplyBalanceInOf(
            cDai,
            address(supplier1)
        );
        assertEq(onPoolSupplier, 0);
        testEqualityLarge(
            inP2PSupplier,
            suppliedAmount.div(morpho.p2pSupplyIndex(cDai)),
            "supplier in peer-to-peer"
        );
        testEqualityLarge(
            onPoolBorrower1,
            suppliedAmount.div(ICToken(cDai).borrowIndex()),
            "borrower on pool"
        );
        testEqualityLarge(
            inP2PBorrower1,
            suppliedAmount.div(morpho.p2pBorrowIndex(cDai)),
            "borrower in peer-to-peer"
        );
        uint256 NMAX = 20;
        createSigners(NMAX);
        Types.BorrowBalance memory vars;
        uint256 borrowIndex = ICToken(cDai).borrowIndex();
        uint256 amountPerBorrower = (borrowedAmount - suppliedAmount) / (NMAX - 1);
        uint256 expectedOnPool;
        for (uint256 i = 0; i < NMAX; i++) {
            if (borrowers[i] == borrower1) continue;
            borrowers[i].approve(usdc, to6Decimals(collateral));
            borrowers[i].supply(cUsdc, to6Decimals(collateral));
            borrowers[i].borrow(cDai, amountPerBorrower);
            (vars.inP2P, vars.onPool) = morpho.borrowBalanceInOf(cDai, address(borrowers[i]));
            expectedOnPool = amountPerBorrower.div(borrowIndex);
            assertEq(vars.inP2P, 0);
            assertEq(vars.onPool, expectedOnPool);
        }
        moveOneBlockForwardBorrowRepay();
        borrower1.approve(dai, type(uint256).max);
        borrower1.repay(cDai, type(uint256).max);
        (inP2PBorrower1, onPoolBorrower1) = morpho.borrowBalanceInOf(cDai, address(borrower1));
        assertEq(onPoolBorrower1, 0);
        assertEq(inP2PBorrower1, 0);
        (inP2PSupplier, onPoolSupplier) = morpho.supplyBalanceInOf(cDai, address(supplier1));
        uint256 expectedSupplyBalanceInP2P = suppliedAmount.div(morpho.p2pSupplyIndex(cDai));
        testEqualityLarge(inP2PSupplier, expectedSupplyBalanceInP2P, "supplier in peer-to-peer");
        assertEq(onPoolSupplier, 0, "supplier on pool");
        for (uint256 i = 0; i < borrowers.length; i++) {
            if (borrowers[i] == borrower1) continue;
            (vars.inP2P, vars.onPool) = morpho.borrowBalanceInOf(cDai, address(borrowers[i]));
            uint256 expectedInP2P = expectedOnPool.mul(ICToken(cDai).borrowIndex()).div(
                morpho.p2pBorrowIndex(cDai)
            );
            testEqualityLarge(vars.inP2P, expectedInP2P, "borrower in peer-to-peer");
            testEqualityLarge(vars.onPool, 0, "borrower on pool");
        }
    }
    function testRepay2_3() public {
        uint256 suppliedAmount = 10_000 ether;
        uint256 borrowedAmount = 2 * suppliedAmount;
        uint256 collateral = 2 * borrowedAmount;
        borrower1.approve(usdc, to6Decimals(collateral));
        borrower1.supply(cUsdc, to6Decimals(collateral));
        borrower1.borrow(cDai, borrowedAmount);
        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(cDai, suppliedAmount);
        (uint256 inP2PBorrower1, uint256 onPoolBorrower1) = morpho.borrowBalanceInOf(
            cDai,
            address(borrower1)
        );
        (uint256 inP2PSupplier, uint256 onPoolSupplier) = morpho.supplyBalanceInOf(
            cDai,
            address(supplier1)
        );
        assertEq(onPoolSupplier, 0);
        assertEq(
            inP2PSupplier,
            suppliedAmount.div(morpho.p2pSupplyIndex(cDai)),
            "supplier in peer-to-peer"
        );
        assertEq(
            onPoolBorrower1,
            suppliedAmount.div(ICToken(cDai).borrowIndex()),
            "borrower on pool"
        );
        assertEq(
            inP2PBorrower1,
            suppliedAmount.div(morpho.p2pBorrowIndex(cDai)),
            "borrower in peer-to-peer"
        );
        moveOneBlockForwardBorrowRepay();
        borrower1.approve(dai, (75 * borrowedAmount) / 100);
        borrower1.repay(cDai, (75 * borrowedAmount) / 100);
        (inP2PBorrower1, onPoolBorrower1) = morpho.borrowBalanceInOf(cDai, address(borrower1));
        uint256 expectedBorrowBalanceInP2P = ((25 * borrowedAmount) / 100).div(
            morpho.p2pBorrowIndex(cDai)
        );
        testEqualityLarge(inP2PBorrower1, expectedBorrowBalanceInP2P, "borrower in P2P");
        assertEq(onPoolBorrower1, 0);
        (inP2PSupplier, onPoolSupplier) = morpho.supplyBalanceInOf(cDai, address(supplier1));
        uint256 expectedSupplyBalanceInP2P = (suppliedAmount / 2).div(morpho.p2pSupplyIndex(cDai));
        uint256 expectedSupplyBalanceOnPool = (suppliedAmount / 2).div(
            ICToken(cDai).exchangeRateCurrent()
        );
        testEqualityLarge(inP2PSupplier, expectedSupplyBalanceInP2P, "supplier in P2P 2");
        testEqualityLarge(onPoolSupplier, expectedSupplyBalanceOnPool, "supplier on pool 2");
    }
    function testRepay2_4() public {
        _setDefaultMaxGasForMatching(
            type(uint64).max,
            type(uint64).max,
            type(uint64).max,
            type(uint64).max
        );
        uint256 suppliedAmount = 10_000 ether;
        uint256 borrowedAmount = 2 * suppliedAmount;
        uint256 collateral = 2 * borrowedAmount;
        borrower1.approve(usdc, to6Decimals(collateral));
        borrower1.supply(cUsdc, to6Decimals(collateral));
        borrower1.borrow(cDai, borrowedAmount);
        supplier1.approve(dai, suppliedAmount);
        supplier1.supply(cDai, suppliedAmount);
        (uint256 inP2PBorrower1, uint256 onPoolBorrower1) = morpho.borrowBalanceInOf(
            cDai,
            address(borrower1)
        );
        (uint256 inP2PSupplier, uint256 onPoolSupplier) = morpho.supplyBalanceInOf(
            cDai,
            address(supplier1)
        );
        testEqualityLarge(onPoolSupplier, 0);
        testEqualityLarge(
            inP2PSupplier,
            suppliedAmount.div(morpho.p2pSupplyIndex(cDai)),
            "supplier in peer-to-peer"
        );
        assertEq(
            onPoolBorrower1,
            suppliedAmount.div(ICToken(cDai).borrowIndex()),
            "borrower on pool"
        );
        assertEq(
            inP2PBorrower1,
            suppliedAmount.div(morpho.p2pBorrowIndex(cDai)),
            "borrower in peer-to-peer"
        );
        uint256 NMAX = 20;
        createSigners(NMAX);
        uint256 amountPerBorrower = (borrowedAmount - suppliedAmount) / (2 * (NMAX - 1));
        for (uint256 i = 0; i < NMAX; i++) {
            if (borrowers[i] == borrower1) continue;
            borrowers[i].approve(usdc, to6Decimals(collateral));
            borrowers[i].supply(cUsdc, to6Decimals(collateral));
            borrowers[i].borrow(cDai, amountPerBorrower);
        }
        moveOneBlockForwardBorrowRepay();
        borrower1.approve(dai, borrowedAmount);
        borrower1.repay(cDai, borrowedAmount);
        (inP2PBorrower1, onPoolBorrower1) = morpho.borrowBalanceInOf(cDai, address(borrower1));
        assertEq(onPoolBorrower1, 0);
        testEqualityLarge(inP2PBorrower1, 0);
        (inP2PSupplier, onPoolSupplier) = morpho.supplyBalanceInOf(cDai, address(supplier1));
        uint256 expectedSupplyBalanceOnPool = (suppliedAmount / 2).div(
            ICToken(cDai).exchangeRateCurrent()
        );
        uint256 expectedSupplyBalanceInP2P = (suppliedAmount / 2).div(morpho.p2pSupplyIndex(cDai));
        testEqualityLarge(inP2PSupplier, expectedSupplyBalanceInP2P, "supplier in peer-to-peer");
        testEqualityLarge(onPoolSupplier, expectedSupplyBalanceOnPool, "supplier on pool");
        uint256 inP2P;
        uint256 onPool;
        for (uint256 i = 0; i < borrowers.length; i++) {
            if (borrowers[i] == borrower1) continue;
            (inP2P, onPool) = morpho.borrowBalanceInOf(cDai, address(borrowers[i]));
            testEqualityLarge(
                inP2P,
                amountPerBorrower.div(morpho.p2pBorrowIndex(cDai)),
                "borrower in peer-to-peer"
            );
            assertEq(onPool, 0, "borrower on pool");
        }
    }
    struct Vars {
        uint256 LR;
        uint256 SPI;
        uint256 BPY;
        uint256 VBR;
        uint256 SP2PD;
        uint256 SP2PA;
        uint256 SP2PER;
    }
    function testDeltaRepay() public {
        _setDefaultMaxGasForMatching(3e6, 3e6, 3e6, 1e6);
        uint256 suppliedAmount = 1 ether;
        uint256 borrowedAmount = 20 * suppliedAmount;
        uint256 collateral = 2 * borrowedAmount;
        uint256 expectedBorrowBalanceInP2P;
        borrower1.approve(usdc, to6Decimals(collateral));
        borrower1.supply(cUsdc, to6Decimals(collateral));
        borrower1.borrow(cDai, borrowedAmount);
        createSigners(30);
        uint256 matched;
        for (uint256 i = 0; i < 20; i++) {
            suppliers[i].approve(dai, suppliedAmount);
            suppliers[i].supply(cDai, suppliedAmount);
            matched += suppliedAmount.div(morpho.p2pSupplyIndex(cDai));
        }
        {
            uint256 p2pBorrowIndex = morpho.p2pBorrowIndex(cDai);
            expectedBorrowBalanceInP2P = borrowedAmount.div(p2pBorrowIndex);
            (uint256 inP2PBorrower, uint256 onPoolBorrower) = morpho.borrowBalanceInOf(
                cDai,
                address(borrower1)
            );
            assertApproxEqAbs(onPoolBorrower, 0, 10, "borrower on pool");
            testEqualityLarge(
                inP2PBorrower,
                expectedBorrowBalanceInP2P,
                "borrower in peer-to-peer"
            );
            uint256 p2pSupplyIndex = morpho.p2pSupplyIndex(cDai);
            uint256 expectedSupplyBalanceInP2P = suppliedAmount.div(p2pSupplyIndex);
            for (uint256 i = 0; i < 20; i++) {
                (uint256 inP2PSupplier, uint256 onPoolSupplier) = morpho.supplyBalanceInOf(
                    cDai,
                    address(suppliers[i])
                );
                testEqualityLarge(onPoolSupplier, 0, "supplier on pool 1");
                testEquality(
                    inP2PSupplier,
                    expectedSupplyBalanceInP2P,
                    "supplier in peer-to-peer 1"
                );
            }
            moveOneBlockForwardBorrowRepay();
            borrower1.approve(dai, type(uint256).max);
            borrower1.repay(cDai, type(uint256).max);
            {
                (uint256 inP2PBorrower1, uint256 onPoolBorrower1) = morpho.supplyBalanceInOf(
                    cDai,
                    address(borrower1)
                );
                assertEq(onPoolBorrower1, 0);
                assertEq(inP2PBorrower1, 0);
            }
            uint256 unmatched = 10 * expectedSupplyBalanceInP2P.mul(morpho.p2pSupplyIndex(cDai));
            uint256 expectedp2pSupplyDeltaInUnderlying = (matched.mul(morpho.p2pSupplyIndex(cDai)) -
                unmatched);
            uint256 expectedp2pSupplyDelta = (matched.mul(morpho.p2pSupplyIndex(cDai)) - unmatched)
            .div(ICToken(cDai).exchangeRateCurrent());
            (uint256 p2pSupplyDelta, , , ) = morpho.deltas(cDai);
            assertApproxEqAbs(p2pSupplyDelta, expectedp2pSupplyDelta, 10, "supply delta 1");
            borrower2.approve(usdc, to6Decimals(collateral));
            borrower2.supply(cUsdc, to6Decimals(collateral));
            borrower2.borrow(cDai, expectedp2pSupplyDeltaInUnderlying / 2);
            (inP2PBorrower, onPoolBorrower) = morpho.borrowBalanceInOf(cDai, address(borrower2));
            expectedBorrowBalanceInP2P = (expectedp2pSupplyDeltaInUnderlying / 2).div(
                p2pBorrowIndex
            );
            (p2pSupplyDelta, , , ) = morpho.deltas(cDai);
            assertApproxEqAbs(
                p2pSupplyDelta,
                expectedp2pSupplyDelta / 2,
                10,
                "supply delta unexpected"
            );
            assertEq(onPoolBorrower, 0, "on pool unexpected");
            assertApproxEqAbs(
                inP2PBorrower,
                expectedBorrowBalanceInP2P,
                1e3,
                "in peer-to-peer unexpected"
            );
        }
        {
            Vars memory oldVars;
            Vars memory newVars;
            (oldVars.SP2PD, , oldVars.SP2PA, ) = morpho.deltas(cDai);
            oldVars.SPI = ICToken(cDai).exchangeRateCurrent();
            oldVars.SP2PER = morpho.p2pSupplyIndex(cDai);
            (oldVars.BPY, ) = getApproxP2PRates(cDai);
            move1000BlocksForward(cDai);
            morpho.updateP2PIndexes(cDai);
            (newVars.SP2PD, , newVars.SP2PA, ) = morpho.deltas(cDai);
            newVars.SPI = ICToken(cDai).exchangeRateCurrent();
            newVars.SP2PER = morpho.p2pSupplyIndex(cDai);
            newVars.LR = ICToken(cDai).supplyRatePerBlock();
            newVars.VBR = ICToken(cDai).borrowRatePerBlock();
            uint256 shareOfTheDelta = newVars.SP2PD.mul(newVars.SPI).div(oldVars.SP2PER).div(
                newVars.SP2PA
            );
            uint256 expectedSP2PER = oldVars.SP2PER.mul(
                _computeCompoundedInterest(oldVars.BPY, 1_000).mul(WAD - shareOfTheDelta) +
                    shareOfTheDelta.mul(newVars.SPI).div(oldVars.SPI)
            );
            assertApproxEqAbs(
                expectedSP2PER,
                newVars.SP2PER,
                (expectedSP2PER * 2) / 100,
                "SP2PER not expected"
            );
            uint256 expectedSupplyBalanceInUnderlying = suppliedAmount.div(oldVars.SP2PER).mul(
                expectedSP2PER
            );
            for (uint256 i = 10; i < 20; i++) {
                (uint256 inP2PSupplier, uint256 onPoolSupplier) = morpho.supplyBalanceInOf(
                    cDai,
                    address(suppliers[i])
                );
                assertApproxEqAbs(
                    inP2PSupplier.mul(newVars.SP2PER),
                    expectedSupplyBalanceInUnderlying,
                    (expectedSupplyBalanceInUnderlying * 2) / 100,
                    "supplier in peer-to-peer 2"
                );
                assertEq(onPoolSupplier, 0, "supplier on pool 2");
            }
        }
        for (uint256 i = 10; i < 20; i++) {
            suppliers[i].withdraw(cDai, suppliedAmount);
        }
        (uint256 p2pSupplyDeltaAfter, , , ) = morpho.deltas(cDai);
        testEquality(p2pSupplyDeltaAfter, 0, "supply delta after");
        (uint256 inP2PBorrower2, uint256 onPoolBorrower2) = morpho.borrowBalanceInOf(
            cDai,
            address(borrower2)
        );
        assertApproxEqAbs(
            inP2PBorrower2,
            expectedBorrowBalanceInP2P,
            1e3,
            "borrower2 in peer-to-peer"
        );
        assertEq(onPoolBorrower2, 0, "borrower2 on pool");
    }
    function testDeltaRepayAll() public {
        _setDefaultMaxGasForMatching(3e6, 3e6, 3e6, 1e6);
        uint256 suppliedAmount = 1 ether;
        uint256 borrowedAmount = 20 * suppliedAmount;
        uint256 collateral = 2 * borrowedAmount;
        borrower1.approve(usdc, to6Decimals(collateral));
        borrower1.supply(cUsdc, to6Decimals(collateral));
        borrower1.borrow(cDai, borrowedAmount);
        createSigners(30);
        for (uint256 i = 0; i < 20; i++) {
            suppliers[i].approve(dai, suppliedAmount);
            suppliers[i].supply(cDai, suppliedAmount);
        }
        for (uint256 i = 0; i < 20; i++) {
            (uint256 inP2P, uint256 onPool) = morpho.supplyBalanceInOf(cDai, address(suppliers[i]));
            assertEq(inP2P, suppliedAmount.div(morpho.p2pSupplyIndex(cDai)), "inP2P");
            assertEq(onPool, 0, "onPool");
        }
        moveOneBlockForwardBorrowRepay();
        borrower1.approve(dai, type(uint256).max);
        borrower1.repay(cDai, type(uint256).max);
        for (uint256 i = 0; i < 10; i++) {
            (uint256 inP2P, uint256 onPool) = morpho.supplyBalanceInOf(cDai, address(suppliers[i]));
            assertEq(inP2P, 0, "inP2P");
            assertApproxEqAbs(
                onPool,
                suppliedAmount.div(ICToken(cDai).exchangeRateCurrent()),
                1e2,
                "onPool"
            );
        }
        for (uint256 i = 10; i < 20; i++) {
            (uint256 inP2P, uint256 onPool) = morpho.supplyBalanceInOf(cDai, address(suppliers[i]));
            assertApproxEqAbs(
                inP2P,
                suppliedAmount.div(morpho.p2pSupplyIndex(cDai)),
                100_000,
                "inP2P"
            );
            assertEq(onPool, 0, "onPool");
        }
        (
            uint256 p2pSupplyDelta,
            uint256 p2pBorrowDelta,
            uint256 p2pSupplyAmount,
            uint256 p2pBorrowAmount
        ) = morpho.deltas(cDai);
        assertApproxEqAbs(
            p2pSupplyDelta,
            (10 * suppliedAmount).div(ICToken(cDai).exchangeRateCurrent()),
            1_000_000,
            "p2pSupplyDelta"
        );
        assertEq(p2pBorrowDelta, 0, "p2pBorrowDelta");
        assertApproxEqAbs(
            p2pSupplyAmount,
            (10 * suppliedAmount).div(morpho.p2pSupplyIndex(cDai)),
            1e3,
            "p2pSupplyAmount"
        );
        assertApproxEqAbs(p2pBorrowAmount, 0, 1, "p2pBorrowAmount");
        move1000BlocksForward(cDai);
        for (uint256 i; i < 20; i++) {
            suppliers[i].withdraw(cDai, type(uint256).max);
        }
        for (uint256 i = 0; i < 20; i++) {
            (uint256 inP2P, uint256 onPool) = morpho.supplyBalanceInOf(cDai, address(suppliers[i]));
            assertEq(inP2P, 0, "inP2P");
            assertEq(onPool, 0, "onPool");
        }
    }
    function testFailRepayZero() public {
        morpho.repay(cDai, msg.sender, 0);
    }
    function testRepayRepayOnBehalf() public {
        uint256 amount = 1 ether;
        borrower1.approve(usdc, to6Decimals(2 * amount));
        borrower1.supply(cUsdc, to6Decimals(2 * amount));
        borrower1.borrow(cDai, amount);
        moveOneBlockForwardBorrowRepay();
        supplier2.approve(dai, cDai, amount);
        hevm.prank(address(supplier2));
        ICToken(cDai).repayBorrowBehalf(address(morpho), amount);
        hevm.stopPrank();
        borrower1.approve(dai, amount);
        borrower1.repay(cDai, amount);
    }
    function testRepayOnPoolThreshold() public {
        uint256 amountRepaid = 1e12;
        borrower1.approve(usdc, to6Decimals(2 ether));
        borrower1.supply(cUsdc, to6Decimals(2 ether));
        borrower1.borrow(cDai, 1 ether);
        uint256 onCompBeforeRepay = ICToken(cDai).borrowBalanceCurrent(address(morpho));
        (, uint256 onPoolBeforeRepay) = morpho.borrowBalanceInOf(cDai, address(borrower1));
        moveOneBlockForwardBorrowRepay();
        borrower1.approve(dai, amountRepaid);
        borrower1.repay(cDai, amountRepaid);
        uint256 onCompAfterRepay = ICToken(cDai).borrowBalanceCurrent(address(morpho));
        (, uint256 onPoolAfterRepay) = morpho.borrowBalanceInOf(cDai, address(borrower1));
        assertLt(onCompAfterRepay, onCompBeforeRepay, "on Comp");
        assertLt(onPoolAfterRepay, onPoolBeforeRepay, "on Morpho");
    }
    function testRepayOnBehalf() public {
        uint256 amount = 10_000 ether;
        uint256 collateral = 2 * amount;
        borrower1.approve(usdc, to6Decimals(collateral));
        borrower1.supply(cUsdc, to6Decimals(collateral));
        borrower1.borrow(cDai, amount);
        moveOneBlockForwardBorrowRepay();
        borrower2.approve(dai, amount);
        hevm.prank(address(borrower2));
        morpho.repay(cDai, address(borrower1), amount);
        (uint256 inP2P, uint256 onPool) = morpho.borrowBalanceInOf(cDai, address(borrower1));
        testEqualityLarge(inP2P, 0);
        testEqualityLarge(onPool, 0);
    }
    function testCannotBorrowRepayInSameBlock() public {
        uint256 amount = 10_000 ether;
        uint256 collateral = 2 * amount;
        borrower1.approve(usdc, to6Decimals(collateral));
        borrower1.supply(cUsdc, to6Decimals(collateral));
        borrower1.borrow(cDai, amount);
        borrower1.approve(dai, amount);
        hevm.prank(address(borrower1));
        hevm.expectRevert(abi.encodeWithSignature("SameBlockBorrowRepay()"));
        morpho.repay(cDai, address(borrower1), amount);
    }
    function testCannotBorrowRepayOnBehalfInSameBlock() public {
        uint256 amount = 10_000 ether;
        uint256 collateral = 2 * amount;
        borrower1.approve(usdc, to6Decimals(collateral));
        borrower1.supply(cUsdc, to6Decimals(collateral));
        borrower1.borrow(cDai, amount);
        borrower2.approve(dai, amount);
        hevm.prank(address(borrower2));
        hevm.expectRevert(abi.encodeWithSignature("SameBlockBorrowRepay()"));
        morpho.repay(cDai, address(borrower1), amount);
    }
    struct StackP2PVars {
        uint256 daiP2PSupplyIndexBefore;
        uint256 daiP2PBorrowIndexBefore;
        uint256 usdcP2PSupplyIndexBefore;
        uint256 usdcP2PBorrowIndexBefore;
        uint256 batP2PSupplyIndexBefore;
        uint256 batP2PBorrowIndexBefore;
        uint256 usdtP2PSupplyIndexBefore;
        uint256 usdtP2PBorrowIndexBefore;
    }
    struct StackPoolVars {
        uint256 daiPoolSupplyIndexBefore;
        uint256 daiPoolBorrowIndexBefore;
        uint256 usdcPoolSupplyIndexBefore;
        uint256 usdcPoolBorrowIndexBefore;
        uint256 batPoolSupplyIndexBefore;
        uint256 batPoolBorrowIndexBefore;
        uint256 usdtPoolSupplyIndexBefore;
        uint256 usdtPoolBorrowIndexBefore;
    }
    function testRepayUpdateIndexesSameAsCompound() public {
        uint256 collateral = 1 ether;
        uint256 borrow = collateral / 10;
        {
            supplier1.approve(dai, type(uint256).max);
            supplier1.approve(usdc, type(uint256).max);
            supplier1.approve(usdt, type(uint256).max);
            supplier1.supply(cDai, collateral);
            supplier1.supply(cUsdc, to6Decimals(collateral));
            supplier1.borrow(cBat, borrow);
            supplier1.borrow(cUsdt, to6Decimals(borrow));
            StackP2PVars memory vars;
            vars.daiP2PSupplyIndexBefore = morpho.p2pSupplyIndex(cDai);
            vars.daiP2PBorrowIndexBefore = morpho.p2pBorrowIndex(cDai);
            vars.usdcP2PSupplyIndexBefore = morpho.p2pSupplyIndex(cUsdc);
            vars.usdcP2PBorrowIndexBefore = morpho.p2pBorrowIndex(cUsdc);
            vars.batP2PSupplyIndexBefore = morpho.p2pSupplyIndex(cBat);
            vars.batP2PBorrowIndexBefore = morpho.p2pBorrowIndex(cBat);
            vars.usdtP2PSupplyIndexBefore = morpho.p2pSupplyIndex(cUsdt);
            vars.usdtP2PBorrowIndexBefore = morpho.p2pBorrowIndex(cUsdt);
            hevm.roll(block.number + 1);
            supplier1.repay(cUsdt, to6Decimals(borrow));
            uint256 daiP2PSupplyIndexAfter = morpho.p2pSupplyIndex(cDai);
            uint256 daiP2PBorrowIndexAfter = morpho.p2pBorrowIndex(cDai);
            uint256 usdcP2PSupplyIndexAfter = morpho.p2pSupplyIndex(cUsdc);
            uint256 usdcP2PBorrowIndexAfter = morpho.p2pBorrowIndex(cUsdc);
            uint256 batP2PSupplyIndexAfter = morpho.p2pSupplyIndex(cBat);
            uint256 batP2PBorrowIndexAfter = morpho.p2pBorrowIndex(cBat);
            uint256 usdtP2PSupplyIndexAfter = morpho.p2pSupplyIndex(cUsdt);
            uint256 usdtP2PBorrowIndexAfter = morpho.p2pBorrowIndex(cUsdt);
            assertEq(daiP2PBorrowIndexAfter, vars.daiP2PSupplyIndexBefore);
            assertEq(daiP2PSupplyIndexAfter, vars.daiP2PBorrowIndexBefore);
            assertEq(usdcP2PSupplyIndexAfter, vars.usdcP2PSupplyIndexBefore);
            assertEq(usdcP2PBorrowIndexAfter, vars.usdcP2PBorrowIndexBefore);
            assertEq(batP2PSupplyIndexAfter, vars.batP2PSupplyIndexBefore);
            assertEq(batP2PBorrowIndexAfter, vars.batP2PBorrowIndexBefore);
            assertGt(usdtP2PSupplyIndexAfter, vars.usdtP2PSupplyIndexBefore);
            assertGt(usdtP2PBorrowIndexAfter, vars.usdtP2PBorrowIndexBefore);
        }
        {
            supplier1.compoundSupply(cDai, collateral);
            supplier1.compoundSupply(cUsdc, to6Decimals(collateral));
            supplier1.compoundBorrow(cBat, borrow);
            supplier1.compoundBorrow(cUsdt, to6Decimals(borrow));
            StackPoolVars memory vars;
            vars.daiPoolSupplyIndexBefore = ICToken(cDai).exchangeRateStored();
            vars.daiPoolBorrowIndexBefore = ICToken(cDai).borrowIndex();
            vars.usdcPoolSupplyIndexBefore = ICToken(cUsdc).exchangeRateStored();
            vars.usdcPoolBorrowIndexBefore = ICToken(cUsdc).borrowIndex();
            vars.batPoolSupplyIndexBefore = ICToken(cBat).exchangeRateStored();
            vars.batPoolBorrowIndexBefore = ICToken(cBat).borrowIndex();
            vars.usdtPoolSupplyIndexBefore = ICToken(cUsdt).exchangeRateStored();
            vars.usdtPoolBorrowIndexBefore = ICToken(cUsdt).borrowIndex();
            hevm.roll(block.number + 1);
            supplier1.compoundRepay(cUsdt, 1);
            uint256 daiPoolSupplyIndexAfter = ICToken(cDai).exchangeRateStored();
            uint256 daiPoolBorrowIndexAfter = ICToken(cDai).borrowIndex();
            uint256 usdcPoolSupplyIndexAfter = ICToken(cUsdc).exchangeRateStored();
            uint256 usdcPoolBorrowIndexAfter = ICToken(cUsdc).borrowIndex();
            uint256 batPoolSupplyIndexAfter = ICToken(cBat).exchangeRateStored();
            uint256 batPoolBorrowIndexAfter = ICToken(cBat).borrowIndex();
            uint256 usdtPoolSupplyIndexAfter = ICToken(cUsdt).exchangeRateStored();
            uint256 usdtPoolBorrowIndexAfter = ICToken(cUsdt).borrowIndex();
            assertEq(daiPoolSupplyIndexAfter, vars.daiPoolSupplyIndexBefore);
            assertEq(daiPoolBorrowIndexAfter, vars.daiPoolBorrowIndexBefore);
            assertEq(usdcPoolSupplyIndexAfter, vars.usdcPoolSupplyIndexBefore);
            assertEq(usdcPoolBorrowIndexAfter, vars.usdcPoolBorrowIndexBefore);
            assertEq(batPoolSupplyIndexAfter, vars.batPoolSupplyIndexBefore);
            assertEq(batPoolBorrowIndexAfter, vars.batPoolBorrowIndexBefore);
            assertGt(usdtPoolSupplyIndexAfter, vars.usdtPoolSupplyIndexBefore);
            assertGt(usdtPoolBorrowIndexAfter, vars.usdtPoolBorrowIndexBefore);
        }
    }
}