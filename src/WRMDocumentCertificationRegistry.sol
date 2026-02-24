// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract WRMDocumentCertificationRegistry is AccessControl {
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    uint256 public constant MAX_PAGE_SIZE = 100;

    error InvalidDocumentHash();
    error InvalidRequesterIdHash();
    error InvalidDocumentIdHash();
    error InvalidCompanyId();
    error InvalidCompanyName();
    error InvalidDocumentName();
    error InvalidDocumentType();
    error DocumentAlreadyCertified(bytes32 documentHash);

    enum DocumentType {
        MedicalCertificate,
        Training,
        Audit
    }

    struct Certification {
        string companyId;
        string companyName;
        string documentName;
        DocumentType documentType;
        bytes32 requesterIdHash;
        bytes32 documentIdHash;
        uint256 certifiedAt;
        address certifiedBy;
        uint256 chainIdAtWrite;
    }

    struct CertificationRecord {
        bytes32 documentHash;
        string companyId;
        string companyName;
        string documentName;
        DocumentType documentType;
        bytes32 requesterIdHash;
        bytes32 documentIdHash;
        uint256 certifiedAt;
        address certifiedBy;
        uint256 chainIdAtWrite;
    }

    mapping(bytes32 => Certification) private _certifications;
    mapping(bytes32 => bool) private _exists;
    mapping(bytes32 => bytes32[]) private _companyDocumentHashes;

    event Certified(
        bytes32 indexed documentHash,
        bytes32 indexed companyIdHash,
        bytes32 indexed requesterIdHash,
        bytes32 documentIdHash,
        string companyId,
        string companyName,
        string documentName,
        DocumentType documentType,
        uint256 certifiedAt,
        address certifiedBy
    );

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function certify(
        bytes32 documentHash,
        bytes32 requesterIdHash,
        bytes32 documentIdHash,
        string calldata companyId,
        string calldata companyName,
        string calldata documentName,
        uint8 documentType
    ) external onlyRole(RELAYER_ROLE) {
        if (documentHash == bytes32(0)) {
            revert InvalidDocumentHash();
        }
        if (requesterIdHash == bytes32(0)) {
            revert InvalidRequesterIdHash();
        }
        if (documentIdHash == bytes32(0)) {
            revert InvalidDocumentIdHash();
        }
        if (bytes(companyId).length == 0) {
            revert InvalidCompanyId();
        }
        if (bytes(companyName).length == 0) {
            revert InvalidCompanyName();
        }
        if (bytes(documentName).length == 0) {
            revert InvalidDocumentName();
        }
        if (documentType > uint8(DocumentType.Audit)) {
            revert InvalidDocumentType();
        }
        if (_exists[documentHash]) {
            revert DocumentAlreadyCertified(documentHash);
        }

        DocumentType parsedDocumentType = DocumentType(documentType);
        bytes32 companyIdHash = keccak256(bytes(companyId));

        _certifications[documentHash] = Certification({
            companyId: companyId,
            companyName: companyName,
            documentName: documentName,
            documentType: parsedDocumentType,
            requesterIdHash: requesterIdHash,
            documentIdHash: documentIdHash,
            certifiedAt: block.timestamp,
            certifiedBy: msg.sender,
            chainIdAtWrite: block.chainid
        });
        _exists[documentHash] = true;
        _companyDocumentHashes[companyIdHash].push(documentHash);

        emit Certified(
            documentHash,
            companyIdHash,
            requesterIdHash,
            documentIdHash,
            companyId,
            companyName,
            documentName,
            parsedDocumentType,
            block.timestamp,
            msg.sender
        );
    }

    function isCertified(bytes32 documentHash) external view returns (bool) {
        return _exists[documentHash];
    }

    function getCertification(bytes32 documentHash)
        external
        view
        returns (
            bool exists,
            string memory companyId,
            string memory companyName,
            string memory documentName,
            DocumentType documentType,
            bytes32 requesterIdHash,
            bytes32 documentIdHash,
            uint256 certifiedAt,
            address certifiedBy,
            uint256 chainIdAtWrite
        )
    {
        exists = _exists[documentHash];
        Certification storage cert = _certifications[documentHash];
        return (
            exists,
            cert.companyId,
            cert.companyName,
            cert.documentName,
            cert.documentType,
            cert.requesterIdHash,
            cert.documentIdHash,
            cert.certifiedAt,
            cert.certifiedBy,
            cert.chainIdAtWrite
        );
    }

    function getCompanyDocumentCount(
        string calldata companyId
    ) external view returns (uint256) {
        bytes32 companyIdHash = keccak256(bytes(companyId));
        return _companyDocumentHashes[companyIdHash].length;
    }

    function getCompanyDocumentHashes(
        string calldata companyId,
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory documentHashes) {
        bytes32 companyIdHash = keccak256(bytes(companyId));
        return _paginateCompanyDocumentHashes(companyIdHash, offset, limit);
    }

    function getCompanyCertifications(
        string calldata companyId,
        uint256 offset,
        uint256 limit
    ) external view returns (CertificationRecord[] memory records) {
        bytes32 companyIdHash = keccak256(bytes(companyId));
        bytes32[] memory hashes = _paginateCompanyDocumentHashes(
            companyIdHash,
            offset,
            limit
        );
        records = new CertificationRecord[](hashes.length);

        for (uint256 i = 0; i < hashes.length; i++) {
            bytes32 documentHash = hashes[i];
            Certification storage cert = _certifications[documentHash];

            records[i] = CertificationRecord({
                documentHash: documentHash,
                companyId: cert.companyId,
                companyName: cert.companyName,
                documentName: cert.documentName,
                documentType: cert.documentType,
                requesterIdHash: cert.requesterIdHash,
                documentIdHash: cert.documentIdHash,
                certifiedAt: cert.certifiedAt,
                certifiedBy: cert.certifiedBy,
                chainIdAtWrite: cert.chainIdAtWrite
            });
        }
    }

    function _paginateCompanyDocumentHashes(
        bytes32 companyIdHash,
        uint256 offset,
        uint256 limit
    ) internal view returns (bytes32[] memory documentHashes) {
        bytes32[] storage hashes = _companyDocumentHashes[companyIdHash];
        uint256 total = hashes.length;
        if (offset >= total) {
            return new bytes32[](0);
        }

        uint256 boundedLimit = limit;
        if (boundedLimit == 0 || boundedLimit > MAX_PAGE_SIZE) {
            boundedLimit = MAX_PAGE_SIZE;
        }

        uint256 end = offset + boundedLimit;
        if (end > total) {
            end = total;
        }

        uint256 count = end - offset;
        documentHashes = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            documentHashes[i] = hashes[offset + i];
        }
    }
}
