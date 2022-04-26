// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import './helpers/TestBaseWorkflow.sol';
import '../NFT-example/NFTPayDelegate.sol';
import '../NFT-example/NFTFundingCycleDataSource.sol';

import '@jbx-protocol-v2/contracts/interfaces/IJBPayDelegate.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBRedemptionDelegate.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBFundingCycleDataSource.sol';

contract TestNFTPayDelegate is TestBaseWorkflow {
  JBController controller;
  JBProjectMetadata _projectMetadata;
  JBFundingCycleData _data;
  JBFundingCycleMetadata _metadata;
  JBGroupedSplits[] _groupedSplits;
  IJBPaymentTerminal[] _terminals;
  JBFundAccessConstraints[] _fundAccessConstraints;
  JBTokenStore _tokenStore;
  address _projectOwner;

  uint256 WEIGHT = 1000 * 10**18;

  IJBPayDelegate payDelegate;

  function setUp() public override {
    payDelegate = new NFTRewards();

    IJBFundingCycleDataSource dataSource = new NFTFundingCycleDataSource(payDelegate);

    super.setUp();

    _projectOwner = multisig();

    _tokenStore = jbTokenStore();

    controller = jbController();

    _projectMetadata = JBProjectMetadata({content: 'myIPFSHash', domain: 1});

    _data = JBFundingCycleData({
      duration: 14,
      weight: WEIGHT,
      discountRate: 450000000,
      ballot: IJBFundingCycleBallot(address(0))
    });

    _metadata = JBFundingCycleMetadata({
      reservedRate: 5000,
      redemptionRate: 5000,
      ballotRedemptionRate: 0,
      pausePay: false,
      pauseDistributions: false,
      pauseRedeem: false,
      pauseBurn: false,
      allowMinting: true,
      allowChangeToken: true,
      allowTerminalMigration: false,
      allowControllerMigration: false,
      allowSetTerminals: false,
      allowSetController: false,
      holdFees: false,
      useTotalOverflowForRedemptions: false,
      useDataSourceForPay: false,
      useDataSourceForRedeem: false,
      dataSource: dataSource
    });
  }

  function testMint() public {
    address caller = address(69420); // Those 3 cheat codes are needed to avoid the msg.sender changing for...reason
    evm.startPrank(caller);
    evm.deal(caller, 100 ether);

    JBETHPaymentTerminal terminal = jbETHPaymentTerminal();

    _terminals.push(terminal);

    _fundAccessConstraints.push(
      JBFundAccessConstraints({
        terminal: jbETHPaymentTerminal(),
        token: jbLibraries().ETHToken(),
        distributionLimit: 10 ether,
        overflowAllowance: 5 ether,
        distributionLimitCurrency: 1, // Currency = ETH
        overflowAllowanceCurrency: 1
      })
    );

    uint256 projectId = controller.launchProjectFor(
      _projectOwner,
      _projectMetadata,
      _data,
      _metadata,
      block.timestamp,
      _groupedSplits,
      _fundAccessConstraints,
      _terminals,
      ''
    );

    terminal.pay{value: 20 ether}(
      projectId,
      20 ether,
      address(0),
      caller,
      0,
      false,
      'Take my money',
      new bytes(0)
    );

    assertEq(NFTRewards(address(payDelegate)).balanceOf(caller), 1);
  }
}
