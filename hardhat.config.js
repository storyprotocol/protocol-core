require("dotenv").config()
require("hardhat-deploy")

require("@nomiclabs/hardhat-etherscan")
require("@nomiclabs/hardhat-waffle")
require("hardhat-gas-reporter")
require("solidity-coverage")
require("@nomiclabs/hardhat-ethers")
require("@nomiclabs/hardhat-etherscan")
require("@openzeppelin/hardhat-upgrades")

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
// eslint-disable-next-line no-undef
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners()

    for (const account of accounts) {
        console.log(account.address)
    }
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    networks: {
        mainnet: {
            url: process.env.MAINNET_URL || "",
            chainId: 1,
            accounts: [
                process.env.MAINNET_PRIVATEKEY ||
                    "0x1234567890123456789012345678901234567890123456789012345678901234",
            ],
        },
        goerli: {
            url: process.env.GOERLI_URL || "",
            chainId: 5,
            accounts: [
                process.env.GOERLI_PRIVATEKEY ||
                    "0x1234567890123456789012345678901234567890123456789012345678901234",
            ],
        },
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS !== undefined,
        currency: "USD",
    },
    solidity: {
        version: "0.8.18",
        settings: {
            optimizer: {
                enabled: true,
                runs: 2000,
            },
        },
    },
    etherscan: {
        apiKey: `${process.env.ETHERSCAN_API_KEY}`,
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts",
    },
    mocha: {
        timeout: 20000,
    },
}
