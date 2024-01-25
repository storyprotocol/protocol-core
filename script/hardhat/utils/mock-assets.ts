import { Contract, ContractTransactionReceipt } from "ethers"
import { DeployResult } from "hardhat-deploy/dist/types"
import * as fs from "fs"
import * as path from "path"

import * as mockTokens from "../../out/mock/tokens.json"
import { MockERC20, MockERC20__factory, MockERC721, MockERC721__factory } from "../../../typechain"

const erc721MintAbi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
    ],
    name: "mint",
    outputs: [
      {
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
    ],
    payable: false,
    stateMutability: "nonpayable",
    type: "function",
  },
]

export class MockAsset {
  public MockToken: MockERC20
  public MockNFT: MockERC721
  public addr: { MockToken: string; MockNFT: string }

  private deployerSigner: any

  constructor(deployerSigner: any) {
    this.deployerSigner = deployerSigner
    this.MockToken = MockERC20__factory.connect(mockTokens.MockToken, deployerSigner)
    this.MockNFT = MockERC721__factory.connect(mockTokens.MockNFT, deployerSigner)

    this.addr = {
      MockToken: mockTokens.MockToken,
      MockNFT: mockTokens.MockNFT,
    }
  }

  static async deploy(deployFn: any, deployer: string, deployerSigner: any) {
    let deployRes: DeployResult

    deployRes = await deployFn("MockERC20", {
      from: deployer,
      log: true,
      waitConfirmations: 1,
    })
    const MockToken = MockERC20__factory.connect(deployRes.address, deployerSigner)
    await MockToken.waitForDeployment()

    deployRes = await deployFn("MockERC721", {
      from: deployer,
      log: true,
      waitConfirmations: 1,
    })
    const MockNFT = MockERC721__factory.connect(deployRes.address, deployerSigner)
    await MockNFT.waitForDeployment()

    // save MockToken and MockNFT addresses to json in this folder
    const outMockPath = path.join(__dirname, "../../out/mock")
    const mockPath = path.join(outMockPath, "tokens.json")
    const mock = { MockToken: await MockToken.getAddress(), MockNFT: await MockNFT.getAddress() }
    fs.writeFileSync(mockPath, JSON.stringify(mock, null, 2))

    return new MockAsset(deployerSigner)
  }

  async mint20(recipient: string, amount: number): Promise<bigint> {
    const decimals = BigInt(await this.MockToken.decimals())
    const txRes = await this.MockToken.mint(recipient, BigInt(amount) * decimals)
    await txRes.wait()
    return this.MockToken.balanceOf(recipient)
  }

  async mint721(recipient: string): Promise<bigint> {
    const tokenAddr = await this.MockNFT.getAddress()
    const txRes = await this.MockNFT.mint(recipient)
    const receipt = (await txRes.wait()) as ContractTransactionReceipt

    // get token ID from the receipt
    const newTokenId = receipt.logs?.[0].topics?.[3]
    if (!newTokenId) throw new Error("tokenId not found in receipt")

    return BigInt(newTokenId)
  }
}
