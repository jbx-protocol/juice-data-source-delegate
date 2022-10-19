// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import '@jbx-protocol/juice-contracts-v3/contracts/structs/JBSplitAllocationData.sol';

import './interfaces/IPoolWrapper.sol';
import './interfaces/ICurveRegistry.sol';
import './interfaces/ICurvePool.sol';

import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';

/**
 @title
 Juicebox split allocator - swap to another asset

 @notice
*/
contract SwapAllocator is ERC165, Ownable, IJBSplitAllocator {
  event NewDex(IPoolWrapper);
  event RemoveDex(IPoolWrapper);

  // All the dexes for this allocator token tuple
  IPoolWrapper[] public dexes;

  // The token which should be distributed to the beneficiary
  address tokenOut;

  // The beneficiary of this split allocator
  address beneficiary;

  constructor(
    address _tokenOut,
    IPoolWrapper[] memory _dexes,
    address _beneficiary
  ) {
    dexes = _dexes;
    tokenOut = _tokenOut;
    beneficiary = _beneficiary;
  }

  function addDex(IPoolWrapper _newDex) external onlyOwner {
    dexes.push(_newDex);
    emit NewDex(_newDex);
  }

  function removeDex(IPoolWrapper _dexToRemove) external onlyOwner {

    uint256 _numberOfDexes = dexes.length;
    IPoolWrapper _currentWrapper;

    for(uint i; i < _numberOfDexes;) {
      _currentWrapper = dexes[i];

      // Swap and pop
      if(_currentWrapper == _dexToRemove) {
        dexes[i] = dexes[_numberOfDexes - 1];
        dexes.pop();
      }

      unchecked {
        ++i;
      }
    }

    emit RemoveDex(_dexToRemove);
  }

  //@inheritdoc IJBAllocator
  function allocate(JBSplitAllocationData calldata _data) external payable override {
    uint256 _amountIn = _data.amount;
    address _tokenIn = _data.token;
    address _tokenOut = tokenOut;

    // Keep record of the best pool wrapper. The pool address is passed to avoid having
    // to find it again in the wrapper
    address _bestPool;
    uint256 _bestQuote;
    IPoolWrapper _bestWrapper;

    // Keep a reference to the stored wrapper
    IPoolWrapper _currentWrapper;
    uint256 _activeDexes = dexes.length;
    for (uint256 i; i < _activeDexes; ) {
      _currentWrapper = dexes[i];

      // Get a quote (expressed as an amount of token received for an amount of token sent)
      (uint256 _quote, address _pool) = _currentWrapper.getQuote(_amountIn, _tokenIn, _tokenOut);

      // If the amount received from this dex is higher, save this wrapper
      if (_quote > _bestQuote) {
        _bestPool = _pool;
        _bestQuote = _quote;
        _bestWrapper = _currentWrapper;
      }

      unchecked {
        ++i;
      }
    }

    if(_bestQuote != 0) {
    // Send the token to the best pool wrapper...
    IERC20(_tokenIn).transfer(address(_bestWrapper), _amountIn);

    // ... And swap them - there is no slippage involved, as quote and swap are atomic
    _bestWrapper.swap(_amountIn, _tokenIn, _tokenOut, _bestQuote, _bestPool);

    // wrapper.swap will send the token back here, transfer them to the beneficiary
    IERC20(_tokenOut).transfer(beneficiary, IERC20(_tokenOut).balanceOf(address(this)));
    }
    // If no swap was performed, send the original token to the beneficiary
    else IERC20(_tokenIn).transfer(beneficiary, _amountIn);
  }

  function supportsInterface(bytes4 _interfaceId)
    public
    view
    override(IERC165, ERC165)
    returns (bool)
  {
    return
      _interfaceId == type(IJBSplitAllocator).interfaceId || super.supportsInterface(_interfaceId);
  }
}
