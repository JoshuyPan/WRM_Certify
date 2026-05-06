# WRMDocumentCertificationRegistry - Backend Integration

## Contract
- Name: `WRMDocumentCertificationRegistry`
- Source: `src/WRMDocumentCertificationRegistry.sol`
- Solidity: `^0.8.24`

## Purpose
Certifica documenti ricevendo dal backend il contenuto integrale del file come `bytes`.

Il contratto:
- calcola `documentHash = keccak256(documentContent)` on-chain
- registra timestamp, relayer e chain id
- impedisce una seconda certificazione dello stesso contenuto
- emette l'evento `Certified`, leggibile dalla receipt della transazione

Nota importante: il valore `return` di una funzione chiamata via transazione non viene esposto nella transaction receipt Ethereum. Per il backend .NET/Nethereum il dato affidabile da salvare e mostrare su Etherscan e' il `documentHash` emesso nell'evento `Certified`.

## Roles
- `DEFAULT_ADMIN_ROLE`: gestisce grant/revoke dei relayer.
- `RELAYER_ROLE`: puo' chiamare `certify`.

## Write Function
```solidity
function certify(bytes calldata documentContent)
    external
    onlyRole(RELAYER_ROLE)
    returns (bytes32 documentHash);
```

Validazioni:
- `documentContent.length > 0`
- `documentHash` non gia' certificato

## Utility Hash Function
```solidity
function hashDocument(bytes calldata documentContent)
    external
    pure
    returns (bytes32 documentHash);
```

Utile per verifiche applicative tramite `eth_call` senza scrivere on-chain.

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
        uint256 certifiedAt,
        address certifiedBy,
        uint256 chainIdAtWrite
    );
```

```solidity
function getCertificationCount() external view returns (uint256);
```

```solidity
function getDocumentHashes(uint256 offset, uint256 limit)
    external
    view
    returns (bytes32[] memory documentHashes);
```

```solidity
function getCertifications(uint256 offset, uint256 limit)
    external
    view
    returns (CertificationRecord[] memory records);
```

Note paginazione:
- `MAX_PAGE_SIZE = 100`
- Se `limit == 0` o `limit > 100`, viene usato `100`.
- Se `offset >= total`, ritorna array vuoto.

## Returned Record Schema
`CertificationRecord`:
- `documentHash: bytes32`
- `certifiedAt: uint256` unix timestamp
- `certifiedBy: address` relayer WRM
- `chainIdAtWrite: uint256`

## Event
```solidity
event Certified(
    bytes32 indexed documentHash,
    uint256 certifiedAt,
    address indexed certifiedBy,
    uint256 chainIdAtWrite
);
```

Il backend deve decodificare questo evento dalla receipt e salvare:
- `documentHash`
- transaction hash della transazione

## Custom Errors
- `EmptyDocumentContent()`
- `DocumentAlreadyCertified(bytes32 documentHash)`
- `AccessControlUnauthorizedAccount(address account, bytes32 neededRole)` OpenZeppelin

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
1. Leggi lo stream del file in `byte[]`.
2. Invia `certify(byte[] documentContent)` firmata dal relayer.
3. Attendi la receipt.
4. Decodifica l'evento `Certified`.
5. Salva nel DB aziendale `documentHash` e transaction hash.
6. Nel frontend crea il link a Etherscan usando la transaction hash.

## Security / Cost Notes
- Il contenuto del file inviato come calldata e' pubblico e visibile a chiunque indicizzi la chain.
- Inviare file interi on-chain puo' costare molto gas; per file grandi la transazione puo' superare i limiti di block gas.
- Se i documenti sono riservati, l'approccio piu' sicuro resta calcolare l'hash nel backend e inviare solo `bytes32`.
