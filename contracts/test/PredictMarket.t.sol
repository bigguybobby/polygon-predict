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
}
