// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PredictMarket.sol";

contract PredictMarketTest is Test {
    PredictMarket pm;
    address admin = makeAddr("admin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    function setUp() public {
        vm.prank(admin);
        pm = new PredictMarket();
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }

    function _createMarket() internal returns (uint256) {
        vm.prank(alice);
        return pm.createMarket("Will ETH > $10k by 2026?", block.timestamp + 1 days, address(0));
    }

    function test_createMarket() public {
        uint256 id = _createMarket();
        (string memory q, address creator,,) = pm.getMarketMeta(id);
        assertEq(q, "Will ETH > $10k by 2026?");
        assertEq(creator, alice);
        (,,,,bool resolved,) = pm.getMarketPools(id);
        assertFalse(resolved);
    }

    function test_placeBets() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        pm.placeBet{value: 1 ether}(id, true);
        vm.prank(charlie);
        pm.placeBet{value: 2 ether}(id, false);

        (uint256 yesPool, uint256 noPool, uint256 total,,,) = pm.getMarketPools(id);
        assertEq(yesPool, 1 ether);
        assertEq(noPool, 2 ether);
        assertEq(total, 3 ether);
    }

    function test_getOdds() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        pm.placeBet{value: 1 ether}(id, true);
        vm.prank(charlie);
        pm.placeBet{value: 3 ether}(id, false);

        (uint256 yesBps, uint256 noBps) = pm.getOdds(id);
        assertEq(yesBps, 2500);
        assertEq(noBps, 7500);
    }

    function test_resolveAndClaimYes() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        pm.placeBet{value: 1 ether}(id, true);
        vm.prank(charlie);
        pm.placeBet{value: 2 ether}(id, false);

        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        pm.resolveMarket(id, PredictMarket.Outcome.Yes);

        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        pm.claimWinnings(id);
        assertEq(bob.balance - bobBefore, 2.94 ether);
    }

    function test_resolveAndClaimNo() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        pm.placeBet{value: 3 ether}(id, true);
        vm.prank(charlie);
        pm.placeBet{value: 1 ether}(id, false);

        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        pm.resolveMarket(id, PredictMarket.Outcome.No);

        uint256 charlieBefore = charlie.balance;
        vm.prank(charlie);
        pm.claimWinnings(id);
        assertEq(charlie.balance - charlieBefore, 3.92 ether);
    }

    function test_invalidRefund() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        pm.placeBet{value: 2 ether}(id, true);
        vm.prank(charlie);
        pm.placeBet{value: 3 ether}(id, false);

        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        pm.resolveMarket(id, PredictMarket.Outcome.Invalid);

        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        pm.claimWinnings(id);
        assertEq(bob.balance - bobBefore, 2 ether);

        uint256 charlieBefore = charlie.balance;
        vm.prank(charlie);
        pm.claimWinnings(id);
        assertEq(charlie.balance - charlieBefore, 3 ether);
    }

    function test_cannotBetAfterDeadline() public {
        uint256 id = _createMarket();
        vm.warp(block.timestamp + 2 days);
        vm.prank(bob);
        vm.expectRevert("betting closed");
        pm.placeBet{value: 1 ether}(id, true);
    }

    function test_cannotResolveBeforeDeadline() public {
        uint256 id = _createMarket();
        vm.prank(alice);
        vm.expectRevert("deadline not passed");
        pm.resolveMarket(id, PredictMarket.Outcome.Yes);
    }

    function test_cannotDoubleResolve() public {
        uint256 id = _createMarket();
        vm.warp(block.timestamp + 2 days);
        vm.startPrank(alice);
        pm.resolveMarket(id, PredictMarket.Outcome.Yes);
        vm.expectRevert("already resolved");
        pm.resolveMarket(id, PredictMarket.Outcome.No);
        vm.stopPrank();
    }

    function test_cannotDoubleClaim() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        pm.placeBet{value: 1 ether}(id, true);
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        pm.resolveMarket(id, PredictMarket.Outcome.Yes);
        vm.startPrank(bob);
        pm.claimWinnings(id);
        vm.expectRevert("already claimed");
        pm.claimWinnings(id);
        vm.stopPrank();
    }

    function test_multipleBettors() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        pm.placeBet{value: 2 ether}(id, true);
        vm.prank(charlie);
        pm.placeBet{value: 1 ether}(id, true);
        vm.prank(alice);
        pm.placeBet{value: 3 ether}(id, false);

        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        pm.resolveMarket(id, PredictMarket.Outcome.Yes);

        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        pm.claimWinnings(id);
        assertEq(bob.balance - bobBefore, 3.92 ether);

        uint256 charlieBefore = charlie.balance;
        vm.prank(charlie);
        pm.claimWinnings(id);
        assertEq(charlie.balance - charlieBefore, 1.96 ether);
    }

    function test_userMarketTracking() public {
        uint256 id1 = _createMarket();
        vm.prank(alice);
        uint256 id2 = pm.createMarket("Market 2?", block.timestamp + 1 days, address(0));
        vm.startPrank(bob);
        pm.placeBet{value: 1 ether}(id1, true);
        pm.placeBet{value: 1 ether}(id2, false);
        vm.stopPrank();

        uint256[] memory bobMarkets = pm.getUserMarkets(bob);
        assertEq(bobMarkets.length, 2);
    }

    function test_withdrawFees() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        pm.placeBet{value: 5 ether}(id, true);
        vm.prank(charlie);
        pm.placeBet{value: 5 ether}(id, false);

        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        pm.resolveMarket(id, PredictMarket.Outcome.Yes);

        // 2% of 10 ETH = 0.2 ETH
        uint256 adminBefore = admin.balance;
        vm.prank(admin);
        pm.withdrawFees(admin);
        assertEq(admin.balance - adminBefore, 0.2 ether);
    }

    function test_setDefaultFee() public {
        vm.prank(admin);
        pm.setDefaultFee(500); // 5%
        assertEq(pm.defaultFee(), 500);
    }

    function test_setDefaultFeeMaxLimit() public {
        vm.prank(admin);
        vm.expectRevert("max 10%");
        pm.setDefaultFee(1001);
    }

    function test_onlyOwnerWithdrawFees() public {
        vm.prank(bob);
        vm.expectRevert("not owner");
        pm.withdrawFees(bob);
    }

    function test_onlyOwnerSetFee() public {
        vm.prank(bob);
        vm.expectRevert("not owner");
        pm.setDefaultFee(500);
    }

    function test_getCreatedMarkets() public {
        vm.startPrank(alice);
        pm.createMarket("Q1?", block.timestamp + 1 days, address(0));
        pm.createMarket("Q2?", block.timestamp + 1 days, address(0));
        vm.stopPrank();

        uint256[] memory ids = pm.getCreatedMarkets(alice);
        assertEq(ids.length, 2);
    }

    function test_calculatePayout() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        pm.placeBet{value: 1 ether}(id, true);
        vm.prank(charlie);
        pm.placeBet{value: 1 ether}(id, false);

        // If I bet 1 ETH YES: total=3, yesPool=2, payout = 1 * (3 - 3*200/10000) / 2 = 1 * 2.94 / 2 = 1.47
        uint256 payout = pm.calculatePayout(id, true, 1 ether);
        assertEq(payout, 1.47 ether);
    }

    function test_cannotResolveUnresolved() public {
        uint256 id = _createMarket();
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        vm.expectRevert("invalid outcome");
        pm.resolveMarket(id, PredictMarket.Outcome.Unresolved);
    }

    function test_onlyResolverCanResolve() public {
        uint256 id = _createMarket();
        vm.warp(block.timestamp + 2 days);
        vm.prank(bob);
        vm.expectRevert("not resolver");
        pm.resolveMarket(id, PredictMarket.Outcome.Yes);
    }

    function test_cannotBetOnResolved() public {
        uint256 id = _createMarket();
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        pm.resolveMarket(id, PredictMarket.Outcome.Yes);

        vm.prank(bob);
        vm.expectRevert("market resolved");
        pm.placeBet{value: 1 ether}(id, true);
    }

    function test_cannotClaimBeforeResolution() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        pm.placeBet{value: 1 ether}(id, true);

        vm.prank(bob);
        vm.expectRevert("not resolved");
        pm.claimWinnings(id);
    }

    function test_loserCannotClaim() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        pm.placeBet{value: 1 ether}(id, true);
        vm.prank(charlie);
        pm.placeBet{value: 1 ether}(id, false);

        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        pm.resolveMarket(id, PredictMarket.Outcome.No);

        vm.prank(bob);
        vm.expectRevert("nothing to claim");
        pm.claimWinnings(id);
    }

    function test_emptyQuestion() public {
        vm.prank(alice);
        vm.expectRevert("empty question");
        pm.createMarket("", block.timestamp + 1 days, address(0));
    }

    function test_pastDeadline() public {
        vm.prank(alice);
        vm.expectRevert("deadline must be future");
        pm.createMarket("Q?", block.timestamp - 1, address(0));
    }

    function test_zeroBet() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        vm.expectRevert("must send ETH");
        pm.placeBet{value: 0}(id, true);
    }

    function test_customResolver() public {
        address oracle = makeAddr("oracle");
        vm.prank(alice);
        uint256 id = pm.createMarket("Q?", block.timestamp + 1 days, oracle);

        vm.warp(block.timestamp + 2 days);
        // Alice (creator) cannot resolve
        vm.prank(alice);
        vm.expectRevert("not resolver");
        pm.resolveMarket(id, PredictMarket.Outcome.Yes);

        // Oracle can
        vm.prank(oracle);
        pm.resolveMarket(id, PredictMarket.Outcome.Yes);
        (,,,, bool resolved,) = pm.getMarketPools(id);
        assertTrue(resolved);
    }

    function test_noFeesToWithdraw() public {
        vm.prank(admin);
        vm.expectRevert("no fees");
        pm.withdrawFees(admin);
    }

    function test_defaultOdds() public {
        uint256 id = _createMarket();
        (uint256 y, uint256 n) = pm.getOdds(id);
        assertEq(y, 5000);
        assertEq(n, 5000);
    }

    function test_getUserPosition() public {
        uint256 id = _createMarket();
        vm.prank(bob);
        pm.placeBet{value: 2 ether}(id, true);
        vm.prank(bob);
        pm.placeBet{value: 1 ether}(id, false);

        (uint256 yA, uint256 nA, bool claimed) = pm.getUserPosition(id, bob);
        assertEq(yA, 2 ether);
        assertEq(nA, 1 ether);
        assertFalse(claimed);
    }
}
