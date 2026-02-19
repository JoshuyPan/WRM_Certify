// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract WRMDocumentCertificationRegistry is AccessControl {
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    error InvalidDocumentHash();
    error InvalidRequesterIdHash();
    error InvalidDocumentIdHash();
    error DocumentAlreadyCertified(bytes32 documentHash);

    struct Certification {
        bytes32 requesterIdHash;
        bytes32 documentIdHash;
        uint256 certifiedAt;
        address certifiedBy;
        uint256 chainIdAtWrite;
    }

    mapping(bytes32 => Certification) private _certifications;
    mapping(bytes32 => bool) private _exists;

    event Certified(
        bytes32 indexed documentHash,
        bytes32 indexed requesterIdHash,
        bytes32 indexed documentIdHash,
        uint256 certifiedAt,
        address certifiedBy
    );

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function certify(
        bytes32 documentHash,
        bytes32 requesterIdHash,
        bytes32 documentIdHash
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
        if (_exists[documentHash]) {
            revert DocumentAlreadyCertified(documentHash);
        }

        _certifications[documentHash] = Certification({
            requesterIdHash: requesterIdHash,
            documentIdHash: documentIdHash,
            certifiedAt: block.timestamp,
            certifiedBy: msg.sender,
            chainIdAtWrite: block.chainid
        });
        _exists[documentHash] = true;

        emit Certified(
            documentHash,
            requesterIdHash,
            documentIdHash,
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
            cert.requesterIdHash,
            cert.documentIdHash,
            cert.certifiedAt,
            cert.certifiedBy,
            cert.chainIdAtWrite
        );
    }
}
