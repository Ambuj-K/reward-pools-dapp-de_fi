// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @title Interface that should implement the ETHPool contract
/// The constructor should have the ERC20 token address as argument
interface IETHPool {
    /// @notice Event when a ETHPool is lauched
    /// @param id ETHPool's id based on a counter (starting from 1) 
    /// @param creator creator of the ETHPool (sender)
    /// @param startAt Starting date of the ETHPool
    /// @param endAt Ending date of the ETHPool    
    event LaunchETHPool(
        uint id,
        address indexed creator,
        uint32 startAt,
        uint32 endAt
    );

    /// @notice Event when a ETHPool is stopped
    /// @param id ETHPool's id    
    event StoppedETHPool(uint id);

    /// @notice Event when a user contributes to the ETHPool
    /// @param id ETHPool's id
    /// @param caller address of the contributor (sender)
    /// @param amount amount of the contribution  
    event Contribute(uint indexed id, address indexed caller, uint amount);

    /// @notice Event when a user withdraws an amount from his contribution to a ETHPool
    /// @param id ETHPool's id
    /// @param caller address of the withdrawer (sender)
    /// @param amount amount of the withdraw    
    event Withdraw(uint indexed id, address indexed caller, uint amount);

    /// @notice Event when a ETHPool is supplied by the creating team
    /// @param id ETHPool's id
    /// @param amount amount of the withdraw   
    event TeamRewardSupplied(uint indexed id, uint amount);

    /// @notice Event when a ETHPool is refunded
    /// @param id ETHPool's id
    /// @param caller tokens receiver (sender)
    /// @param amount amount of tokens (all the contribution)
    event RefundETHPool(uint id, address indexed caller, uint amount);    

    /// @notice Object representing a ETHPool that should be used
    struct ETHPool {
        // Creator address Team of ETHPool
        address creator;
        // Total amount in the pool
        uint pool_size;
        // Timestamp of start of ETHPool
        uint startAt;
        // Timestamp of end of ETHPool
        uint32 endAt;
        // Active or Ended
        bool active;
    }

    /// @notice Launch a new ETHPool. 
    /// @param _startAt Starting date of the ETHPool
    /// @param _endAt Ending date of the ETHPool
    function launchETHPool(
        uint32 _startAt,
        uint32 _endAt
    ) external;  

    /// @notice Stop a ETHPool
    /// @param _id ETHPool's id
    function stopETHPool(uint _id) external;

    /// @notice Contribute to the ETHPool for the given amount
    /// @param _id ETHPool's id
    /// @param _amount Amount of the contribution    
    function contribute(uint _id, uint _amount) external;

    /// @notice Withdraw an amount from your contribution
    /// @param _id ETHPool's id
    /// @param _amount Amount of the contribution to withdraw
    function withdraw(uint _id, uint _amount) external;

    /// @notice Claim all the tokens from the ETHPool
    /// @param _id ETHPool's id
    /// @param _amount Amount to be added by the creating team
    function addRewardETHPool(uint _id, uint _amount) external;

    /// @notice Refund all the tokens to the sender
    /// @param _id ETHPool's id
    function refundETHPool(uint _id) external;

    /// @notice Get the ETHPool info
    /// @param _id ETHPool's id
    function getETHPool(uint _id) view external returns (ETHPool memory ETHPool);

    /// @notice Get User Balance after reward disbursement
    /// @param _id EthPool's id
    function getUserBalance(uint _id) view external returns (uint _amount);
}