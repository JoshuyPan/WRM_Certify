// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    AccessControlDefaultAdminRules
} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title WorkforceDocumentRegistry
/// @notice Registro blockchain per certificare documenti aziendali tramite hash/commitment.
/// @dev Non salvare mai dati personali o sanitari in chiaro on-chain.
contract WorkforceDocumentRegistry is AccessControlDefaultAdminRules, Pausable {
    bytes32 public constant TENANT_MANAGER_ROLE = keccak256("TENANT_MANAGER_ROLE");
    bytes32 public constant GLOBAL_ISSUER_ROLE = keccak256("GLOBAL_ISSUER_ROLE");
    bytes32 public constant REVOCATOR_ROLE = keccak256("REVOCATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    enum Status {
        None,
        Valid,
        Revoked
    }

    struct Certificate {
        bytes32 tenantIdHash;
        bytes32 externalRefHash;
        bytes32 documentCommitment;
        bytes32 metadataCommitment;
        address issuer;
        uint64 issuedAt;
        uint64 revokedAt;
        Status status;
    }

    mapping(bytes32 => Certificate) private _certificates;

    /// @dev tenantIdHash => issuer wallet/relayer => allowed
    mapping(bytes32 => mapping(address => bool)) public tenantIssuers;

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

    error ZeroValue();
    error UnauthorizedIssuer(bytes32 tenantIdHash, address issuer);
    error CertificateAlreadyExists(bytes32 certificateId);
    error CertificateNotFound(bytes32 certificateId);
    error CertificateNotValid(bytes32 certificateId);
    error UnauthorizedRevoker(bytes32 certificateId, address caller);

    constructor(address initialAdmin, uint48 defaultAdminDelay)
        AccessControlDefaultAdminRules(defaultAdminDelay, initialAdmin)
    {
        if (initialAdmin == address(0)) revert ZeroValue();

        _grantRole(TENANT_MANAGER_ROLE, initialAdmin);
        _grantRole(GLOBAL_ISSUER_ROLE, initialAdmin);
        _grantRole(REVOCATOR_ROLE, initialAdmin);
        _grantRole(PAUSER_ROLE, initialAdmin);
    }

    /// @notice Abilita o disabilita un issuer/relayer per uno specifico tenant.
    /// @dev tenantIdHash deve essere un identificativo opaco, non il nome azienda.
    function setTenantIssuer(bytes32 tenantIdHash, address issuer, bool allowed)
        external
        onlyRole(TENANT_MANAGER_ROLE)
    {
        if (tenantIdHash == bytes32(0) || issuer == address(0)) revert ZeroValue();

        tenantIssuers[tenantIdHash][issuer] = allowed;

        emit TenantIssuerSet(tenantIdHash, issuer, allowed);
    }

    /// @notice Emette una certificazione documentale.
    /// @param tenantIdHash Hash opaco del tenant/azienda.
    /// @param externalRefHash Hash opaco della reference interna, es. UUID pratica/documento.
    /// @param documentCommitment Commitment del documento, preferibile a un hash raw pubblico.
    /// @param metadataCommitment Commitment opzionale di metadati off-chain.
    /// @return certificateId ID deterministico della certificazione.
    function issueCertificate(
        bytes32 tenantIdHash,
        bytes32 externalRefHash,
        bytes32 documentCommitment,
        bytes32 metadataCommitment
    ) external whenNotPaused returns (bytes32 certificateId) {
        if (tenantIdHash == bytes32(0) || externalRefHash == bytes32(0) || documentCommitment == bytes32(0)) {
            revert ZeroValue();
        }

        bool allowed = hasRole(GLOBAL_ISSUER_ROLE, msg.sender) || tenantIssuers[tenantIdHash][msg.sender];

        if (!allowed) {
            revert UnauthorizedIssuer(tenantIdHash, msg.sender);
        }

        certificateId = keccak256(abi.encode(block.chainid, address(this), tenantIdHash, externalRefHash));

        if (_certificates[certificateId].status != Status.None) {
            revert CertificateAlreadyExists(certificateId);
        }

        uint64 issuedAt = uint64(block.timestamp);

        _certificates[certificateId] = Certificate({
            tenantIdHash: tenantIdHash,
            externalRefHash: externalRefHash,
            documentCommitment: documentCommitment,
            metadataCommitment: metadataCommitment,
            issuer: msg.sender,
            issuedAt: issuedAt,
            revokedAt: 0,
            status: Status.Valid
        });

        emit CertificateIssued(
            certificateId, tenantIdHash, documentCommitment, externalRefHash, metadataCommitment, msg.sender, issuedAt
        );
    }

    /// @notice Revoca una certificazione.
    /// @dev reasonCommitment deve essere un hash/commitment, non una motivazione in chiaro.
    function revokeCertificate(bytes32 certificateId, bytes32 reasonCommitment) external whenNotPaused {
        Certificate storage cert = _certificates[certificateId];

        if (cert.status == Status.None) {
            revert CertificateNotFound(certificateId);
        }

        if (cert.status != Status.Valid) {
            revert CertificateNotValid(certificateId);
        }

        bool allowed = msg.sender == cert.issuer || hasRole(REVOCATOR_ROLE, msg.sender);

        if (!allowed) {
            revert UnauthorizedRevoker(certificateId, msg.sender);
        }

        uint64 revokedAt = uint64(block.timestamp);

        cert.status = Status.Revoked;
        cert.revokedAt = revokedAt;

        emit CertificateRevoked(certificateId, cert.tenantIdHash, reasonCommitment, msg.sender, revokedAt);
    }

    /// @notice Verifica se un documento corrisponde a una certificazione valida.
    function verifyCertificate(bytes32 certificateId, bytes32 documentCommitment) external view returns (bool) {
        Certificate storage cert = _certificates[certificateId];

        return cert.status == Status.Valid && cert.documentCommitment == documentCommitment;
    }

    function getCertificate(bytes32 certificateId) external view returns (Certificate memory) {
        return _certificates[certificateId];
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
