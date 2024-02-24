
# Story Protocol Beta

Story Protocol is building the Programmable IP layer to bring programmability to IP. Story Protocol transforms IPs into networks that transcend mediums and platforms, unleashing global creativity and liquidity. Instead of static JPEGs that lack interactivity and composability with other assets, programmable IPs are dynamic and extensible: built to be built upon. Creators and applications can register their IP with Story Protocol, converting their static IP into programmable IP by declaring a set of onchain rights that any program can read and write on.

# Documentation

[Learn more about Story Protocol](https://docs.storyprotocol.xyz/)


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
-   `SEPOLIA_URL`
-   `SEPOLIA_PRIVATEKEY`
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

# Licensing

The license for Story Protocol Core is the Business Source License 1.1 (BUSL-1.1), see LICENSE."

In the terms of service with your End Users, governing your End Users’ use of and access to your App, you will include the following sentence:
“This application is integrated with functionality provided by Story Protocol, Inc that enables intellectual property registration and tracking. You acknowledge and agree that such functionality and your use of this application is subject to Story Protocol, Inc.’s End User Terms."


# Document Generation

We use [solidity-docgen](https://github.com/OpenZeppelin/solidity-docgen) to generate the documents for smart contracts. Documents can be generated with the following command:

```
npx hardhat docgen
```

By default, the documents are generated in Markdown format in the `doc` folder of the project. Each Solidity file (`*.sol`) has its own Markdown (`*.md`) file. To update the configuration for document generation, you can update the following section in `harhat.config.js`:

```
docgen: {
  outputDir: "./docs",
  pages: "files"
}
```

You can refer to the [config.ts](https://github.com/OpenZeppelin/solidity-docgen/blob/master/src/config.ts) of solidity-docgen for the full list of configurable parameters.

# Resources
-   [Hardhat](https://hardhat.org/docs)
-   [Foundry Documentation](https://book.getfoundry.sh/)
-   [Yarn](https://yarnpkg.com/getting-started)

# Official Links
- [Website](https://storyprotocol.xyz)
- [Twitter/X](https://twitter.com/storyprotocol)
- [Discord](https://discord.gg/storyprotocol)
