
# Solidity Template 

Support both [Foundry](https://github.com/gakonst/foundry) test and [Hardhat](https://hardhat.org/).

# Getting Started

## Requirements

Please install the following:

-   [Foundry / Foundryup](https://github.com/gakonst/foundry)
-   [Hardhat](https://hardhat.org/hardhat-runner/docs/getting-started#overview) 

And you probably already have `make` installed... but if not [try looking here.](https://askubuntu.com/questions/161104/how-do-i-install-make) and [here for MacOS](https://stackoverflow.com/questions/1469994/using-make-on-os-x)

## Quickstart

```sh
make # This installs the project's dependencies.
make test
```

## Testing

```
make test
```

or

```
forge test
```

# Deploying to a network

## Setup

You'll need to add the following variables to a `.env` file:

-   `MAINNET_URL`
-   `MAINNET_PRIVATEKEY`
-   `GOERLI_URL`
-   `GOERLI_PRIVATEKEY`
-   `ETHERSCAN_API_KEY`

## Deploying

```
make deploy-goerli
```


### Working with a local network

Foundry comes with local network [anvil](https://book.getfoundry.sh/anvil/index.html) baked in, and allows us to deploy to our local network for quick testing locally.

To start a local network run:

```
make anvil
```

This will spin up a local blockchain with a determined private key, so you can use the same private key each time.

# Code Style
We employed solhint to check code style.
To check code style with solhint run:
```
make lint
```
To re-format code with prettier run:
```
make format
```

# Security

We use slither, a popular security framework from [Trail of Bits](https://www.trailofbits.com/). To use slither, you'll first need to [install python](https://www.python.org/downloads/) and [install slither](https://github.com/crytic/slither#how-to-install).

Then, you can run:

```
make slither
```

And get your slither output.


## Resources
-   [Hardhat](https://hardhat.org/docs)
-   [Foundry Documentation](https://book.getfoundry.sh/)
-   [Yarn](https://yarnpkg.com/getting-started)

### TODO

[ ] Add support for sepolia chain 

