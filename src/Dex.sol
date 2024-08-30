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

    function addLiquidity(uint256 _amountX, uint256 _amountY, uint256 _minLiquidity) external returns (uint256) {
        require(_amountX > 0 && _amountY > 0, "Dex: Invalid initialization");
        require(tokenX.allowance(msg.sender, address(this)) >= _amountX && tokenY.allowance(msg.sender, address(this)) >= _amountY, "ERC20: insufficient allowance");
        require(tokenX.balanceOf(msg.sender) >= _amountX && tokenY.balanceOf(msg.sender) >= _amountY, "ERC20: transfer amount exceeds balance");

        // **Detect and handle direct transfers before calculating liquidity**
        uint256 _currentBalanceX = tokenX.balanceOf(address(this));
        uint256 _currentBalanceY = tokenY.balanceOf(address(this));

        if (_currentBalanceX > reserveX || _currentBalanceY > reserveY) {
            uint256 _directTransferX = _currentBalanceX - reserveX;
            uint256 _directTransferY = _currentBalanceY - reserveY;

            // Update reserves to include any direct transfers
            reserveX += _directTransferX;
            reserveY += _directTransferY;
        }

        uint256 _liquidity;
        if (totalSupply == 0) {
            // Initial liquidity provision
            _liquidity = sqrt(_amountX * _amountY);
            require(_liquidity >= _minLiquidity, "Dex: Insufficient liquidity");
            totalSupply = _liquidity;
            balanceOf[msg.sender] = _liquidity;
            reserveX += _amountX;
            reserveY += _amountY;
        } 
		else {
            // Proportional liquidity provision
            uint256 _optimalAmountY = (_amountX * reserveY) / reserveX;
            uint256 _optimalAmountX = (_amountY * reserveX) / reserveY;

            if (_amountY > _optimalAmountY) {
                _amountY = _optimalAmountY;
            } 
			else {
                _amountX = _optimalAmountX;
            }

            _liquidity = (_amountX * totalSupply) / reserveX;
            require(_liquidity > 0 && _liquidity >= _minLiquidity, "Dex: Insufficient liquidity");

            reserveX += _amountX;
            reserveY += _amountY;
            totalSupply += _liquidity;
            balanceOf[msg.sender] += _liquidity;
        }

        // Perform transfers
        require(tokenX.transferFrom(msg.sender, address(this), _amountX), "Dex: transfer failed");
        require(tokenY.transferFrom(msg.sender, address(this), _amountY), "Dex: transfer failed");

        return _liquidity;
    }

    function removeLiquidity(uint256 _liquidity, uint256 _minAmountX, uint256 _minAmountY) external returns (uint256 _amountX, uint256 _amountY) {
        require(balanceOf[msg.sender] >= _liquidity, "Dex: Insufficient liquidity balance");

        _amountX = (_liquidity * reserveX) / totalSupply;
        _amountY = (_liquidity * reserveY) / totalSupply;

        require(_amountX >= _minAmountX && _amountY >= _minAmountY, "Dex: Insufficient output amount");

        balanceOf[msg.sender] -= _liquidity;
        totalSupply -= _liquidity;
        reserveX -= _amountX;
        reserveY -= _amountY;

        require(tokenX.transfer(msg.sender, _amountX), "Dex: transfer failed");
        require(tokenY.transfer(msg.sender, _amountY), "Dex: transfer failed");

        return (_amountX, _amountY);
    }

    function swap(uint256 _amountX, uint256 _amountY, uint256 _minOutput) external returns (uint256 _output) {
        require(_amountX == 0 && _amountY != 0 || _amountX != 0 && _amountY == 0, "Dex: One of the amounts must be zero");

        if (_amountX > 0) {
            uint256 _newReserveX = reserveX + _amountX;
            uint256 _newReserveY = (reserveX * reserveY) / _newReserveX;
            _output = reserveY - _newReserveY;
            _output = (_output * 999) / 1000; // 0.1% fee
            require(_output >= _minOutput, "Dex: Output amount too low");

            reserveX = _newReserveX;
            reserveY -= _output;

            require(tokenX.transferFrom(msg.sender, address(this), _amountX), "Dex: transfer failed");
            require(tokenY.transfer(msg.sender, _output), "Dex: transfer failed");
        } 
		else {
            uint256 _newReserveY = reserveY + _amountY;
            uint256 _newReserveX = (reserveX * reserveY) / _newReserveY;
            _output = reserveX - _newReserveX;
            _output = (_output * 999) / 1000; // 0.1% fee
            require(_output >= _minOutput, "Dex: Output amount too low");

            reserveY = _newReserveY;
            reserveX -= _output;

            require(tokenY.transferFrom(msg.sender, address(this), _amountY), "Dex: transfer failed");
            require(tokenX.transfer(msg.sender, _output), "Dex: transfer failed");
        }

        return _output;
    }

    function sqrt(uint _y) private pure returns (uint _z) {
        if (_y > 3) {
            _z = _y;
            uint _x = _y / 2 + 1;
            while (_x < _z) {
                _z = _x;
                _x = (_y / _x + _x) / 2;
            }
        } 
		else if (_y != 0) {
            _z = 1;
        }
    }
}

