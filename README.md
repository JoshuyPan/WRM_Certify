### DEPLOY
```
forge script script/Deploy.s.sol:Deploy --fork-url $RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### CERTIFICATION FLOW

Il backend .NET invia al contratto il contenuto integrale del file come `byte[]` chiamando:

```solidity
certify(bytes documentContent)
```

Il contratto calcola `keccak256(documentContent)`, registra la certificazione ed emette:

```solidity
Certified(bytes32 indexed documentHash, uint256 certifiedAt, address indexed certifiedBy, uint256 chainIdAtWrite)
```

Con Nethereum salva nel DB `documentHash` decodificato dall'evento e la transaction hash della receipt.
