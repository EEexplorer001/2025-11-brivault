// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;
// @audit-info using floating pragma

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";


contract BriVault is ERC4626, Ownable {

    using SafeERC20 for IERC20;
    
    // @audit-info should be immutable
    uint256 public participationFeeBsp;

    uint256 constant BASE = 10000;
    uint256 constant PARTICIPATIONFEEBSPMAX = 300; 
    /**
    @dev participationFee address
     */
    // @audit-info should be immutable
    address private participationFeeAddress;

    // @audit-info should be immutable
    uint256 public eventStartDate;

    // @audit-info should be immutable
    uint256 public eventEndDate;

    // @audit-info stakedAmount not used
    uint256 public  stakedAmount;

    // @audit-info totalAssetsShares not used
    uint256 public totalAssetsShares;

    string public winner;

    uint256 public finalizedVaultAsset;

    uint256 public totalWinnerShares;

    uint256 public totalParticipantShares;

    // @audit-info looks like a private but actually public.
    bool public _setWinner;

    uint256 public winnerCountryId;


    // minimum amount to join in.
    // @audit-info should be immutable
    uint256 public  minimumAmount; 

    // number of participants 
    uint256 public numberOfParticipants;

    // Array of teams 
    string[48] public teams;
    address[] public usersAddress;

    // Error Logs
    error eventStarted();
    error lowFeeAndAmount();
    error invalidCountry();
    error eventNotEnded();
    error didNotWin();
    error notRegistered();
    error winnerNotSet();
    error noDeposit();
    error eventNotStarted();
    error WinnerAlreadySet();
    error limiteExceede();

    event deposited (address indexed _depositor, uint256 _value);
    event CountriesSet(string[48] country);
    event WinnerSet (string winnerSet);
    event joinedEvent (address user, uint256 _countryId);
    event Withdraw (address user, uint256 _amount);  

    mapping (address => uint256) public stakedAsset;
    mapping (address => string) public userToCountry;
    mapping(address => mapping(uint256 => uint256)) public userSharesToCountry;
    

    constructor (IERC20 _asset, uint256 _participationFeeBsp, uint256 _eventStartDate, address _participationFeeAddress, uint256 _minimumAmount, uint256 _eventEndDate) ERC4626 (_asset) ERC20("BriTechLabs", "BTT") Ownable(msg.sender) {
         if (_participationFeeBsp > PARTICIPATIONFEEBSPMAX){
            revert limiteExceede();
         }
         // @audit should check _eventEndDate > _eventStartDate
         // @audit should check _eventStartDate > block.timestamp, otherwise event already started, no one can join
         // @audit should check _participationFeeAddress not zero address
         // @audit should check if _minimumAmount is too high so no one can join or even overflow
         
         participationFeeBsp = _participationFeeBsp;
         eventStartDate = _eventStartDate;
         eventEndDate = _eventEndDate;
         participationFeeAddress = _participationFeeAddress;
         minimumAmount = _minimumAmount;
         _setWinner = false;
    }

    modifier winnerSet () {
        if (_setWinner != true) {
          revert winnerNotSet();
        }
        _;
    }

    /**----------------------------- Admin Functions ----------------------------------- */

    /**
        @notice sets the countries for the tournament
     */
 function setCountry(string[48] memory countries) public onlyOwner {

    // q: what if some 0s in the array?
    // q: should we check if countries have already been set?
    // @audit-info this function can be called multiple times to overwrite previous countries
    // @audit what if some countries are empty strings?

    for (uint256 i = 0; i < countries.length; ++i) {
        teams[i] = countries[i];
    }
    emit CountriesSet(countries);
}

    /**
        @notice sets the winner at the end of the tournament 
     */
    function setWinner(uint256 countryIndex) public onlyOwner returns (string memory) {
        if (block.timestamp <= eventEndDate) {
            revert eventNotEnded();
        }

        require(countryIndex < teams.length, "Invalid country index");

        if (_setWinner) {
            revert WinnerAlreadySet();
        }

        // @audit no check for non-empty country name
        winnerCountryId = countryIndex;
        winner = teams[countryIndex];

        _setWinner = true;

        _getWinnerShares();

        _setFinallizedVaultBalance();

        emit WinnerSet (winner);
        
        return winner;

    }

    /**
     * @notice sets the finalized vault balance
     */
    function _setFinallizedVaultBalance () internal returns (uint256) {
        // @audit-info no need to check since setWinner can only be called after eventEndDate
        if (block.timestamp <= eventStartDate) {
            revert eventNotStarted();
        }

        return finalizedVaultAsset = IERC20(asset()).balanceOf(address(this));
    }

    /**
        @notice calculates the shares
     */
    function _convertToShares(uint256 assets) internal view returns (uint256 shares) {
        uint256 balanceOfVault = IERC20(asset()).balanceOf(address(this));
        uint256 totalShares = totalSupply(); // total minted BTT shares so far
        
        // q: What if balanceOfVault is 0 but totalShares is not 0?
        if (totalShares == 0 || balanceOfVault == 0) {
            // First depositor: 1:1 ratio
            return assets;
        }

        // q: how to deal with rounding errors?
        shares = Math.mulDiv(assets, totalShares, balanceOfVault);
    }


    /**
    @notice get the winner
     */
    function getWinner () public view returns (string memory) {
        return winner;
    }


    /**
        @notice get country 
     */
    // @audit-info getCountry not used anywhere
    function getCountry(uint256 countryId) external view returns (string memory) {
         if (bytes(teams[countryId]).length == 0) {
            revert invalidCountry();
        }

        return teams[countryId];
    }

    /**
        @notice get winnerShares
     */
    function _getWinnerShares () internal returns (uint256) {
        // @audit no reset. owner can call setWinner multiple times to multiply totalWinnerShares so that prize will be diluted.
        for (uint256 i = 0; i < usersAddress.length; ++i){
            address user = usersAddress[i]; 
           totalWinnerShares += userSharesToCountry[user][winnerCountryId];
        }
        return totalWinnerShares;
    }

    function _getParticipationFee(uint256 assets) internal view returns (uint256) {
        return (assets * participationFeeBsp) / BASE;
    }

    /** 
        @dev allows users to deposit for the event.
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256) {

        // @audit Attackers can deposit on behalf of receiver without their consent, and keep shares for themselves. 
        require(receiver != address(0));

        if (block.timestamp >= eventStartDate) {
            revert eventStarted();
        }

        uint256 fee = _getParticipationFee(assets);
        // charge on a percentage basis points

        if (minimumAmount + fee > assets) {
            revert lowFeeAndAmount();
        }

        uint256 stakeAsset = assets - fee;

        // @audit no increment staking for existing user. 
        stakedAsset[receiver] = stakeAsset;

        uint256 participantShares = _convertToShares(stakeAsset);


        IERC20(asset()).safeTransferFrom(msg.sender, participationFeeAddress, fee);

        IERC20(asset()).safeTransferFrom(msg.sender, address(this), stakeAsset);

        _mint(msg.sender, participantShares);


        emit deposited (receiver, stakeAsset);

        return participantShares;
    }

    /**
        @dev allows users to join the event 
    */
    function joinEvent(uint256 countryId) public {

        // @audit single attacker can join multiple times to manipulate numberOfParticipants and userSharesToCountry
        // @audit no upbound check for numberOfParticipants, attacker can overflow it (DoS)
        // @audit no check for duplicate players.

        if (stakedAsset[msg.sender] == 0) {
            revert noDeposit();
        }

        // Ensure countryId is a valid index in the `teams` array
        if (countryId >= teams.length) {
            revert invalidCountry();
        }

        if (block.timestamp > eventStartDate) {
            revert eventStarted();
        }

        
        userToCountry[msg.sender] = teams[countryId];

        
        uint256 participantShares = balanceOf(msg.sender);
        userSharesToCountry[msg.sender][countryId] = participantShares;

        usersAddress.push(msg.sender);

        numberOfParticipants++;
        totalParticipantShares += participantShares;

        emit joinedEvent(msg.sender, countryId);
    }


    /**
        @dev cancel participation
     */
    function cancelParticipation () public  {
        // q: should we check if the user has joined the event?
        if (block.timestamp >= eventStartDate){
           revert eventStarted();
        }

        uint256 refundAmount = stakedAsset[msg.sender];
        // check staked amount is 0 or not
        // q: do not reset userToCountry mapping?
        // q: do not reset userSharesToCountry mapping?
        // q: do not remove from usersAddress array?
        // q: do not decrease numberOfParticipants or totalParticipantShares?
        // @audit Do not reset these variables. Attacker can exploit this (DoS)

        stakedAsset[msg.sender] = 0;

         uint256 shares = balanceOf(msg.sender);
        
        _burn(msg.sender, shares);

        IERC20(asset()).safeTransfer(msg.sender, refundAmount);
        // @audit-info Missing emit event
    }

        /**
            @dev allows users to withdraw. 
        */
    function withdraw() external winnerSet {
        if (block.timestamp < eventEndDate) {
            revert eventNotEnded();
        }

        // @audit should check countryId instead of country name.
        if (
            keccak256(abi.encodePacked(userToCountry[msg.sender])) !=
            keccak256(abi.encodePacked(winner))
        ) {
            revert didNotWin();
        }
        // @audit no check if winner is an empty string. Attacker can set empty string as country and win. Attackers can even directly go withdraw if eventEndDate has passed but winner not set yet.
        // @audit attacker can aggregate shares from losers and increase their winning share.
        uint256 shares = balanceOf(msg.sender);

        uint256 vaultAsset = finalizedVaultAsset;
        // @audit no check if totalWinnerShares is zero, division by zero possible
        uint256 assetToWithdraw = Math.mulDiv(shares, vaultAsset, totalWinnerShares);
        
        _burn(msg.sender, shares);

        IERC20(asset()).safeTransfer(msg.sender, assetToWithdraw);

        emit Withdraw(msg.sender, assetToWithdraw);
    }


}
