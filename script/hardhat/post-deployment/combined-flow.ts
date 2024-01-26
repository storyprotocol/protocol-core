import type { AddressLike, BaseContract, BytesLike, ContractTransactionReceipt, EventLog } from "ethers"
import hre from "hardhat"

import * as deployedAll from "../../out/all.json"
import { type DeployedContracts, getDeployedContracts } from "../utils/deployed"
import { MockAsset } from "../utils/mock-assets"
import { Licensing } from "../../../typechain/contracts/registries/LicenseRegistry"
import { TypedEvent, TypedEventFilter } from "../utils/interfaces"

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
  const receipt = (await txRes.wait()) as ContractTransactionReceipt

  // c.LicenseRegistry.filters["LicenseFrameworkCreated(address,uint256,tuple)"]
  // const events = await c.LicenseRegistry.queryTransaction(txRes.hash)
  // c.LicenseRegistry.interface.parseLog(receipt.logs[0])
  // c.LicenseRegistry.interface.decodeEventLog("LicenseFrameworkCreated", receipt.logs[0].data, receipt.logs[0].topics)

  const events = receipt.logs.map((log) =>
    c.LicenseRegistry.interface.parseLog({ topics: log.topics as string[], data: log.data })
  )

  console.dir(receipt.logs)
  console.log("====================================")
  console.dir(events)
}

// export function matchEvents<TArgsArray extends any[], TArgsObject>(
//   events: EventLog[],
//   contract: BaseContract,
//   eventFilter: TypedEventFilter<TypedEvent<TArgsArray, TArgsObject>>
// ): TypedEvent<TArgsArray, TArgsObject>[] {
// 	const topics = eventFilter.topics || []
//   return events
//     .filter((ev) => matchTopics(topics, ev.topics))
//     .map((ev) => {
//       const args = contract.interface.parseLog(ev).args
//       const result: TypedEvent<TArgsArray, TArgsObject> = {
//         ...ev,
//         args: args as TArgsArray & TArgsObject,
//       }
//       return result
//     })
// }

// function matchTopics(filter: TopicFilter | undefined, value: Array<string>): boolean {
//   // Implement the logic for topic filtering as described here:
//   // https://docs.ethers.io/v5/concepts/events/#events--filters
//   if (!filter) {
//     return false
//   }
//   for (let i = 0; i < filter.length; i++) {
//     const f = filter[i]
//     const v = value[i]
//     if (typeof f == "string") {
//       if (f !== v) return false
//     } else {
//       if (f.indexOf(v) === -1) return false
//     }
//   }
//   return true
// }

runCombinedFlow().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
