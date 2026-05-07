# WorkforceDocumentRegistry - Backend Integration

## Contract
- Name: `WorkforceDocumentRegistry`
- Source: `src/WRMDocumentCertificationRegistry.sol`
- Solidity: `^0.8.24`

## Purpose
Certifica documenti salvando on-chain solo identificativi e commitment opachi.

Il contratto:
- registra `tenantIdHash`, `externalRefHash`, `documentCommitment` e `metadataCommitment`
- calcola un `certificateId` deterministico
- impedisce duplicati per stessa coppia tenant/reference
- consente revoca e verifica dello stato
- non richiede di inviare il contenuto del file in calldata

## Roles
- `DEFAULT_ADMIN_ROLE`: gestisce ruoli amministrativi.
- `TENANT_MANAGER_ROLE`: abilita o disabilita issuer per tenant.
- `GLOBAL_ISSUER_ROLE`: puo' emettere certificati per qualsiasi tenant.
- `REVOCATOR_ROLE`: puo' revocare certificati.
- `PAUSER_ROLE`: puo' mettere in pausa emissione e revoca.

## Constructor
```solidity
constructor(address initialAdmin, uint48 defaultAdminDelay)
```

## Issuer Management
```solidity
function setTenantIssuer(bytes32 tenantIdHash, address issuer, bool allowed)
    external
    onlyRole(TENANT_MANAGER_ROLE);
```

## Write Functions
```solidity
function issueCertificate(
    bytes32 tenantIdHash,
    bytes32 externalRefHash,
    bytes32 documentCommitment,
    bytes32 metadataCommitment
)
    external
    whenNotPaused
    returns (bytes32 certificateId);
```

Validazioni:
- `tenantIdHash != bytes32(0)`
- `externalRefHash != bytes32(0)`
- `documentCommitment != bytes32(0)`
- chiamante con `GLOBAL_ISSUER_ROLE` o abilitato per il tenant
- certificato non gia' esistente

```solidity
function revokeCertificate(bytes32 certificateId, bytes32 reasonCommitment)
    external
    whenNotPaused;
```

La revoca e' consentita all'issuer originale o a un account con `REVOCATOR_ROLE`.

## Read Functions
```solidity
function verifyCertificate(bytes32 certificateId, bytes32 documentCommitment)
    external
    view
    returns (bool);
```

```solidity
function getCertificate(bytes32 certificateId)
    external
    view
    returns (Certificate memory);
```

## Returned Record Schema
`Certificate`:
- `tenantIdHash: bytes32`
- `externalRefHash: bytes32`
- `documentCommitment: bytes32`
- `metadataCommitment: bytes32`
- `issuer: address`
- `issuedAt: uint64`
- `revokedAt: uint64`
- `status: Status`

`Status`:
- `None`
- `Valid`
- `Revoked`

## Events
```solidity
event TenantIssuerSet(bytes32 indexed tenantIdHash, address indexed issuer, bool allowed);
```

```solidity
event CertificateIssued(
    bytes32 indexed certificateId,
    bytes32 indexed tenantIdHash,
    bytes32 indexed documentCommitment,
    bytes32 externalRefHash,
    bytes32 metadataCommitment,
    address issuer,
    uint64 issuedAt
);
```

```solidity
event CertificateRevoked(
    bytes32 indexed certificateId,
    bytes32 indexed tenantIdHash,
    bytes32 reasonCommitment,
    address revoker,
    uint64 revokedAt
);
```

## Custom Errors
- `ZeroValue()`
- `UnauthorizedIssuer(bytes32 tenantIdHash, address issuer)`
- `CertificateAlreadyExists(bytes32 certificateId)`
- `CertificateNotFound(bytes32 certificateId)`
- `CertificateNotValid(bytes32 certificateId)`
- `UnauthorizedRevoker(bytes32 certificateId, address caller)`
- `AccessControlUnauthorizedAccount(address account, bytes32 neededRole)` OpenZeppelin

## Suggested .NET AppSettings
```json
{
  "Blockchain": {
    "Enabled": true,
    "RpcUrl": "https://...",
    "ChainId": 11155111,
    "ContractAddress": "0x...",
    "IssuerPrivateKey": "..."
  }
}
```

## Backend Flow
1. Calcola off-chain `tenantIdHash`, `externalRefHash`, `documentCommitment` e, se serve, `metadataCommitment`.
2. Invia `issueCertificate(...)` firmata dall'issuer autorizzato.
3. Attendi la receipt.
4. Decodifica l'evento `CertificateIssued`.
5. Salva nel DB aziendale `certificateId`, commitment e transaction hash.
6. Nel frontend crea il link a Etherscan usando la transaction hash.

## Security / Cost Notes
- Non inviare dati personali, sanitari o contenuti file in chiaro on-chain.
- Usare commitment con salt rende piu' difficile correlare documenti prevedibili.
- `externalRefHash` deve essere opaco e non deve rivelare UUID o riferimenti interni in chiaro.
