### DEPLOY
```
forge script script/Deploy.s.sol:Deploy --fork-url $RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### CERTIFICATION FLOW

Il backend .NET calcola off-chain hash/commitment opachi e invia al contratto solo valori `bytes32`, chiamando:

```solidity
issueCertificate(
    bytes32 tenantIdHash,
    bytes32 externalRefHash,
    bytes32 documentCommitment,
    bytes32 metadataCommitment
)
```

Il contratto registra issuer, timestamp e stato della certificazione ed emette:

```solidity
CertificateIssued(
    bytes32 indexed certificateId,
    bytes32 indexed tenantIdHash,
    bytes32 indexed documentCommitment,
    bytes32 externalRefHash,
    bytes32 metadataCommitment,
    address issuer,
    uint64 issuedAt
)
```

Con Nethereum salva nel DB `certificateId` decodificato dall'evento e la transaction hash della receipt.
