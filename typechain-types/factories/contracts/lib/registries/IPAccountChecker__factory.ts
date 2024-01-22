/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  Contract,
  ContractFactory,
  ContractTransactionResponse,
  Interface,
} from "ethers";
import type { Signer, ContractDeployTransaction, ContractRunner } from "ethers";
import type { NonPayableOverrides } from "../../../../common";
import type {
  IPAccountChecker,
  IPAccountCheckerInterface,
} from "../../../../contracts/lib/registries/IPAccountChecker";

const _abi = [
  {
    inputs: [
      {
        internalType: "contract IIPAccountRegistry",
        name: "ipAccountRegistry_",
        type: "IIPAccountRegistry",
      },
      {
        internalType: "address",
        name: "ipAccountAddress_",
        type: "address",
      },
    ],
    name: "isIpAccount",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "contract IIPAccountRegistry",
        name: "ipAccountRegistry_",
        type: "IIPAccountRegistry",
      },
      {
        internalType: "uint256",
        name: "chainId_",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "tokenContract_",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId_",
        type: "uint256",
      },
    ],
    name: "isRegistered",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
] as const;

const _bytecode =
  "0x6107b5610053600b82828239805160001a607314610046577f4e487b7100000000000000000000000000000000000000000000000000000000600052600060045260246000fd5b30600052607381538281f3fe73000000000000000000000000000000000000000030146080604052600436106100405760003560e01c80635a1c2dd714610045578063b43f0ea514610075575b600080fd5b61005f600480360381019061005a9190610517565b6100a5565b60405161006c9190610572565b60405180910390f35b61008f600480360381019061008a91906105c3565b6102c1565b60405161009c9190610572565b60405180910390f35b60008073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff16036100e357600090506102bb565b60008273ffffffffffffffffffffffffffffffffffffffff163b0361010b57600090506102bb565b61011482610365565b61012157600090506102bb565b61014b827f6faff5f1000000000000000000000000000000000000000000000000000000006103b2565b61015857600090506102bb565b610182827f3bb8ecad000000000000000000000000000000000000000000000000000000006103b2565b61018f57600090506102bb565b60008060008473ffffffffffffffffffffffffffffffffffffffff1663fc0c546a6040518163ffffffff1660e01b8152600401606060405180830381865afa1580156101df573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906102039190610654565b9250925092508573ffffffffffffffffffffffffffffffffffffffff166387020f958484846040518463ffffffff1660e01b8152600401610246939291906106c5565b602060405180830381865afa158015610263573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061028791906106fc565b73ffffffffffffffffffffffffffffffffffffffff168573ffffffffffffffffffffffffffffffffffffffff161493505050505b92915050565b6000808573ffffffffffffffffffffffffffffffffffffffff166387020f958686866040518463ffffffff1660e01b8152600401610301939291906106c5565b602060405180830381865afa15801561031e573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061034291906106fc565b73ffffffffffffffffffffffffffffffffffffffff163b14159050949350505050565b6000610391827f01ffc9a7000000000000000000000000000000000000000000000000000000006103d7565b80156103ab57506103a98263ffffffff60e01b6103d7565b155b9050919050565b60006103bd83610365565b80156103cf57506103ce83836103d7565b5b905092915050565b600080826040516024016103eb9190610764565b6040516020818303038152906040526301ffc9a760e01b6020820180517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff838183161783525050505090506000806000602060008551602087018a617530fa92503d9150600051905082801561045e575060208210155b801561046a5750600081115b94505050505092915050565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006104a68261047b565b9050919050565b60006104b88261049b565b9050919050565b6104c8816104ad565b81146104d357600080fd5b50565b6000813590506104e5816104bf565b92915050565b6104f48161049b565b81146104ff57600080fd5b50565b600081359050610511816104eb565b92915050565b6000806040838503121561052e5761052d610476565b5b600061053c858286016104d6565b925050602061054d85828601610502565b9150509250929050565b60008115159050919050565b61056c81610557565b82525050565b60006020820190506105876000830184610563565b92915050565b6000819050919050565b6105a08161058d565b81146105ab57600080fd5b50565b6000813590506105bd81610597565b92915050565b600080600080608085870312156105dd576105dc610476565b5b60006105eb878288016104d6565b94505060206105fc878288016105ae565b935050604061060d87828801610502565b925050606061061e878288016105ae565b91505092959194509250565b60008151905061063981610597565b92915050565b60008151905061064e816104eb565b92915050565b60008060006060848603121561066d5761066c610476565b5b600061067b8682870161062a565b935050602061068c8682870161063f565b925050604061069d8682870161062a565b9150509250925092565b6106b08161058d565b82525050565b6106bf8161049b565b82525050565b60006060820190506106da60008301866106a7565b6106e760208301856106b6565b6106f460408301846106a7565b949350505050565b60006020828403121561071257610711610476565b5b60006107208482850161063f565b91505092915050565b60007fffffffff0000000000000000000000000000000000000000000000000000000082169050919050565b61075e81610729565b82525050565b60006020820190506107796000830184610755565b9291505056fea26469706673582212201697df2a793cbfd8086cbe8f219d7566d3f997e92153041e28e2bb30ec2dd49a64736f6c63430008170033";

type IPAccountCheckerConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: IPAccountCheckerConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class IPAccountChecker__factory extends ContractFactory {
  constructor(...args: IPAccountCheckerConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override getDeployTransaction(
    overrides?: NonPayableOverrides & { from?: string }
  ): Promise<ContractDeployTransaction> {
    return super.getDeployTransaction(overrides || {});
  }
  override deploy(overrides?: NonPayableOverrides & { from?: string }) {
    return super.deploy(overrides || {}) as Promise<
      IPAccountChecker & {
        deploymentTransaction(): ContractTransactionResponse;
      }
    >;
  }
  override connect(runner: ContractRunner | null): IPAccountChecker__factory {
    return super.connect(runner) as IPAccountChecker__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): IPAccountCheckerInterface {
    return new Interface(_abi) as IPAccountCheckerInterface;
  }
  static connect(
    address: string,
    runner?: ContractRunner | null
  ): IPAccountChecker {
    return new Contract(address, _abi, runner) as unknown as IPAccountChecker;
  }
}
