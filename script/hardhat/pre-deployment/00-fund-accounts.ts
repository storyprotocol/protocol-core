import * as ethers from "ethers"
import hre from "hardhat"

require("dotenv").config()

import { USERS } from "../utils/constants"

async function runFundAccounts() {
  const provider = new ethers.JsonRpcProvider((hre.network.config as { url: string }).url)

  if (!process.env.MAINNET_DEPLOYER_ADDRESS) throw new Error("MAINNET_DEPLOYER_ADDRESS not set")
  const wallets: string[] = [
    process.env.MAINNET_DEPLOYER_ADDRESS as string,
    USERS.ALICE,
    USERS.BOB,
    USERS.CARL,
    USERS.EVE,
  ]

  await provider.send("tenderly_setBalance", [
    wallets,
    // amount in wei will be set for ALL wallets
    ethers.toQuantity(ethers.parseUnits("10000", "ether")),
  ])

  for (const wallet of wallets) {
    const balance = await provider.getBalance(wallet)
    console.log(`Balance of ${wallet} is ${ethers.formatEther(balance)}`)
  }
}

runFundAccounts().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
