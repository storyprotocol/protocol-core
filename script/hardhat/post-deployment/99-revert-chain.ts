import { JsonRpcProvider } from "ethers"
import hre from "hardhat"
import { DeployResult, DeployOptions } from "hardhat-deploy/dist/types"

import * as checkpointJson from "../../out/checkpoint.json"

async function revertChainToCheckpoint() {
  const provider = new JsonRpcProvider((hre.network.config as { url: string }).url)
  const checkpoint = checkpointJson.checkpoint

  await provider.send("evm_revert", [checkpoint])

  console.log(`Reverted to checkpoint: ${checkpoint}`)
}

revertChainToCheckpoint().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
