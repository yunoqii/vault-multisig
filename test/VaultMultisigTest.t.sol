/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../src/VaultMultisig.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultMultisigTest is Test {
    VaultMultisig vault;
    uint256 quorum = 2;
    address[] signers;
    address[] signersArray;
    address[] newSignersArray;

    address newSigner = vm.addr(5);
    address newSigner2 = vm.addr(6);
    address newSigner3 = vm.addr(7);

    address signer1 = vm.addr(1);
    address signer2 = vm.addr(2);
    address signer3 = vm.addr(3);
    address defaultRecipient = vm.addr(999);
    address stranger = vm.addr(4);

    function setUp() public {
        signers.push(signer1);
        signers.push(signer2);
        signers.push(signer3);

        newSignersArray.push(newSigner);
        newSignersArray.push(newSigner2);
        newSignersArray.push(newSigner3);

        vault = new VaultMultisig(signers, quorum);
    }

    function test_InitiateTransferRevertIfNoEtherOnVault(address _randomAddress) public {
        vm.assume(_randomAddress != address(0));
        vm.prank(signer1);
        vm.expectRevert(VaultMultisig.VaultIsEmpty.selector);

        console.log("Vault balance: ", address(vault).balance);
        vault.initiateTransfer(_randomAddress, 1 wei);
    }

    function test_InitiateTransferRevertsInvalidRecipient() public {
        address recipient = address(0);

        vm.prank(signer1);

        vm.expectRevert(VaultMultisig.InvalidRecipient.selector);

        vault.initiateTransfer(recipient, 1 wei);
    }

    function test_InitiateTransferRevertsInvalidMain(address _randomAddress) public {
        vm.assume(_randomAddress != address(0));

        vm.prank(signer1);

        vm.expectRevert(VaultMultisig.InvalidAmount.selector);

        vault.initiateTransfer(_randomAddress, 0);
    }

    function test_InitiateTransferWorks(address _randomAddress) public {
        vm.assume(_randomAddress != address(0));

        fundVault(1 ether);

        vm.prank(signer1);

        vm.expectEmit(true, true, false, true);
        emit VaultMultisig.TransferInitiated(0, _randomAddress, 1 ether);

        vault.initiateTransfer(_randomAddress, 1 ether);

        (address to, uint256 amount, uint256 approvals, bool executed) = vault.getTransfer(0);

        assertEq(to, _randomAddress);
        assertEq(amount, 1 ether);
        assertEq(approvals, 1);
        assertEq(executed, false);
    }

    function test_approveTransferShouldWork() public {
        vm.startPrank(signer1);
        fundVault(1 ether);
        vault.initiateTransfer(defaultRecipient, 1 ether);

        /// first approve
        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.SignerAlreadyApproved.selector, signer1));
        vault.approveTransfer(0);

        /// 2nd approve
        vm.startPrank(signer2);
        vault.approveTransfer(0);

        /// 3rd approve
        vm.startPrank(signer3);
        vault.approveTransfer(0);

        (,, uint256 approvals,) = vault.getTransfer(0);

        assertEq(approvals, 3);
    }

    function test_approveTransferShouldEmitTransferApproved() public {
        vm.startPrank(signer1);
        fundVault(1 ether);
        vault.initiateTransfer(defaultRecipient, 1 ether);

        vm.expectEmit(true, true, false, false);
        emit VaultMultisig.TransferApproved(0, signer2);

        vm.startPrank(signer2);
        vault.approveTransfer(0);
    }

    function test_executeTransferWorks() public {
        vm.startPrank(signer1);
        fundVault(1 ether);
        vault.initiateTransfer(defaultRecipient, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.QuorumHasNotBeenReached.selector, 0));
        vault.executeTransfer(0);

        vm.startPrank(signer2);
        vault.approveTransfer(0);

        vm.expectEmit(true, false, false, false);
        emit VaultMultisig.TransferExecuted(0);
        vault.executeTransfer(0);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.TransferIsAlreadyExecuted.selector, 0));
        vault.executeTransfer(0);
    }

    function test_hasSignedTransferWorks() public {
        vm.startPrank(signer1);
        fundVault(1 ether);
        vault.initiateTransfer(defaultRecipient, 1 ether);

        vm.startPrank(signer2);
        vault.approveTransfer(0);

        assertTrue(vault.hasSignedTransfer(0, signer1));
        assertTrue(vault.hasSignedTransfer(0, signer2));
    }

    function test_getTransferWorks() public {
        uint256 beforeTransferInitiation = vault.getTransferCount();
        assertEq(beforeTransferInitiation, 0);

        vm.startPrank(signer1);
        fundVault(1 ether);
        vault.initiateTransfer(defaultRecipient, 1 ether);

        uint256 afterTransferInitiation = vault.getTransferCount();
        assertEq(afterTransferInitiation, 1);
    }

    function test_OnlyMultisigSignerModifierWorks() public {
        vm.prank(stranger);
        fundVault(1 ether);

        vm.expectRevert(VaultMultisig.InvalidMultisigSigner.selector);
        vault.initiateTransfer(defaultRecipient, 0);
    }

    function test_constructorRevertsSignersArrayCannotBeEmpty() public {
        address[] memory empty;

        vm.expectRevert(VaultMultisig.SignersArrayCannotBeEmpty.selector);
        new VaultMultisig(empty, 1);
    }

    function test_constructorRevertsQuorumGreaterThanSigners() public {
        signersArray.push(signer1);
        signersArray.push(signer2);

        vm.expectRevert(VaultMultisig.QuorumGreaterThanSigners.selector);
        new VaultMultisig(signersArray, 3);
    }

    function test_constructorRevertsQuorumCannotBeZero() public {
        signersArray.push(signer1);

        vm.expectRevert(VaultMultisig.QuorumCannotBeZero.selector);
        new VaultMultisig(signersArray, 0);
    }

    function test_UpdateSignerAndQuorumWorks() public {
        vm.startPrank(signer1);
        console.log(newSignersArray.length);

        address[] memory empty;

        vm.expectRevert(VaultMultisig.SignersArrayCannotBeEmpty.selector);
        vault.updateSignersAndQuorum(empty, 1);

        vm.expectRevert(VaultMultisig.QuorumCannotBeZero.selector);
        vault.updateSignersAndQuorum(newSignersArray, 0);

        vm.expectRevert(VaultMultisig.QuorumGreaterThanSigners.selector);
        vault.updateSignersAndQuorum(newSignersArray, 4);

        vm.expectEmit(false, false, false, false);
        emit VaultMultisig.MultiSigSignersUpdated();
        vm.expectEmit(true, false, false, false);
        emit VaultMultisig.QuorumUpdated(2);
        vault.updateSignersAndQuorum(newSignersArray, 2);

    }

    function fundVault(uint256 amount) internal {
        vm.deal(address(vault), amount);
    }
}
