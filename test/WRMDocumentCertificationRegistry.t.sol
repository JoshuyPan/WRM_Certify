// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {WorkforceDocumentRegistry} from "../src/WRMDocumentCertificationRegistry.sol";

contract WorkforceDocumentRegistryTest is Test {
    WorkforceDocumentRegistry private registry;

    address private admin = address(0xA11CE);
    address private globalIssuer = address(0xB0B);
    address private tenantIssuer = address(0xD00D);
    address private stranger = address(0xBAD);

    bytes32 private constant TENANT_ID_HASH = keccak256("tenant:wrm");
    bytes32 private constant EXTERNAL_REF_HASH = keccak256("document:1");
    bytes32 private constant SECOND_EXTERNAL_REF_HASH = keccak256("document:2");
    bytes32 private constant DOCUMENT_COMMITMENT = keccak256("document content commitment");
    bytes32 private constant SECOND_DOCUMENT_COMMITMENT = keccak256("second document commitment");
    bytes32 private constant METADATA_COMMITMENT = keccak256("metadata commitment");
    bytes32 private constant REASON_COMMITMENT = keccak256("revocation reason");
    bytes32 private constant GLOBAL_ISSUER_ROLE = keccak256("GLOBAL_ISSUER_ROLE");
    bytes32 private constant REVOCATOR_ROLE = keccak256("REVOCATOR_ROLE");

    event TenantIssuerSet(bytes32 indexed tenantIdHash, address indexed issuer, bool allowed);

    event CertificateIssued(
        bytes32 indexed certificateId,
        bytes32 indexed tenantIdHash,
        bytes32 indexed documentCommitment,
        bytes32 externalRefHash,
        bytes32 metadataCommitment,
        address issuer,
        uint64 issuedAt
    );

    event CertificateRevoked(
        bytes32 indexed certificateId,
        bytes32 indexed tenantIdHash,
        bytes32 reasonCommitment,
        address revoker,
        uint64 revokedAt
    );

    function setUp() public {
        registry = new WorkforceDocumentRegistry(admin, 0);

        vm.prank(admin);
        registry.grantRole(GLOBAL_ISSUER_ROLE, globalIssuer);
    }

    function testGlobalIssuerCanIssueCertificate() public {
        uint64 ts = 1_700_000_000;
        vm.warp(ts);
        bytes32 certificateId = _certificateId(EXTERNAL_REF_HASH);

        vm.expectEmit(true, true, true, true);
        emit CertificateIssued(
            certificateId, TENANT_ID_HASH, DOCUMENT_COMMITMENT, EXTERNAL_REF_HASH, METADATA_COMMITMENT, globalIssuer, ts
        );

        vm.prank(globalIssuer);
        bytes32 returnedId =
            registry.issueCertificate(TENANT_ID_HASH, EXTERNAL_REF_HASH, DOCUMENT_COMMITMENT, METADATA_COMMITMENT);

        assertEq(returnedId, certificateId);
        assertTrue(registry.verifyCertificate(certificateId, DOCUMENT_COMMITMENT));
    }

    function testTenantIssuerCanIssueForAllowedTenant() public {
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit TenantIssuerSet(TENANT_ID_HASH, tenantIssuer, true);
        registry.setTenantIssuer(TENANT_ID_HASH, tenantIssuer, true);

        vm.prank(tenantIssuer);
        bytes32 certificateId =
            registry.issueCertificate(TENANT_ID_HASH, EXTERNAL_REF_HASH, DOCUMENT_COMMITMENT, bytes32(0));

        assertTrue(registry.verifyCertificate(certificateId, DOCUMENT_COMMITMENT));
    }

    function testUnauthorizedIssuerCannotIssue() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(WorkforceDocumentRegistry.UnauthorizedIssuer.selector, TENANT_ID_HASH, stranger)
        );
        registry.issueCertificate(TENANT_ID_HASH, EXTERNAL_REF_HASH, DOCUMENT_COMMITMENT, METADATA_COMMITMENT);
    }

    function testZeroRequiredValuesRevert() public {
        vm.prank(globalIssuer);
        vm.expectRevert(WorkforceDocumentRegistry.ZeroValue.selector);
        registry.issueCertificate(bytes32(0), EXTERNAL_REF_HASH, DOCUMENT_COMMITMENT, METADATA_COMMITMENT);
    }

    function testDuplicateCertificateReverts() public {
        vm.startPrank(globalIssuer);
        bytes32 certificateId =
            registry.issueCertificate(TENANT_ID_HASH, EXTERNAL_REF_HASH, DOCUMENT_COMMITMENT, METADATA_COMMITMENT);

        vm.expectRevert(
            abi.encodeWithSelector(WorkforceDocumentRegistry.CertificateAlreadyExists.selector, certificateId)
        );
        registry.issueCertificate(TENANT_ID_HASH, EXTERNAL_REF_HASH, SECOND_DOCUMENT_COMMITMENT, METADATA_COMMITMENT);
        vm.stopPrank();
    }

    function testDuplicateDocumentCommitmentRevertsWithDifferentExternalRef() public {
        vm.startPrank(globalIssuer);
        bytes32 certificateId =
            registry.issueCertificate(TENANT_ID_HASH, EXTERNAL_REF_HASH, DOCUMENT_COMMITMENT, METADATA_COMMITMENT);

        vm.expectRevert(
            abi.encodeWithSelector(
                WorkforceDocumentRegistry.DocumentAlreadyCertified.selector, DOCUMENT_COMMITMENT, certificateId
            )
        );
        registry.issueCertificate(TENANT_ID_HASH, SECOND_EXTERNAL_REF_HASH, DOCUMENT_COMMITMENT, METADATA_COMMITMENT);
        vm.stopPrank();
    }

    function testDocumentCommitmentStaysBlockedAfterRevoke() public {
        bytes32 certificateId = _issueDefaultCertificate();

        vm.prank(globalIssuer);
        registry.revokeCertificate(certificateId, REASON_COMMITMENT);

        vm.prank(globalIssuer);
        vm.expectRevert(
            abi.encodeWithSelector(
                WorkforceDocumentRegistry.DocumentAlreadyCertified.selector, DOCUMENT_COMMITMENT, certificateId
            )
        );
        registry.issueCertificate(TENANT_ID_HASH, SECOND_EXTERNAL_REF_HASH, DOCUMENT_COMMITMENT, METADATA_COMMITMENT);
    }

    function testGetCertificateReturnsExactValues() public {
        uint64 ts = 1_700_000_123;
        vm.warp(ts);

        vm.prank(globalIssuer);
        bytes32 certificateId =
            registry.issueCertificate(TENANT_ID_HASH, EXTERNAL_REF_HASH, DOCUMENT_COMMITMENT, METADATA_COMMITMENT);

        WorkforceDocumentRegistry.Certificate memory cert = registry.getCertificate(certificateId);

        assertEq(cert.tenantIdHash, TENANT_ID_HASH);
        assertEq(cert.externalRefHash, EXTERNAL_REF_HASH);
        assertEq(cert.documentCommitment, DOCUMENT_COMMITMENT);
        assertEq(cert.metadataCommitment, METADATA_COMMITMENT);
        assertEq(cert.issuer, globalIssuer);
        assertEq(cert.issuedAt, ts);
        assertEq(cert.revokedAt, 0);
        assertEq(uint8(cert.status), uint8(WorkforceDocumentRegistry.Status.Valid));
        assertEq(registry.getCertificateIdByDocumentCommitment(DOCUMENT_COMMITMENT), certificateId);
    }

    function testIssuerCanRevokeOwnCertificate() public {
        uint64 ts = 1_700_000_456;
        bytes32 certificateId = _issueDefaultCertificate();

        vm.warp(ts);
        vm.expectEmit(true, true, true, true);
        emit CertificateRevoked(certificateId, TENANT_ID_HASH, REASON_COMMITMENT, globalIssuer, ts);

        vm.prank(globalIssuer);
        registry.revokeCertificate(certificateId, REASON_COMMITMENT);

        WorkforceDocumentRegistry.Certificate memory cert = registry.getCertificate(certificateId);
        assertEq(uint8(cert.status), uint8(WorkforceDocumentRegistry.Status.Revoked));
        assertEq(cert.revokedAt, ts);
        assertFalse(registry.verifyCertificate(certificateId, DOCUMENT_COMMITMENT));
    }

    function testRevocatorRoleCanRevokeCertificate() public {
        bytes32 certificateId = _issueDefaultCertificate();

        vm.prank(admin);
        registry.grantRole(REVOCATOR_ROLE, stranger);

        vm.prank(stranger);
        registry.revokeCertificate(certificateId, REASON_COMMITMENT);

        WorkforceDocumentRegistry.Certificate memory cert = registry.getCertificate(certificateId);
        assertEq(uint8(cert.status), uint8(WorkforceDocumentRegistry.Status.Revoked));
    }

    function testUnauthorizedRevokerCannotRevoke() public {
        bytes32 certificateId = _issueDefaultCertificate();

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(WorkforceDocumentRegistry.UnauthorizedRevoker.selector, certificateId, stranger)
        );
        registry.revokeCertificate(certificateId, REASON_COMMITMENT);
    }

    function testPauseBlocksIssuingAndRevoking() public {
        bytes32 certificateId = _issueDefaultCertificate();

        vm.prank(admin);
        registry.pause();

        vm.prank(globalIssuer);
        vm.expectRevert();
        registry.issueCertificate(
            TENANT_ID_HASH, SECOND_EXTERNAL_REF_HASH, SECOND_DOCUMENT_COMMITMENT, METADATA_COMMITMENT
        );

        vm.prank(globalIssuer);
        vm.expectRevert();
        registry.revokeCertificate(certificateId, REASON_COMMITMENT);
    }

    function _issueDefaultCertificate() private returns (bytes32 certificateId) {
        vm.prank(globalIssuer);
        certificateId =
            registry.issueCertificate(TENANT_ID_HASH, EXTERNAL_REF_HASH, DOCUMENT_COMMITMENT, METADATA_COMMITMENT);
    }

    function _certificateId(bytes32 externalRefHash) private view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(registry), TENANT_ID_HASH, externalRefHash));
    }
}
