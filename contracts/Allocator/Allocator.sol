// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@jbx-protocol-v2/contracts/interfaces/IJBAllocator';

/**
 @title
 Juicebox split allocator

 @notice
 This is an allocator template, used as a recipient of a payout split, to add an extra layer of logic in fund allocation
*/
contract Allocator is IJBAllocator {
  //will inheritdoc IJBAllocator
  function allocate(JBSplitAllocationData calldata _data) external payable {
    payable(msg.sender).call{value: payable(address(this)).balance}('');
  }

  function supportsInterface(bytes4 _interfaceId) external pure override returns (bool) {
    return _interfaceId == type(IJBAllocator).interfaceId;
  }
}
