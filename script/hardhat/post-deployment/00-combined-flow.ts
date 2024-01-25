import type { AddressLike, BytesLike, ContractTransactionReceipt } from "ethers"
import hre from "hardhat"
import { DeployResult } from "hardhat-deploy/dist/types"

import * as deployedAll from "../../out/all.json"
import { type DeployedContracts, getDeployedContracts } from "../utils/deployed"
import { MockAsset } from "../utils/mock-assets"
import { Licensing } from "../../../typechain/contracts/registries/LicenseRegistry"

async function runCombinedFlow() {
  const { deployments, getNamedAccounts, network, ethers } = hre
  const { deployer } = await getNamedAccounts()
  const deployerSigner = await ethers.getSigner(deployer)
  const chainId = network.config.chainId as number

  const c = getDeployedContracts(deployerSigner)
  const ma = new MockAsset(deployerSigner)

  await ma.mint20(deployer, 100)
  let tokenId = await ma.mint721(deployer)

  // grant access control
  // register IPAccount through registration module
  _createLicenseFrameworks(c, {
		licenseUrl: "https://example.com/license/{id}.json",
	})
  // create policy from framework
  // attach policy to IPAccount
  // mint licenses
  // link IPAccounts to parents using licenses

  let tx = await c.IPRecordRegistry.createIPAccount(chainId, ma.addr.MockNFT, tokenId)
  console.log(tx)
}

interface CreateLicenseFrameworkParams {
	minting?: {
		paramVerifiers: AddressLike[]
		paramDefaultValues: BytesLike[]
	}
	activation?: {
		paramVerifiers: AddressLike[]
		paramDefaultValues: BytesLike[]
	}
	linkParent?: {
		paramVerifiers: AddressLike[]
		paramDefaultValues: BytesLike[]
	}
	defaultNeedsActivation?: boolean
	licenseUrl: string
}

async function _createLicenseFrameworks(c: DeployedContracts, p: CreateLicenseFrameworkParams) {
  const fwParams: Licensing.FrameworkCreationParamsStruct = {
    mintingParamVerifiers: p.minting?.paramVerifiers || [],
    mintingParamDefaultValues: p.minting?.paramDefaultValues || [],
    activationParamVerifiers: p.activation?.paramVerifiers || [],
    activationParamDefaultValues: p.activation?.paramDefaultValues || [],
    defaultNeedsActivation: p.defaultNeedsActivation || false,
    linkParentParamVerifiers: p.linkParent?.paramVerifiers || [],
    linkParentParamDefaultValues: p.linkParent?.paramDefaultValues || [],
    licenseUrl: p.licenseUrl,
  }

  const txRes = await c.LicenseRegistry.addLicenseFramework(fwParams)
	const receipt = await txRes.wait() as ContractTransactionReceipt
	receipt.logs.find((l) => l.topics[0] === c.LicenseRegistry.interface.getEvent("LicenseFrameworkCreated").topicHash)
	const event = receipt.events?.find((e) => e.event === "LicenseFrameworkCreated")
}

runCombinedFlow().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
