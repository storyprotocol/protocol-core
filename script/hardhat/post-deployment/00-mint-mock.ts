import hre from "hardhat"

import * as mockAddresses from "../../out/mock.json"
import { MockERC20__factory, MockERC721__factory } from "../../../typechain"

async function runFlow() {
  const { getNamedAccounts, ethers } = hre
  const { deployer } = await getNamedAccounts()
  const deployerSigner = await ethers.getSigner(deployer)

  const MockToken = MockERC20__factory.connect(mockAddresses.MockToken, deployerSigner)
  const MockNFT = MockERC721__factory.connect(mockAddresses.MockNFT, deployerSigner)

  await MockToken.mint(deployer, 100 * (await MockToken.decimals()))
  await MockNFT.mint(deployer)
}

runFlow().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
