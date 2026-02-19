// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {WRMDocumentCertificationRegistry} from "../src/WRMDocumentCertificationRegistry.sol";

contract WRMDocumentCertificationRegistryTest is Test {
    WRMDocumentCertificationRegistry private registry;
    bytes32 private constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    address private admin = address(0xA11CE);
    address private relayer = address(0xB0B);
    address private user = address(0xCAFE);
    address private newRelayer = address(0xD00D);

    bytes32 private docHash = keccak256("doc");
    bytes32 private requesterIdHash = keccak256("requester");
    bytes32 private documentIdHash = keccak256("document");

    event Certified(
        bytes32 indexed documentHash,
        bytes32 indexed requesterIdHash,
        bytes32 indexed documentIdHash,
        uint256 certifiedAt,
        address certifiedBy
    );

    function setUp() public {
        registry = new WRMDocumentCertificationRegistry(admin);
        vm.prank(admin);
        registry.grantRole(RELAYER_ROLE, relayer);
    }

    function testRelayerCanCertifySuccessfully() public {
        vm.prank(relayer);
        registry.certify(docHash, requesterIdHash, documentIdHash);

        assertTrue(registry.isCertified(docHash));
    }

    function testRelayerCanCertifyEmitsEvent() public {
        uint256 ts = 1_700_000_000;
        vm.warp(ts);

        vm.expectEmit(true, true, true, true);
        emit Certified(docHash, requesterIdHash, documentIdHash, ts, relayer);

        vm.prank(relayer);
        registry.certify(docHash, requesterIdHash, documentIdHash);
    }

    function testNonRelayerCannotCertify() public {
        vm.expectRevert();
        registry.certify(docHash, requesterIdHash, documentIdHash);
    }

    function testZeroDocumentHashReverts() public {
        vm.prank(relayer);
        vm.expectRevert(
            WRMDocumentCertificationRegistry.InvalidDocumentHash.selector
        );
        registry.certify(bytes32(0), requesterIdHash, documentIdHash);
    }

    function testZeroRequesterIdHashReverts() public {
        vm.prank(relayer);
        vm.expectRevert(
            WRMDocumentCertificationRegistry.InvalidRequesterIdHash.selector
        );
        registry.certify(docHash, bytes32(0), documentIdHash);
    }

    function testZeroDocumentIdHashReverts() public {
        vm.prank(relayer);
        vm.expectRevert(
            WRMDocumentCertificationRegistry.InvalidDocumentIdHash.selector
        );
        registry.certify(docHash, requesterIdHash, bytes32(0));
    }

    function testDuplicateCertificationReverts() public {
        vm.prank(relayer);
        registry.certify(docHash, requesterIdHash, documentIdHash);

        vm.prank(relayer);
        vm.expectRevert(
            abi.encodeWithSelector(
                WRMDocumentCertificationRegistry.DocumentAlreadyCertified.selector,
                docHash
            )
        );
        registry.certify(docHash, requesterIdHash, documentIdHash);
    }

    function testIsCertifiedReturnsTrueAfterCertify() public {
        vm.prank(relayer);
        registry.certify(docHash, requesterIdHash, documentIdHash);

        assertTrue(registry.isCertified(docHash));
    }

    function testGetCertificationReturnsExactValues() public {
        uint256 ts = 1_700_000_123;
        vm.warp(ts);

        vm.prank(relayer);
        registry.certify(docHash, requesterIdHash, documentIdHash);

        (
            bool exists,
            bytes32 storedRequesterIdHash,
            bytes32 storedDocumentIdHash,
            uint256 certifiedAt,
            address certifiedBy,
            uint256 chainIdAtWrite
        ) = registry.getCertification(docHash);

        assertTrue(exists);
        assertEq(storedRequesterIdHash, requesterIdHash);
        assertEq(storedDocumentIdHash, documentIdHash);
        assertEq(certifiedAt, ts);
        assertEq(certifiedBy, relayer);
        assertEq(chainIdAtWrite, block.chainid);
    }

    function testAdminCanGrantRelayerRole() public {
        vm.prank(admin);
        registry.grantRole(RELAYER_ROLE, newRelayer);

        assertTrue(registry.hasRole(RELAYER_ROLE, newRelayer));
    }

    function testRevokedRelayerCannotCertify() public {
        vm.prank(admin);
        registry.grantRole(RELAYER_ROLE, newRelayer);
        vm.prank(admin);
        registry.revokeRole(RELAYER_ROLE, newRelayer);

        vm.prank(newRelayer);
        vm.expectRevert();
        registry.certify(docHash, requesterIdHash, documentIdHash);
    }
}
