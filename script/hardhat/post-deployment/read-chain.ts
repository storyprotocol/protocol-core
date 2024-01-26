import {
  JsonRpcProvider,
  type AddressLike,
  type BaseContract,
  type BytesLike,
  type ContractTransactionReceipt,
  type EventLog,
	keccak256,
	hexlify,
} from "ethers"
import hre from "hardhat"

import * as deployedAll from "../../out/all.json"
import { type DeployedContracts, getDeployedContracts } from "../utils/deployed"
import { MockAsset } from "../utils/mock-assets"
import { Licensing } from "../../../typechain/contracts/registries/LicenseRegistry"

async function runReadChain() {
  const { deployments, getNamedAccounts, network, ethers } = hre
  const { deployer } = await getNamedAccounts()
  const deployerSigner = await ethers.getSigner(deployer)
  const chainId = network.config.chainId as number

  const provider = new JsonRpcProvider((network.config as { url: string }).url)

  const c = getDeployedContracts(deployerSigner)

  const txHash = "0xd8f41fad8851dc30d92d7fd4566d4c9280d02f01089f186326ccf9c8cddb483e"
  const receipt = await provider.getTransactionReceipt(txHash) as ContractTransactionReceipt

	const topicHash = keccak256(hexlify("IPAccountRegistered(address,address,uint256,address,address)"))

	console.log('topicHash', topicHash)

  console.dir(receipt.logs)
  // console.log("====================================")

}

runReadChain().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
