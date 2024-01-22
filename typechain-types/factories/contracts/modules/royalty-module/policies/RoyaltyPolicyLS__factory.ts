/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  Contract,
  ContractFactory,
  ContractTransactionResponse,
  Interface,
} from "ethers";
import type {
  Signer,
  AddressLike,
  ContractDeployTransaction,
  ContractRunner,
} from "ethers";
import type { NonPayableOverrides } from "../../../../../common";
import type {
  RoyaltyPolicyLS,
  RoyaltyPolicyLSInterface,
} from "../../../../../contracts/modules/royalty-module/policies/RoyaltyPolicyLS";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "_royaltyModule",
        type: "address",
      },
      {
        internalType: "address",
        name: "_liquidSplitFactory",
        type: "address",
      },
      {
        internalType: "address",
        name: "_liquidSplitMain",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "target",
        type: "address",
      },
    ],
    name: "AddressEmptyCode",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "AddressInsufficientBalance",
    type: "error",
  },
  {
    inputs: [],
    name: "FailedInnerCall",
    type: "error",
  },
  {
    inputs: [],
    name: "RoyaltyPolicyLS__NotRoyaltyModule",
    type: "error",
  },
  {
    inputs: [],
    name: "RoyaltyPolicyLS__ZeroLiquidSplitFactory",
    type: "error",
  },
  {
    inputs: [],
    name: "RoyaltyPolicyLS__ZeroLiquidSplitMain",
    type: "error",
  },
  {
    inputs: [],
    name: "RoyaltyPolicyLS__ZeroRoyaltyModule",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
    ],
    name: "SafeERC20FailedOperation",
    type: "error",
  },
  {
    inputs: [],
    name: "LIQUID_SPLIT_FACTORY",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "LIQUID_SPLIT_MAIN",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "ROYALTY_MODULE",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_account",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_withdrawETH",
        type: "uint256",
      },
      {
        internalType: "contract ERC20[]",
        name: "_tokens",
        type: "address[]",
      },
    ],
    name: "claimRoyalties",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_ipId",
        type: "address",
      },
      {
        internalType: "address",
        name: "_token",
        type: "address",
      },
      {
        internalType: "address[]",
        name: "_accounts",
        type: "address[]",
      },
      {
        internalType: "address",
        name: "_distributorAddress",
        type: "address",
      },
    ],
    name: "distributeFunds",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_ipId",
        type: "address",
      },
      {
        internalType: "bytes",
        name: "_data",
        type: "bytes",
      },
    ],
    name: "initPolicy",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_caller",
        type: "address",
      },
      {
        internalType: "address",
        name: "_ipId",
        type: "address",
      },
      {
        internalType: "address",
        name: "_token",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "_amount",
        type: "uint256",
      },
    ],
    name: "onRoyaltyPayment",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "ipId",
        type: "address",
      },
    ],
    name: "splitClones",
    outputs: [
      {
        internalType: "address",
        name: "splitClone",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
] as const;

const _bytecode =
  "0x60e06040523480156200001157600080fd5b50604051620019433803806200194383398181016040528101906200003791906200027b565b600073ffffffffffffffffffffffffffffffffffffffff168373ffffffffffffffffffffffffffffffffffffffff16036200009e576040517f25e1172a00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff160362000105576040517f281a770f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16036200016c576040517fef65d3a900000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b8273ffffffffffffffffffffffffffffffffffffffff1660808173ffffffffffffffffffffffffffffffffffffffff16815250508173ffffffffffffffffffffffffffffffffffffffff1660a08173ffffffffffffffffffffffffffffffffffffffff16815250508073ffffffffffffffffffffffffffffffffffffffff1660c08173ffffffffffffffffffffffffffffffffffffffff1681525050505050620002d7565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b6000620002438262000216565b9050919050565b620002558162000236565b81146200026157600080fd5b50565b60008151905062000275816200024a565b92915050565b60008060006060848603121562000297576200029662000211565b5b6000620002a78682870162000264565b9350506020620002ba8682870162000264565b9250506040620002cd8682870162000264565b9150509250925092565b60805160a05160c051611620620003236000396000818161037c01526105e901526000818161018901526102510152600081816101ad015281816103a001526104bc01526116206000f3fe608060405234801561001057600080fd5b50600436106100885760003560e01c806373b7ce281161005b57806373b7ce28146101015780637c8dc3a41461011f578063bf3221b71461013b578063ca6344bc1461016b57610088565b80631c184e1d1461008d5780631db874c4146100ab5780633c6940d5146100c75780635be8968b146100e5575b600080fd5b610095610187565b6040516100a2919061098f565b60405180910390f35b6100c560048036038101906100c09190610a4f565b6101ab565b005b6100cf61037a565b6040516100dc919061098f565b60405180910390f35b6100ff60048036038101906100fa9190610ae5565b61039e565b005b6101096104ba565b604051610116919061098f565b60405180910390f35b61013960048036038101906101349190610ba2565b6104de565b005b61015560048036038101906101509190610c2a565b6105b4565b604051610162919061098f565b60405180910390f35b61018560048036038101906101809190610cad565b6105e7565b005b7f000000000000000000000000000000000000000000000000000000000000000081565b7f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614610230576040517f66b6bc2f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60008060008085858101906102459190610fad565b935093509350935060007f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663d621faa9868686866040518563ffffffff1660e01b81526004016102ae94939291906111d7565b6020604051808303816000875af11580156102cd573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906102f1919061123f565b9050806000808a73ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055505050505050505050565b7f000000000000000000000000000000000000000000000000000000000000000081565b7f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614610423576040517f66b6bc2f00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b60008060008573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1690506104b38582848673ffffffffffffffffffffffffffffffffffffffff1661067e909392919063ffffffff16565b5050505050565b7f000000000000000000000000000000000000000000000000000000000000000081565b6000808673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663d3561ecd858585856040518563ffffffff1660e01b815260040161057b94939291906112f7565b600060405180830381600087803b15801561059557600080fd5b505af11580156105a9573d6000803e3d6000fd5b505050505050505050565b60006020528060005260406000206000915054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b7f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff16636e5f6919858585856040518563ffffffff1660e01b81526004016106469493929190611486565b600060405180830381600087803b15801561066057600080fd5b505af1158015610674573d6000803e3d6000fd5b5050505050505050565b6106fa848573ffffffffffffffffffffffffffffffffffffffff166323b872dd8686866040516024016106b3939291906114c6565b604051602081830303815290604052915060e01b6020820180517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff8381831617835250505050610700565b50505050565b600061072b828473ffffffffffffffffffffffffffffffffffffffff1661079790919063ffffffff16565b9050600081511415801561075057508080602001905181019061074e9190611535565b155b1561079257826040517f5274afe7000000000000000000000000000000000000000000000000000000008152600401610789919061098f565b60405180910390fd5b505050565b60606107a5838360006107ad565b905092915050565b6060814710156107f457306040517fcd7860590000000000000000000000000000000000000000000000000000000081526004016107eb919061098f565b60405180910390fd5b6000808573ffffffffffffffffffffffffffffffffffffffff16848660405161081d91906115d3565b60006040518083038185875af1925050503d806000811461085a576040519150601f19603f3d011682016040523d82523d6000602084013e61085f565b606091505b509150915061086f86838361087a565b925050509392505050565b60608261088f5761088a82610909565b610901565b600082511480156108b7575060008473ffffffffffffffffffffffffffffffffffffffff163b145b156108f957836040517f9996b3150000000000000000000000000000000000000000000000000000000081526004016108f0919061098f565b60405180910390fd5b819050610902565b5b9392505050565b60008151111561091c5780518082602001fd5b6040517f1425ea4200000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006109798261094e565b9050919050565b6109898161096e565b82525050565b60006020820190506109a46000830184610980565b92915050565b6000604051905090565b600080fd5b600080fd5b6109c78161096e565b81146109d257600080fd5b50565b6000813590506109e4816109be565b92915050565b600080fd5b600080fd5b600080fd5b60008083601f840112610a0f57610a0e6109ea565b5b8235905067ffffffffffffffff811115610a2c57610a2b6109ef565b5b602083019150836001820283011115610a4857610a476109f4565b5b9250929050565b600080600060408486031215610a6857610a676109b4565b5b6000610a76868287016109d5565b935050602084013567ffffffffffffffff811115610a9757610a966109b9565b5b610aa3868287016109f9565b92509250509250925092565b6000819050919050565b610ac281610aaf565b8114610acd57600080fd5b50565b600081359050610adf81610ab9565b92915050565b60008060008060808587031215610aff57610afe6109b4565b5b6000610b0d878288016109d5565b9450506020610b1e878288016109d5565b9350506040610b2f878288016109d5565b9250506060610b4087828801610ad0565b91505092959194509250565b60008083601f840112610b6257610b616109ea565b5b8235905067ffffffffffffffff811115610b7f57610b7e6109ef565b5b602083019150836020820283011115610b9b57610b9a6109f4565b5b9250929050565b600080600080600060808688031215610bbe57610bbd6109b4565b5b6000610bcc888289016109d5565b9550506020610bdd888289016109d5565b945050604086013567ffffffffffffffff811115610bfe57610bfd6109b9565b5b610c0a88828901610b4c565b93509350506060610c1d888289016109d5565b9150509295509295909350565b600060208284031215610c4057610c3f6109b4565b5b6000610c4e848285016109d5565b91505092915050565b60008083601f840112610c6d57610c6c6109ea565b5b8235905067ffffffffffffffff811115610c8a57610c896109ef565b5b602083019150836020820283011115610ca657610ca56109f4565b5b9250929050565b60008060008060608587031215610cc757610cc66109b4565b5b6000610cd5878288016109d5565b9450506020610ce687828801610ad0565b935050604085013567ffffffffffffffff811115610d0757610d066109b9565b5b610d1387828801610c57565b925092505092959194509250565b6000601f19601f8301169050919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b610d6a82610d21565b810181811067ffffffffffffffff82111715610d8957610d88610d32565b5b80604052505050565b6000610d9c6109aa565b9050610da88282610d61565b919050565b600067ffffffffffffffff821115610dc857610dc7610d32565b5b602082029050602081019050919050565b6000610dec610de784610dad565b610d92565b90508083825260208201905060208402830185811115610e0f57610e0e6109f4565b5b835b81811015610e385780610e2488826109d5565b845260208401935050602081019050610e11565b5050509392505050565b600082601f830112610e5757610e566109ea565b5b8135610e67848260208601610dd9565b91505092915050565b600067ffffffffffffffff821115610e8b57610e8a610d32565b5b602082029050602081019050919050565b600063ffffffff82169050919050565b610eb581610e9c565b8114610ec057600080fd5b50565b600081359050610ed281610eac565b92915050565b6000610eeb610ee684610e70565b610d92565b90508083825260208201905060208402830185811115610f0e57610f0d6109f4565b5b835b81811015610f375780610f238882610ec3565b845260208401935050602081019050610f10565b5050509392505050565b600082601f830112610f5657610f556109ea565b5b8135610f66848260208601610ed8565b91505092915050565b6000610f7a8261094e565b9050919050565b610f8a81610f6f565b8114610f9557600080fd5b50565b600081359050610fa781610f81565b92915050565b60008060008060808587031215610fc757610fc66109b4565b5b600085013567ffffffffffffffff811115610fe557610fe46109b9565b5b610ff187828801610e42565b945050602085013567ffffffffffffffff811115611012576110116109b9565b5b61101e87828801610f41565b935050604061102f87828801610ec3565b925050606061104087828801610f98565b91505092959194509250565b600081519050919050565b600082825260208201905092915050565b6000819050602082019050919050565b6110818161096e565b82525050565b60006110938383611078565b60208301905092915050565b6000602082019050919050565b60006110b78261104c565b6110c18185611057565b93506110cc83611068565b8060005b838110156110fd5781516110e48882611087565b97506110ef8361109f565b9250506001810190506110d0565b5085935050505092915050565b600081519050919050565b600082825260208201905092915050565b6000819050602082019050919050565b61113f81610e9c565b82525050565b60006111518383611136565b60208301905092915050565b6000602082019050919050565b60006111758261110a565b61117f8185611115565b935061118a83611126565b8060005b838110156111bb5781516111a28882611145565b97506111ad8361115d565b92505060018101905061118e565b5085935050505092915050565b6111d181610e9c565b82525050565b600060808201905081810360008301526111f181876110ac565b90508181036020830152611205818661116a565b905061121460408301856111c8565b6112216060830184610980565b95945050505050565b600081519050611239816109be565b92915050565b600060208284031215611255576112546109b4565b5b60006112638482850161122a565b91505092915050565b6000819050919050565b600061128560208401846109d5565b905092915050565b6000602082019050919050565b60006112a68385611057565b93506112b18261126c565b8060005b858110156112ea576112c78284611276565b6112d18882611087565b97506112dc8361128d565b9250506001810190506112b5565b5085925050509392505050565b600060608201905061130c6000830187610980565b818103602083015261131f81858761129a565b905061132e6040830184610980565b95945050505050565b61134081610aaf565b82525050565b6000819050919050565b6000819050919050565b600061137561137061136b8461094e565b611350565b61094e565b9050919050565b60006113878261135a565b9050919050565b60006113998261137c565b9050919050565b6113a98161138e565b82525050565b60006113bb83836113a0565b60208301905092915050565b60006113d28261096e565b9050919050565b6113e2816113c7565b81146113ed57600080fd5b50565b6000813590506113ff816113d9565b92915050565b600061141460208401846113f0565b905092915050565b6000602082019050919050565b60006114358385611057565b935061144082611346565b8060005b85811015611479576114568284611405565b61146088826113af565b975061146b8361141c565b925050600181019050611444565b5085925050509392505050565b600060608201905061149b6000830187610980565b6114a86020830186611337565b81810360408301526114bb818486611429565b905095945050505050565b60006060820190506114db6000830186610980565b6114e86020830185610980565b6114f56040830184611337565b949350505050565b60008115159050919050565b611512816114fd565b811461151d57600080fd5b50565b60008151905061152f81611509565b92915050565b60006020828403121561154b5761154a6109b4565b5b600061155984828501611520565b91505092915050565b600081519050919050565b600081905092915050565b60005b8381101561159657808201518184015260208101905061157b565b60008484015250505050565b60006115ad82611562565b6115b7818561156d565b93506115c7818560208601611578565b80840191505092915050565b60006115df82846115a2565b91508190509291505056fea264697066735822122080829e1bddcd6199d39b5b66e0e51b001d090f9a381c81e3bd599df654060e1164736f6c63430008170033";

type RoyaltyPolicyLSConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: RoyaltyPolicyLSConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class RoyaltyPolicyLS__factory extends ContractFactory {
  constructor(...args: RoyaltyPolicyLSConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override getDeployTransaction(
    _royaltyModule: AddressLike,
    _liquidSplitFactory: AddressLike,
    _liquidSplitMain: AddressLike,
    overrides?: NonPayableOverrides & { from?: string }
  ): Promise<ContractDeployTransaction> {
    return super.getDeployTransaction(
      _royaltyModule,
      _liquidSplitFactory,
      _liquidSplitMain,
      overrides || {}
    );
  }
  override deploy(
    _royaltyModule: AddressLike,
    _liquidSplitFactory: AddressLike,
    _liquidSplitMain: AddressLike,
    overrides?: NonPayableOverrides & { from?: string }
  ) {
    return super.deploy(
      _royaltyModule,
      _liquidSplitFactory,
      _liquidSplitMain,
      overrides || {}
    ) as Promise<
      RoyaltyPolicyLS & {
        deploymentTransaction(): ContractTransactionResponse;
      }
    >;
  }
  override connect(runner: ContractRunner | null): RoyaltyPolicyLS__factory {
    return super.connect(runner) as RoyaltyPolicyLS__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): RoyaltyPolicyLSInterface {
    return new Interface(_abi) as RoyaltyPolicyLSInterface;
  }
  static connect(
    address: string,
    runner?: ContractRunner | null
  ): RoyaltyPolicyLS {
    return new Contract(address, _abi, runner) as unknown as RoyaltyPolicyLS;
  }
}
