// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract WRMDocumentCertificationRegistry is AccessControl {
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    uint256 public constant MAX_PAGE_SIZE = 100;

    error EmptyDocumentContent();
    error DocumentAlreadyCertified(bytes32 documentHash);

    struct Certification {
        uint256 certifiedAt;
        address certifiedBy;
        uint256 chainIdAtWrite;
    }

    struct CertificationRecord {
        bytes32 documentHash;
        uint256 certifiedAt;
        address certifiedBy;
        uint256 chainIdAtWrite;
    }

    mapping(bytes32 => Certification) private _certifications;
    mapping(bytes32 => bool) private _exists;
    bytes32[] private _documentHashes;

    event Certified(
        bytes32 indexed documentHash, uint256 certifiedAt, address indexed certifiedBy, uint256 chainIdAtWrite
    );

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function certify(bytes calldata documentContent) external onlyRole(RELAYER_ROLE) returns (bytes32 documentHash) {
        if (documentContent.length == 0) {
            revert EmptyDocumentContent();
        }

        documentHash = _hashDocument(documentContent);
        if (_exists[documentHash]) {
            revert DocumentAlreadyCertified(documentHash);
        }

        _certifications[documentHash] =
            Certification({certifiedAt: block.timestamp, certifiedBy: msg.sender, chainIdAtWrite: block.chainid});
        _exists[documentHash] = true;
        _documentHashes.push(documentHash);

        emit Certified(documentHash, block.timestamp, msg.sender, block.chainid);
    }

    function hashDocument(bytes calldata documentContent) external pure returns (bytes32 documentHash) {
        if (documentContent.length == 0) {
            revert EmptyDocumentContent();
        }

        return _hashDocument(documentContent);
    }

    function isCertified(bytes32 documentHash) external view returns (bool) {
        return _exists[documentHash];
    }

    function getCertification(bytes32 documentHash)
        external
        view
        returns (bool exists, uint256 certifiedAt, address certifiedBy, uint256 chainIdAtWrite)
    {
        exists = _exists[documentHash];
        Certification storage cert = _certifications[documentHash];
        return (exists, cert.certifiedAt, cert.certifiedBy, cert.chainIdAtWrite);
    }

    function getCertificationCount() external view returns (uint256) {
        return _documentHashes.length;
    }

    function getDocumentHashes(uint256 offset, uint256 limit) external view returns (bytes32[] memory documentHashes) {
        return _paginateDocumentHashes(offset, limit);
    }

    function getCertifications(uint256 offset, uint256 limit)
        external
        view
        returns (CertificationRecord[] memory records)
    {
        bytes32[] memory hashes = _paginateDocumentHashes(offset, limit);
        records = new CertificationRecord[](hashes.length);

        for (uint256 i = 0; i < hashes.length; i++) {
            bytes32 documentHash = hashes[i];
            Certification storage cert = _certifications[documentHash];

            records[i] = CertificationRecord({
                documentHash: documentHash,
                certifiedAt: cert.certifiedAt,
                certifiedBy: cert.certifiedBy,
                chainIdAtWrite: cert.chainIdAtWrite
            });
        }
    }

    function _paginateDocumentHashes(uint256 offset, uint256 limit)
        internal
        view
        returns (bytes32[] memory documentHashes)
    {
        uint256 total = _documentHashes.length;
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
            documentHashes[i] = _documentHashes[offset + i];
        }
    }

    function _hashDocument(bytes calldata documentContent) internal pure returns (bytes32 documentHash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, documentContent.offset, documentContent.length)
            documentHash := keccak256(ptr, documentContent.length)
        }
    }
}
