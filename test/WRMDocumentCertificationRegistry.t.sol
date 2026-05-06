// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {WRMDocumentCertificationRegistry} from "../src/WRMDocumentCertificationRegistry.sol";

contract WRMDocumentCertificationRegistryTest is Test {
    WRMDocumentCertificationRegistry private registry;
    bytes32 private constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    address private admin = address(0xA11CE);
    address private relayer = address(0xB0B);
    address private newRelayer = address(0xD00D);

    bytes private documentContent = bytes("Contenuto integrale del documento da certificare");
    bytes private secondDocumentContent = bytes("Secondo documento con contenuto diverso");

    event Certified(
        bytes32 indexed documentHash, uint256 certifiedAt, address indexed certifiedBy, uint256 chainIdAtWrite
    );

    function setUp() public {
        registry = new WRMDocumentCertificationRegistry(admin);
        vm.prank(admin);
        registry.grantRole(RELAYER_ROLE, relayer);
    }

    function testRelayerCanCertifySuccessfully() public {
        bytes32 expectedHash = keccak256(documentContent);

        vm.prank(relayer);
        bytes32 documentHash = registry.certify(documentContent);

        assertEq(documentHash, expectedHash);
        assertTrue(registry.isCertified(expectedHash));
    }

    function testHashDocumentMatchesCertifyHash() public view {
        bytes32 expectedHash = keccak256(documentContent);

        assertEq(registry.hashDocument(documentContent), expectedHash);
    }

    function testRelayerCanCertifyEmitsEvent() public {
        uint256 ts = 1_700_000_000;
        vm.warp(ts);
        bytes32 expectedHash = keccak256(documentContent);

        vm.expectEmit(true, true, true, true);
        emit Certified(expectedHash, ts, relayer, block.chainid);

        vm.prank(relayer);
        registry.certify(documentContent);
    }

    function testNonRelayerCannotCertify() public {
        vm.expectRevert();
        registry.certify(documentContent);
    }

    function testEmptyDocumentContentReverts() public {
        vm.prank(relayer);
        vm.expectRevert(WRMDocumentCertificationRegistry.EmptyDocumentContent.selector);
        registry.certify("");
    }

    function testEmptyDocumentContentHashReverts() public {
        vm.expectRevert(WRMDocumentCertificationRegistry.EmptyDocumentContent.selector);
        registry.hashDocument("");
    }

    function testDuplicateCertificationReverts() public {
        bytes32 expectedHash = keccak256(documentContent);

        vm.prank(relayer);
        registry.certify(documentContent);

        vm.prank(relayer);
        vm.expectRevert(
            abi.encodeWithSelector(WRMDocumentCertificationRegistry.DocumentAlreadyCertified.selector, expectedHash)
        );
        registry.certify(documentContent);
    }

    function testGetCertificationReturnsExactValues() public {
        uint256 ts = 1_700_000_123;
        vm.warp(ts);
        bytes32 expectedHash = keccak256(documentContent);

        vm.prank(relayer);
        registry.certify(documentContent);

        (bool exists, uint256 certifiedAt, address certifiedBy, uint256 chainIdAtWrite) =
            registry.getCertification(expectedHash);

        assertTrue(exists);
        assertEq(certifiedAt, ts);
        assertEq(certifiedBy, relayer);
        assertEq(chainIdAtWrite, block.chainid);
    }

    function testGlobalCatalogFunctions() public {
        bytes32 expectedHash = keccak256(documentContent);
        bytes32 secondExpectedHash = keccak256(secondDocumentContent);

        vm.startPrank(relayer);
        registry.certify(documentContent);
        registry.certify(secondDocumentContent);
        vm.stopPrank();

        uint256 total = registry.getCertificationCount();
        assertEq(total, 2);

        bytes32[] memory hashes = registry.getDocumentHashes(0, 10);
        assertEq(hashes.length, 2);
        assertEq(hashes[0], expectedHash);
        assertEq(hashes[1], secondExpectedHash);

        WRMDocumentCertificationRegistry.CertificationRecord[] memory records = registry.getCertifications(0, 10);
        assertEq(records.length, 2);
        assertEq(records[0].documentHash, expectedHash);
        assertEq(records[0].certifiedBy, relayer);
        assertEq(records[1].documentHash, secondExpectedHash);
        assertEq(records[1].certifiedBy, relayer);
    }

    function testCatalogPaginationUsesMaxPageSizeWhenLimitIsZero() public {
        vm.startPrank(relayer);
        registry.certify(documentContent);
        registry.certify(secondDocumentContent);
        vm.stopPrank();

        bytes32[] memory hashes = registry.getDocumentHashes(0, 0);

        assertEq(hashes.length, 2);
    }

    function testAdminCanGrantAndRevokeRelayerRole() public {
        vm.prank(admin);
        registry.grantRole(RELAYER_ROLE, newRelayer);
        assertTrue(registry.hasRole(RELAYER_ROLE, newRelayer));

        vm.prank(admin);
        registry.revokeRole(RELAYER_ROLE, newRelayer);
        assertFalse(registry.hasRole(RELAYER_ROLE, newRelayer));
    }
}
