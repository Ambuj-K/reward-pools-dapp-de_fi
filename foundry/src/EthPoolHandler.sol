// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IEthPool.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

// Feature: allows teams to create multiple time bound pools separately
// contribution/deposit terms used interchangeably

contract ETHPoolHandler is IETHPool, Ownable, ReentrancyGuard{

    IERC20 public s_ETHPoolToken;

    // Counter for token id counter
    using Counters for Counters.Counter;  
    Counters.Counter internal s_ETHPoolCounter;

    mapping (uint256 => ETHPool) internal s_ETHPoolIDToETHPoolObject;
    mapping (address => mapping(uint256 => uint256)) internal s_userAddressToContribution;
    // todo: if possible find better gas/storage usage paradigm
    mapping (uint256 => address[]) internal s_ETHPoolIDToContributorAddrList;
    mapping (uint256 => mapping(address => uint256)) internal s_ETHPoolIDToContributionAddrPercentage;

    enum updateAmountType{ DEPOSIT,WITHDRAWAL,REWARD }

    // "require" string is gas expensive, so custom descriptive errors
    // launchETHPool errors
    error ETHPool_StartAtLesserThanToday();
    error ETHPool_StartDateGreaterThanEnd();
    error ETHPool_RequestedETHPoolLesserThan90days();

    // cancel ETHPool errors
    error ETHPool_CancelETHPoolTimingError();

    // contribute/withdraw errors
    error ETHPool_NotActiveAnymore();
    error ETHPool_OutOfETHPoolStartAndEndTime();
    error ETHPool_AmtWithdrawnGreaterThanContribution();
    error ETHPool__TokenTransferToContractFailed();
    error ETHPool__TokenTransferToUserFailed();

    // add reward ETHPool errors
    error ETHPool_NonCreatorTeamAddRewardAttempt();

    // refund ETHPool errors
    error ETHPool__RefundToUserFailed();
    error ETHPool_NoContributionToRefund();
    error ETHPool_StillActive();

    constructor(address _ETHPoolToken){
        s_ETHPoolToken = IERC20(_ETHPoolToken);
    }

    /// @notice Launch a new ETHPool. 
    /// @param _startAt Starting date of the ETHPool
    /// @param _endAt Ending date of the ETHPool
    function launchETHPool(
        uint32 _startAt,
        uint32 _endAt
    ) external {
        if( _startAt<uint32(block.timestamp + 1 days)){
            revert ETHPool_StartAtLesserThanToday();
        }

        if ( _startAt > _endAt){
            revert ETHPool_StartDateGreaterThanEnd();
        }
        // min pool duration 90 days
        if ( _endAt - _startAt<uint32(90 days)){
            revert ETHPool_RequestedETHPoolLesserThan90days();
        }

        ETHPool memory s_ETHPoolObj = ETHPool(
            msg.sender,
            0,
            _startAt,
            _endAt,
            true
        );

        uint256 ETHPoolId = s_ETHPoolCounter.current();
        s_ETHPoolCounter.increment();
        s_ETHPoolIDToETHPoolObject[ETHPoolId] = s_ETHPoolObj;

        // emit LaunchETHPool event
        emit LaunchETHPool(
        ETHPoolId,
        msg.sender,
        _startAt,
        _endAt);
    }

    /// @notice stop a ETHPool
    /// @param _id ETHPool's id
    function stopETHPool(uint _id) external{
        if (msg.sender != s_ETHPoolIDToETHPoolObject[_id].creator){
            revert ETHPool_NonCreatorTeamAddRewardAttempt();
        }
        if (s_ETHPoolIDToETHPoolObject[_id].startAt<block.timestamp && s_ETHPoolIDToETHPoolObject[_id].endAt>block.timestamp){
            revert ETHPool_CancelETHPoolTimingError();
        }
        // all values in ETHPool struct 0
        s_ETHPoolIDToETHPoolObject[_id].active = false;
        emit StoppedETHPool(_id);
    }

    /// @notice Contribute to the ETHPool for the given amount
    /// @param _id ETHPool's id
    /// @param _amount Amount of the contribution    
    function contribute(uint _id, uint _amount) external nonReentrant {
        if (!s_ETHPoolIDToETHPoolObject[_id].active){
            revert ETHPool_NotActiveAnymore();
        }
        if (s_ETHPoolIDToETHPoolObject[_id].startAt<=block.timestamp && block.timestamp<=s_ETHPoolIDToETHPoolObject[_id].endAt){
            revert ETHPool_OutOfETHPoolStartAndEndTime();
        }
        // in the frontend tokencontract function approve by user acct
        bool success = s_ETHPoolToken.transferFrom(msg.sender, address(this), _amount);
        if (!success){
            revert ETHPool__TokenTransferToContractFailed();
        }
        s_ETHPoolIDToContributorAddrList[_id].push(msg.sender);
        s_ETHPoolIDToETHPoolObject[_id].pool_size = s_ETHPoolIDToETHPoolObject[_id].pool_size + _amount;
        s_userAddressToContribution[msg.sender][_id] = s_userAddressToContribution[msg.sender][_id] + _amount;
        updatePercentageContributions(_id, _amount, false);
        emit Contribute(_id, msg.sender, _amount);
    }

    /// @notice Withdraw an amount from your contribution
    /// @param _id ETHPool's id
    /// @param _amount Amount of the contribution to withdraw
    function withdraw(uint _id, uint _amount) external nonReentrant {
        if (!s_ETHPoolIDToETHPoolObject[_id].active){
            revert ETHPool_NotActiveAnymore();
        }
        if (s_ETHPoolIDToETHPoolObject[_id].startAt<=block.timestamp && block.timestamp<=s_ETHPoolIDToETHPoolObject[_id].endAt){
            revert ETHPool_OutOfETHPoolStartAndEndTime();
        }
        //checks if user eligible to withdraw the amount or even exists in the mapping
        if (s_userAddressToContribution[msg.sender][_id] < _amount){
            revert ETHPool_AmtWithdrawnGreaterThanContribution();
        }
        bool success = s_ETHPoolToken.transfer(msg.sender, _amount);
        if (!success){
            revert ETHPool__TokenTransferToUserFailed();
        }
        s_ETHPoolIDToETHPoolObject[_id].pool_size = s_ETHPoolIDToETHPoolObject[_id].pool_size - _amount;
        s_userAddressToContribution[msg.sender][_id] = s_userAddressToContribution[msg.sender][_id] - _amount;
        updatePercentageContributions(_id, _amount, false);
        emit Withdraw(_id, msg.sender, _amount);
    }

    /// @notice Claim all the tokens from the ETHPool
    /// @param _id ETHPool's id
    function addRewardETHPool(uint _id, uint _amount) external nonReentrant {
        if (!s_ETHPoolIDToETHPoolObject[_id].active){
            revert ETHPool_NotActiveAnymore();
        }
        if (msg.sender != s_ETHPoolIDToETHPoolObject[_id].creator){
            revert ETHPool_NonCreatorTeamAddRewardAttempt();
        }
        // ETH Pool existing check errors
        s_ETHPoolIDToETHPoolObject[_id].pool_size = s_ETHPoolIDToETHPoolObject[_id].pool_size + _amount;
        // msg.sender use redundant in case of rewards
        updatePercentageContributions(_id, _amount, true);
        emit TeamRewardSupplied(_id, _amount);
    }

    /// @notice Refund all the tokens to the sender
    /// @param _id ETHPool's id
    function refundETHPool(uint _id) external nonReentrant {
        // creating team needs to close/end the pool for refunds in case offer suspended
        if (s_ETHPoolIDToETHPoolObject[_id].active){
            revert ETHPool_StillActive();
        }
        uint256 amtRefund = s_userAddressToContribution[msg.sender][_id];
        if (s_userAddressToContribution[msg.sender][_id] == 0){
            revert ETHPool_NoContributionToRefund();
        }
        bool success = s_ETHPoolToken.transfer(msg.sender,amtRefund);
        if (!success){
            revert ETHPool__RefundToUserFailed();
        }
        s_ETHPoolIDToETHPoolObject[_id].pool_size = s_ETHPoolIDToETHPoolObject[_id].pool_size - amtRefund;
        emit RefundETHPool(_id, msg.sender, amtRefund); 
    }
    
    /// @notice update contribution & percentage per user, deposits/withdrawals/rewards 
    /// @param _id EthPool's id
    /// @param _amount amount of deposits/withdrawals/rewards 
    /// @param _isReward amount is reward or otherwise
    function updatePercentageContributions(uint _id, uint _amount, bool _isReward) internal {
        if (_isReward){
            // in case its a reward
            for (uint i=0; i<s_ETHPoolIDToContributorAddrList[_id].length; i++) {
                // userAddress variable to update percentage wise reward to each user's pooled contribution
                address userAddress = s_ETHPoolIDToContributorAddrList[_id][i];
                s_userAddressToContribution[userAddress][_id] = s_userAddressToContribution[userAddress][_id]+
                s_ETHPoolIDToContributionAddrPercentage[_id][userAddress]*_amount/100;
            }
        }
        else {
            // incase of contribution/withdrawal
            
            for (uint i=0; i<s_ETHPoolIDToContributorAddrList[_id].length; i++) {
                // userAddress variable to update percentage contribution of each user
                address userAddress = s_ETHPoolIDToContributorAddrList[_id][i];
                s_ETHPoolIDToContributionAddrPercentage[_id][userAddress] = s_userAddressToContribution[userAddress][_id]*100/s_ETHPoolIDToETHPoolObject[_id].pool_size;
            }
        }
    }

    /// @notice Get the ETHPool info
    /// @param _id ETHPool's id
    function getETHPool(uint _id) view external returns (ETHPool memory ethPool) {
        return s_ETHPoolIDToETHPoolObject[_id];
    }

    /// @notice Get User Balance after reward disbursement
    /// @param _id EthPool's id
    function getUserBalance(uint _id) view external returns (uint _amount) {
        return s_userAddressToContribution[msg.sender][_id];
    }

}