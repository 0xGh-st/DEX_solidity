// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Dex {
    ERC20 public tokenX;
    ERC20 public tokenY;

    uint256 public totalSupply;
    uint256 public reserveX;
    uint256 public reserveY;

    mapping(address => uint256) public balanceOf;

    constructor(address _tokenX, address _tokenY) {
        tokenX = ERC20(_tokenX);
        tokenY = ERC20(_tokenY);
    }

    function addLiquidity(uint256 amountX, uint256 amountY, uint256 minLiquidity) external returns (uint256) {
        require(amountX > 0 && amountY > 0, "Dex: Invalid initialization");
        require(tokenX.allowance(msg.sender, address(this)) >= amountX && tokenY.allowance(msg.sender, address(this)) >= amountY, "ERC20: insufficient allowance");
        require(tokenX.balanceOf(msg.sender) >= amountX && tokenY.balanceOf(msg.sender) >= amountY, "ERC20: transfer amount exceeds balance");

        uint256 liquidity;
        if (totalSupply == 0) {
            // Initial liquidity provision
            reserveX = amountX;
            reserveY = amountY;
            liquidity = sqrt(amountX * amountY);
            require(liquidity >= minLiquidity, "Dex: Insufficient liquidity");
            totalSupply = liquidity;
            balanceOf[msg.sender] = liquidity;
        } else {
            // Determine optimal amounts of tokenX and tokenY to add based on pool's ratio
            uint256 optimalAmountY = (amountX * reserveY) / reserveX;
            uint256 optimalAmountX = (amountY * reserveX) / reserveY;

            if (amountY > optimalAmountY) {
                // Too much Y provided, adjust amountY to optimal amount
                amountY = optimalAmountY;
            } else {
                // Too much X provided, adjust amountX to optimal amount
                amountX = optimalAmountX;
            }

            // Calculate the liquidity to mint
            liquidity = (amountX * totalSupply) / reserveX;

            require(liquidity > 0 && liquidity >= minLiquidity, "Dex: Insufficient liquidity");

            // Update reserves and total supply
            reserveX += amountX;
            reserveY += amountY;
            totalSupply += liquidity;
            balanceOf[msg.sender] += liquidity;
        }

        // Perform transfers
        require(tokenX.transferFrom(msg.sender, address(this), amountX), "Dex: transfer failed");
        require(tokenY.transferFrom(msg.sender, address(this), amountY), "Dex: transfer failed");

        return liquidity;
    }

    function removeLiquidity(uint256 liquidity, uint256 minAmountX, uint256 minAmountY) external returns (uint256 amountX, uint256 amountY) {
        require(balanceOf[msg.sender] >= liquidity, "Dex: Insufficient liquidity balance");

        // Calculate the proportional amounts of tokenX and tokenY to return
        amountX = (liquidity * reserveX) / totalSupply;
        amountY = (liquidity * reserveY) / totalSupply;

        require(amountX >= minAmountX && amountY >= minAmountY, "Dex: Insufficient output amount");

        // Update balances and reserves
        balanceOf[msg.sender] -= liquidity;
        totalSupply -= liquidity;
        reserveX -= amountX;
        reserveY -= amountY;

        require(tokenX.transfer(msg.sender, amountX), "Dex: transfer failed");
        require(tokenY.transfer(msg.sender, amountY), "Dex: transfer failed");

        return (amountX, amountY);
    }

    function swap(uint256 amountX, uint256 amountY, uint256 minOutput) external returns (uint256 output) {
        require(amountX == 0 || amountY == 0, "Dex: One of the amounts must be zero");
        require(amountX != 0 || amountY != 0, "Dex: One amount must be non-zero");

        if (amountX > 0) {
            uint256 newReserveX = reserveX + amountX;
            uint256 newReserveY = (reserveX * reserveY) / newReserveX;
            output = reserveY - newReserveY;
            output = (output * 999) / 1000; // 0.1% fee
            require(output >= minOutput, "Dex: Output amount too low");

            // Update reserves
            reserveX = newReserveX;
            reserveY = reserveY - output;  // Ensure reserveY reflects the correct state after swap

            // Transfer tokens
            require(tokenX.transferFrom(msg.sender, address(this), amountX), "Dex: transfer failed");
            require(tokenY.transfer(msg.sender, output), "Dex: transfer failed");
        } else {
            uint256 newReserveY = reserveY + amountY;
            uint256 newReserveX = (reserveX * reserveY) / newReserveY;
            output = reserveX - newReserveX;
            output = (output * 999) / 1000; // 0.1% fee
            require(output >= minOutput, "Dex: Output amount too low");

            // Update reserves
            reserveY = newReserveY;
            reserveX = reserveX - output;  // Ensure reserveX reflects the correct state after swap

            // Transfer tokens
            require(tokenY.transferFrom(msg.sender, address(this), amountY), "Dex: transfer failed");
            require(tokenX.transfer(msg.sender, output), "Dex: transfer failed");
        }

        return output;
    }

    function sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

