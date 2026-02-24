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

    bytes32 private docHash = keccak256("doc");
    bytes32 private docHash2 = keccak256("doc-2");
    bytes32 private requesterIdHash = keccak256("requester");
    bytes32 private documentIdHash = keccak256("document");
    bytes32 private documentIdHash2 = keccak256("document-2");

    string private companyId = "COMPANY-001";
    string private companyName = "ACME SPA";
    string private documentName = "Certificato idoneita Rossi";

    event Certified(
        bytes32 indexed documentHash,
        bytes32 indexed companyIdHash,
        bytes32 indexed requesterIdHash,
        bytes32 documentIdHash,
        string companyId,
        string companyName,
        string documentName,
        WRMDocumentCertificationRegistry.DocumentType documentType,
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
        registry.certify(
            docHash,
            requesterIdHash,
            documentIdHash,
            companyId,
            companyName,
            documentName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );

        assertTrue(registry.isCertified(docHash));
    }

    function testRelayerCanCertifyEmitsEvent() public {
        uint256 ts = 1_700_000_000;
        vm.warp(ts);
        bytes32 companyIdHash = keccak256(bytes(companyId));

        vm.expectEmit(true, true, true, true);
        emit Certified(
            docHash,
            companyIdHash,
            requesterIdHash,
            documentIdHash,
            companyId,
            companyName,
            documentName,
            WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate,
            ts,
            relayer
        );

        vm.prank(relayer);
        registry.certify(
            docHash,
            requesterIdHash,
            documentIdHash,
            companyId,
            companyName,
            documentName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );
    }

    function testNonRelayerCannotCertify() public {
        vm.expectRevert();
        registry.certify(
            docHash,
            requesterIdHash,
            documentIdHash,
            companyId,
            companyName,
            documentName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );
    }

    function testZeroDocumentHashReverts() public {
        vm.prank(relayer);
        vm.expectRevert(
            WRMDocumentCertificationRegistry.InvalidDocumentHash.selector
        );
        registry.certify(
            bytes32(0),
            requesterIdHash,
            documentIdHash,
            companyId,
            companyName,
            documentName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );
    }

    function testZeroRequesterIdHashReverts() public {
        vm.prank(relayer);
        vm.expectRevert(
            WRMDocumentCertificationRegistry.InvalidRequesterIdHash.selector
        );
        registry.certify(
            docHash,
            bytes32(0),
            documentIdHash,
            companyId,
            companyName,
            documentName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );
    }

    function testZeroDocumentIdHashReverts() public {
        vm.prank(relayer);
        vm.expectRevert(
            WRMDocumentCertificationRegistry.InvalidDocumentIdHash.selector
        );
        registry.certify(
            docHash,
            requesterIdHash,
            bytes32(0),
            companyId,
            companyName,
            documentName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );
    }

    function testEmptyCompanyIdReverts() public {
        vm.prank(relayer);
        vm.expectRevert(WRMDocumentCertificationRegistry.InvalidCompanyId.selector);
        registry.certify(
            docHash,
            requesterIdHash,
            documentIdHash,
            "",
            companyName,
            documentName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );
    }

    function testEmptyCompanyNameReverts() public {
        vm.prank(relayer);
        vm.expectRevert(
            WRMDocumentCertificationRegistry.InvalidCompanyName.selector
        );
        registry.certify(
            docHash,
            requesterIdHash,
            documentIdHash,
            companyId,
            "",
            documentName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );
    }

    function testEmptyDocumentNameReverts() public {
        vm.prank(relayer);
        vm.expectRevert(
            WRMDocumentCertificationRegistry.InvalidDocumentName.selector
        );
        registry.certify(
            docHash,
            requesterIdHash,
            documentIdHash,
            companyId,
            companyName,
            "",
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );
    }

    function testInvalidDocumentTypeReverts() public {
        vm.prank(relayer);
        vm.expectRevert(
            WRMDocumentCertificationRegistry.InvalidDocumentType.selector
        );
        registry.certify(
            docHash,
            requesterIdHash,
            documentIdHash,
            companyId,
            companyName,
            documentName,
            99
        );
    }

    function testDuplicateCertificationReverts() public {
        vm.prank(relayer);
        registry.certify(
            docHash,
            requesterIdHash,
            documentIdHash,
            companyId,
            companyName,
            documentName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );

        vm.prank(relayer);
        vm.expectRevert(
            abi.encodeWithSelector(
                WRMDocumentCertificationRegistry.DocumentAlreadyCertified.selector,
                docHash
            )
        );
        registry.certify(
            docHash,
            requesterIdHash,
            documentIdHash,
            companyId,
            companyName,
            documentName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );
    }

    function testGetCertificationReturnsExactValues() public {
        uint256 ts = 1_700_000_123;
        vm.warp(ts);

        vm.prank(relayer);
        registry.certify(
            docHash,
            requesterIdHash,
            documentIdHash,
            companyId,
            companyName,
            documentName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.Training)
        );

        (
            bool exists,
            string memory storedCompanyId,
            string memory storedCompanyName,
            string memory storedDocumentName,
            WRMDocumentCertificationRegistry.DocumentType storedDocumentType,
            bytes32 storedRequesterIdHash,
            bytes32 storedDocumentIdHash,
            uint256 certifiedAt,
            address certifiedBy,
            uint256 chainIdAtWrite
        ) = registry.getCertification(docHash);

        assertTrue(exists);
        assertEq(storedCompanyId, companyId);
        assertEq(storedCompanyName, companyName);
        assertEq(storedDocumentName, documentName);
        assertEq(
            uint8(storedDocumentType),
            uint8(WRMDocumentCertificationRegistry.DocumentType.Training)
        );
        assertEq(storedRequesterIdHash, requesterIdHash);
        assertEq(storedDocumentIdHash, documentIdHash);
        assertEq(certifiedAt, ts);
        assertEq(certifiedBy, relayer);
        assertEq(chainIdAtWrite, block.chainid);
    }

    function testCompanyCatalogFunctions() public {
        string memory secondDocName = "Attestato sicurezza";

        vm.startPrank(relayer);
        registry.certify(
            docHash,
            requesterIdHash,
            documentIdHash,
            companyId,
            companyName,
            documentName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );
        registry.certify(
            docHash2,
            requesterIdHash,
            documentIdHash2,
            companyId,
            companyName,
            secondDocName,
            uint8(WRMDocumentCertificationRegistry.DocumentType.Training)
        );
        vm.stopPrank();

        uint256 total = registry.getCompanyDocumentCount(companyId);
        assertEq(total, 2);

        bytes32[] memory hashes = registry.getCompanyDocumentHashes(
            companyId,
            0,
            10
        );
        assertEq(hashes.length, 2);
        assertEq(hashes[0], docHash);
        assertEq(hashes[1], docHash2);

        WRMDocumentCertificationRegistry.CertificationRecord[]
            memory records = registry.getCompanyCertifications(companyId, 0, 10);
        assertEq(records.length, 2);
        assertEq(records[0].documentHash, docHash);
        assertEq(records[0].companyName, companyName);
        assertEq(
            uint8(records[0].documentType),
            uint8(WRMDocumentCertificationRegistry.DocumentType.MedicalCertificate)
        );
        assertEq(records[1].documentHash, docHash2);
        assertEq(records[1].documentName, secondDocName);
        assertEq(
            uint8(records[1].documentType),
            uint8(WRMDocumentCertificationRegistry.DocumentType.Training)
        );
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
