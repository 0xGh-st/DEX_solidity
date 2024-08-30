// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Dex{
	ERC20 tokenX;
	ERC20 tokenY;
	uint256 k;

	constructor(address _tokenX, address _tokenY){
		tokenX = ERC20(_tokenX);
		tokenY = ERC20(_tokenY);
	}

	function addLiquidity(uint256 _amountX, uint256 _amountY, uint256 param) public returns(uint256){
		require(_amountX > 0 && _amountY > 0, "addLiquidity=>first require");
		require(_amountX + tokenX.balanceOf(address(this)) == _amountY + tokenY.balanceOf(address(this)), "addLiquidity=>Imbalance");
		require(tokenX.allowance(msg.sender, address(this))>=_amountX && tokenY.allowance(msg.sender, address(this))>=_amountY, "ERC20: insufficient allowance");
		require(tokenX.balanceOf(msg.sender)>=_amountX && tokenY.balanceOf(msg.sender)>=_amountY, "ERC20: transfer amount exceeds balance");
		tokenX.transferFrom(msg.sender, address(this), _amountX);
		tokenY.transferFrom(msg.sender, address(this), _amountY);
		if(param != 0) revert();
		k = tokenX.balanceOf(address(this)) + tokenY.balanceOf(address(this));		

		return _amountX + _amountY;
	}

	function removeLiquidity(uint256 _amountX, uint256 _amountY, uint256 param) public returns(uint256, uint256){
		require(tokenX.transfer(msg.sender, _amountX), "removeLiquidity=>Failed tokenX.transfer");
		require(tokenY.transfer(msg.sender, _amountY), "removeLiquidity=>Failed tokenY.transfer");
		
		k = tokenX.balanceOf(address(this)) *  tokenY.balanceOf(address(this));		

		return (tokenX.balanceOf(address(this)), tokenY.balanceOf(address(this)));		
	}

	function swap(uint256 _amountX, uint256 _amountY, uint256 param) public returns(uint256){
		require((_amountX > 0 && _amountY == 0) || (_amountX == 0 && _amountY > 0), "swap first require");

		ERC20 _tokenOut;
		ERC20 _tokenIn;
		uint256 _amountOut;
		uint256 _amountIn;

		if(_amountX>0){
			_tokenOut = tokenY;
			_tokenIn = tokenX;
			_amountIn = _amountX;
		}
		else{
			_tokenOut = tokenX;
			_tokenIn = tokenY;
			_amountIn = _amountY;
		}

		_amountOut = k/(_tokenOut.balanceOf(address(this)) - _amountOut) - (k/(_tokenOut.balanceOf(address(this)) - _amountOut))*1/100;

		require(_tokenIn.transferFrom(msg.sender, address(this), _amountIn));
		require(_tokenOut.transfer(msg.sender, _amountOut));

		return _amountOut;
	}
}
