# Corners Of Space NFT Contract

## Deploying Contract

### 1) Install dependencies:

```shell
npm i
```

### 2) Fill In .env

- Create .env file
- Copy .env.example in it
- Double check pre-filled fields if they qualify your needs and wants
- Fill missing fields

### 3) Deploy

Current config let's you deploy on 2 chains: BSC Mainnet and BSC Testnet.

To deploy NFT contract to testnet:

```shell
npx hardhat deploy --network bscTestnet
```

To deploy NFT contract to testnet:

```shell
npx hardhat deploy --network bscMainnet
```

### Testing

```shell
npx hardhat test
```
