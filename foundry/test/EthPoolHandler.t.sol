// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../src/ETHPoolHandler.sol";
import "../src/PlatformToken.sol";

interface CheatCodes {
    function startPrank(address) external;
    function stopPrank() external;
    function expectEmit(bool, bool, bool, bool) external;
    function warp(uint256) external;
    function roll(uint256) external;
}

contract ETHPoolHandlerTest is DSTest {
    CheatCodes constant cheats = CheatCodes(HEVM_ADDRESS);

    ETHPoolHandler public ETHPoolHandlerObj;
    PlatformToken public token;

    function setUp() public {
        token =new PlatformToken();
        ETHPoolHandlerObj = new ETHPoolHandler(address(token));
    }

    function testCreateContributeWithdrawClaim() public {
        // create ETHPool via addr i.e. team
        address addr = 0x1234567890123456789012345678901234567890;
        token.transfer(address(addr), 1000 ether);
        emit log_uint(token.balanceOf(address(addr)));
        cheats.startPrank(address(addr));
        ETHPoolHandlerObj.launchETHPool(uint32(block.timestamp + 1 days), uint32(block.timestamp + 91 days));
        cheats.stopPrank();


        // use 2nd address to contribute, person A
        address addr1 = 0x1234567890123456789012345678901234567892;
        token.transfer(address(addr1), 1000 ether);
        emit log_uint(token.balanceOf(address(addr1)));
        cheats.startPrank(address(addr1));
        // approval from 2nd acc for contract transfer
        token.approve(address(ETHPoolHandlerObj), 20 ether);
        // addr 1 contribute to ETHPool
        ETHPoolHandlerObj.contribute(0, 20 ether);
        cheats.stopPrank();
        emit log_uint(token.balanceOf(address(addr1)));
        assertEq(token.balanceOf(address(addr1)), 980 ether);

        // team adds weeekly reward 100
        cheats.startPrank(address(addr));
        ETHPoolHandlerObj.addRewardETHPool(0,100 ether);
        // ETHPoolHandlerObj.stopETHPool(0);
        cheats.stopPrank();

        // use 3rd address to contributem person B
        address addr2 = 0x1234567890123456789012345678901234567893;
        token.transfer(address(addr2), 1000 ether);
        emit log_uint(token.balanceOf(address(addr2)));
        cheats.startPrank(address(addr2));
        // approval from 3rd acc for contract transfer
        token.approve(address(ETHPoolHandlerObj), 80 ether);
        // addr 2 contribute to ETHPool 20
        ETHPoolHandlerObj.contribute(0, 80 ether);
        cheats.stopPrank();
        assertEq(token.balanceOf(address(addr2)), 920 ether);

        // check balance of addr 1 => 20 added + 100 % of 100 = 120
        cheats.startPrank(address(addr1));
        // withdraw 10 ether from ETHPool via addr1
        emit log_uint(ETHPoolHandlerObj.getUserBalance(0));
        assertEq(ETHPoolHandlerObj.getUserBalance(0), 120 ether);
        // ETHPoolHandlerObj.withdraw(0, 10 ether);
        cheats.stopPrank();

        // team adds weeekly reward 100 again
        cheats.startPrank(address(addr));
        ETHPoolHandlerObj.addRewardETHPool(0,100 ether);
        // ETHPoolHandlerObj.stopETHPool(0);
        cheats.stopPrank();

        // check the balalce of addr 2
        // 80 added + 80/200(200 pool balance pre reward) * 100 = 120
        cheats.startPrank(address(addr2));
        // withdraw 10 ether from ETHPool via addr1
        emit log_uint(ETHPoolHandlerObj.getUserBalance(0));
        assertEq(ETHPoolHandlerObj.getUserBalance(0), 120 ether);
        // ETHPoolHandlerObj.withdraw(0, 10 ether);
        cheats.stopPrank();

        assertEq(token.balanceOf(address(addr1)), 980 ether);
        assertEq(ETHPoolHandlerObj.getETHPool(0).creator,addr);
        // check ETHPool balance to 30
        assertEq(ETHPoolHandlerObj.getETHPool(0).pool_size,300 ether);
        cheats.warp(92 days);
        // check balance of user addr, creator of ETHPool
        assertEq(token.balanceOf(address(addr)), 1000 ether);
    }

    // create ETHPool
    // function testLaunchETHPool() public {
    //     address addr = 0x1234567890123456789012345678901234567890;
    //     token.transfer(address(addr), 1000 ether);
    //     emit log_uint(token.balanceOf(address(addr)));
    //     cheats.startPrank(address(addr));
    //     ETHPoolHandlerObj.launchETHPool(uint32(block.timestamp + 1 days), uint32(block.timestamp + 91 days));
    //     cheats.stopPrank();
    //     emit log_address(ETHPoolHandlerObj.getETHPool(0).creator);
    //     assertEq(ETHPoolHandlerObj.getETHPool(0).creator,addr);
    // }

}
