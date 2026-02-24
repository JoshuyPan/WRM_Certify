# WRMDocumentCertificationRegistry - Backend Integration (Variant)

## Contract
- Name: `WRMDocumentCertificationRegistry`
- Source: `src/WRMDocumentCertificationRegistry.sol`
- Solidity: `^0.8.24`

## Purpose
Registra certificazioni documentali con:
- hash tecnici (`documentHash`, `requesterIdHash`, `documentIdHash`)
- metadati leggibili (`companyId`, `companyName`, `documentName`, `documentType`)
- catalogazione per azienda (`companyId`) con query `GET` on-chain.

## Document Types
Enum on-chain:
- `0`: `MedicalCertificate`
- `1`: `Training`
- `2`: `Audit`

## Roles
- `DEFAULT_ADMIN_ROLE`: gestisce grant/revoke dei relayer.
- `RELAYER_ROLE`: può chiamare `certify`.

## Write Function
```solidity
function certify(
    bytes32 documentHash,
    bytes32 requesterIdHash,
    bytes32 documentIdHash,
    string calldata companyId,
    string calldata companyName,
    string calldata documentName,
    uint8 documentType
) external onlyRole(RELAYER_ROLE);
```

Validazioni:
- `documentHash != 0`
- `requesterIdHash != 0`
- `documentIdHash != 0`
- `companyId` non vuoto
- `companyName` non vuoto
- `documentName` non vuoto
- `documentType` in `[0..2]`
- `documentHash` non già certificato

## Read Functions
```solidity
function isCertified(bytes32 documentHash) external view returns (bool);
```

```solidity
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
    );
```

```solidity
function getCompanyDocumentCount(string calldata companyId)
    external
    view
    returns (uint256);
```

```solidity
function getCompanyDocumentHashes(
    string calldata companyId,
    uint256 offset,
    uint256 limit
) external view returns (bytes32[] memory documentHashes);
```

```solidity
function getCompanyCertifications(
    string calldata companyId,
    uint256 offset,
    uint256 limit
) external view returns (CertificationRecord[] memory records);
```

Note paginazione:
- `MAX_PAGE_SIZE = 100`
- Se `limit == 0` o `limit > 100`, viene usato `100`.
- Se `offset >= total`, ritorna array vuoto.

## Returned Record Schema
`CertificationRecord`:
- `documentHash: bytes32`
- `companyId: string`
- `companyName: string`
- `documentName: string`
- `documentType: enum (0/1/2)`
- `requesterIdHash: bytes32`
- `documentIdHash: bytes32`
- `certifiedAt: uint256` (unix timestamp)
- `certifiedBy: address` (relayer WRM)
- `chainIdAtWrite: uint256`

## Event
```solidity
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
```

`companyIdHash = keccak256(bytes(companyId))`.

## Custom Errors
- `InvalidDocumentHash()`
- `InvalidRequesterIdHash()`
- `InvalidDocumentIdHash()`
- `InvalidCompanyId()`
- `InvalidCompanyName()`
- `InvalidDocumentName()`
- `InvalidDocumentType()`
- `DocumentAlreadyCertified(bytes32 documentHash)`
- `AccessControlUnauthorizedAccount(address account, bytes32 neededRole)` (OpenZeppelin)

## Selectors / Topic
Function selectors:
- `certify(bytes32,bytes32,bytes32,string,string,string,uint8)` -> `0xbeee0efb`
- `isCertified(bytes32)` -> `0x964c6790`
- `getCertification(bytes32)` -> `0x1fb25f07`
- `getCompanyDocumentCount(string)` -> `0x55705ac0`
- `getCompanyDocumentHashes(string,uint256,uint256)` -> `0xfa565b58`
- `getCompanyCertifications(string,uint256,uint256)` -> `0xd7829b34`

Event topic0:
- `Certified(bytes32,bytes32,bytes32,bytes32,string,string,string,uint8,uint256,address)`
- topic0 value: `0x16678c9402ecbe764c9730942616162c00e91e0a4b9304da6e422ea538df2827`

## Off-chain Hash Rules (Backend)
- `documentHash = keccak256(file bytes)`
- `requesterIdHash = keccak256(tenantId + userId + salt)`
- `documentIdHash = keccak256(documentId + salt)`

Usa regole deterministiche stabili in tutti gli ambienti.

## Suggested .NET AppSettings
```json
{
  "Blockchain": {
    "Enabled": true,
    "RpcUrl": "https://...",
    "ChainId": 11155111,
    "ContractAddress": "0x...",
    "RelayerPrivateKey": "..."
  }
}
```

## Backend Flow
1. Calcola hash input.
2. `isCertified(documentHash)` opzionale per idempotenza applicativa.
3. Invia `certify(...)` firmata dal relayer.
4. Attendi receipt.
5. Decodifica `Certified`.
6. Per pagina riepilogo azienda, usa:
- `getCompanyDocumentCount(companyId)`
- `getCompanyCertifications(companyId, offset, limit)` in loop paginato.

## Important
- Se questa variante sostituisce la versione precedente, backend/frontend devono aggiornare ABI e firma `certify`.
- Le query complete per azienda sono disponibili on-chain ma hanno costo gas/storage maggiore rispetto alla versione hash-only.
