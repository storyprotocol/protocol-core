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
import type { NonPayableOverrides } from "../../../common";
import type {
  IPMetadataResolver,
  IPMetadataResolverInterface,
} from "../../../contracts/resolvers/IPMetadataResolver";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "accessController",
        type: "address",
      },
      {
        internalType: "address",
        name: "ipRecordRegistry",
        type: "address",
      },
      {
        internalType: "address",
        name: "ipAccountRegistry",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "IPResolver_Unauthorized",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "length",
        type: "uint256",
      },
    ],
    name: "StringsInsufficientHexLength",
    type: "error",
  },
  {
    inputs: [],
    name: "ACCESS_CONTROLLER",
    outputs: [
      {
        internalType: "contract IAccessController",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "IP_ACCOUNT_REGISTRY",
    outputs: [
      {
        internalType: "contract IPAccountRegistry",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "IP_RECORD_REGISTRY",
    outputs: [
      {
        internalType: "contract IPRecordRegistry",
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
        name: "",
        type: "address",
      },
    ],
    name: "_records",
    outputs: [
      {
        internalType: "string",
        name: "name",
        type: "string",
      },
      {
        internalType: "string",
        name: "description",
        type: "string",
      },
      {
        internalType: "bytes32",
        name: "hash",
        type: "bytes32",
      },
      {
        internalType: "uint64",
        name: "registrationDate",
        type: "uint64",
      },
      {
        internalType: "address",
        name: "registrant",
        type: "address",
      },
      {
        internalType: "string",
        name: "uri",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "accessController",
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
        name: "ipId",
        type: "address",
      },
    ],
    name: "description",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
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
    name: "hash",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
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
    name: "metadata",
    outputs: [
      {
        components: [
          {
            internalType: "address",
            name: "owner",
            type: "address",
          },
          {
            internalType: "string",
            name: "name",
            type: "string",
          },
          {
            internalType: "string",
            name: "description",
            type: "string",
          },
          {
            internalType: "bytes32",
            name: "hash",
            type: "bytes32",
          },
          {
            internalType: "uint64",
            name: "registrationDate",
            type: "uint64",
          },
          {
            internalType: "address",
            name: "registrant",
            type: "address",
          },
          {
            internalType: "string",
            name: "uri",
            type: "string",
          },
        ],
        internalType: "struct IP.Metadata",
        name: "",
        type: "tuple",
      },
    ],
    stateMutability: "view",
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
    name: "name",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
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
    name: "owner",
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
        name: "ipId",
        type: "address",
      },
    ],
    name: "registrant",
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
        name: "ipId",
        type: "address",
      },
    ],
    name: "registrationDate",
    outputs: [
      {
        internalType: "uint64",
        name: "",
        type: "uint64",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "ipId",
        type: "address",
      },
      {
        internalType: "string",
        name: "newDescription",
        type: "string",
      },
    ],
    name: "setDescription",
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
      {
        internalType: "bytes32",
        name: "newHash",
        type: "bytes32",
      },
    ],
    name: "setHash",
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
      {
        components: [
          {
            internalType: "string",
            name: "name",
            type: "string",
          },
          {
            internalType: "string",
            name: "description",
            type: "string",
          },
          {
            internalType: "bytes32",
            name: "hash",
            type: "bytes32",
          },
          {
            internalType: "uint64",
            name: "registrationDate",
            type: "uint64",
          },
          {
            internalType: "address",
            name: "registrant",
            type: "address",
          },
          {
            internalType: "string",
            name: "uri",
            type: "string",
          },
        ],
        internalType: "struct IP.MetadataRecord",
        name: "newMetadata",
        type: "tuple",
      },
    ],
    name: "setMetadata",
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
      {
        internalType: "string",
        name: "newName",
        type: "string",
      },
    ],
    name: "setName",
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
      {
        internalType: "string",
        name: "newURI",
        type: "string",
      },
    ],
    name: "setURI",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "id",
        type: "bytes4",
      },
    ],
    name: "supportsInterface",
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
        internalType: "address",
        name: "ipId",
        type: "address",
      },
    ],
    name: "uri",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
] as const;

const _bytecode =
  "0x60e06040523480156200001157600080fd5b50604051620038703803806200387083398181016040528101906200003791906200014c565b8282828273ffffffffffffffffffffffffffffffffffffffff1660808173ffffffffffffffffffffffffffffffffffffffff16815250508173ffffffffffffffffffffffffffffffffffffffff1660c08173ffffffffffffffffffffffffffffffffffffffff16815250508073ffffffffffffffffffffffffffffffffffffffff1660a08173ffffffffffffffffffffffffffffffffffffffff1681525050505050505050620001a8565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006200011482620000e7565b9050919050565b620001268162000107565b81146200013257600080fd5b50565b60008151905062000146816200011b565b92915050565b600080600060608486031215620001685762000167620000e2565b5b6000620001788682870162000135565b93505060206200018b8682870162000135565b92505060406200019e8682870162000135565b9150509250925092565b60805160a05160c0516136606200021060003960008181610c2d01528181610fa80152610fce015260006110ec01526000818161055f0152818161078301528181610ada015281816111bb015281816113090152818161145c01526116f601526136606000f3fe608060405234801561001057600080fd5b50600436106101215760003560e01c8063666e1b39116100ad578063ae6e7faf11610071578063ae6e7faf14610354578063bc43cbaf14610370578063bc7cd2721461038e578063c29fab6d146103c3578063e84b8169146103f357610121565b8063666e1b391461028a578063702acd85146102ba5780637e809973146102d8578063a2911fcd14610308578063a2b4192f1461033857610121565b80631b8b1073116100f45780631b8b1073146101d25780632ba21572146101f05780633121db1c14610220578063426eb0171461023c5780634cc6f2731461026c57610121565b8063019848921461012657806301ffc9a7146101565780630323bd58146101865780631b562aa5146101a2575b600080fd5b610140600480360381019061013b91906120a2565b61040f565b60405161014d919061215f565b60405180910390f35b610170600480360381019061016b91906121d9565b6104e2565b60405161017d9190612221565b60405180910390f35b6101a0600480360381019061019b91906122a1565b61055c565b005b6101bc60048036038101906101b791906120a2565b6106ae565b6040516101c9919061215f565b60405180910390f35b6101da610781565b6040516101e79190612360565b60405180910390f35b61020a600480360381019061020591906120a2565b6107a5565b60405161021791906124ba565b60405180910390f35b61023a600480360381019061023591906122a1565b610ad7565b005b610256600480360381019061025191906120a2565b610c29565b604051610263919061215f565b60405180910390f35b610274610fa6565b60405161028191906124fd565b60405180910390f35b6102a4600480360381019061029f91906120a2565b610fca565b6040516102b19190612527565b60405180910390f35b6102c26110ea565b6040516102cf9190612563565b60405180910390f35b6102f260048036038101906102ed91906120a2565b61110e565b6040516102ff919061258d565b60405180910390f35b610322600480360381019061031d91906120a2565b611159565b60405161032f91906125b7565b60405180910390f35b610352600480360381019061034d91906125f6565b6111b8565b005b61036e600480360381019061036991906122a1565b611306565b005b610378611458565b6040516103859190612527565b60405180910390f35b6103a860048036038101906103a391906120a2565b611480565b6040516103ba96959493929190612652565b60405180910390f35b6103dd60048036038101906103d891906120a2565b611688565b6040516103ea9190612527565b60405180910390f35b61040d600480360381019061040891906126f4565b6116f3565b005b60606000808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020600001805461045d90612763565b80601f016020809104026020016040519081016040528092919081815260200182805461048990612763565b80156104d65780601f106104ab576101008083540402835291602001916104d6565b820191906000526020600020905b8154815290600101906020018083116104b957829003601f168201915b50505050509050919050565b60007fdd717015000000000000000000000000000000000000000000000000000000007bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916827bffffffffffffffffffffffffffffffffffffffffffffffffffffffff19161480610555575061055482611839565b5b9050919050565b827f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff16637dfd0ddb8233306000357fffffffff00000000000000000000000000000000000000000000000000000000166040518563ffffffff1660e01b81526004016105e094939291906127a3565b602060405180830381865afa1580156105fd573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906106219190612814565b610657576040517f37c8602b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b82826000808773ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060010191826106a7929190612a27565b5050505050565b60606000808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060010180546106fc90612763565b80601f016020809104026020016040519081016040528092919081815260200182805461072890612763565b80156107755780601f1061074a57610100808354040283529160200191610775565b820191906000526020600020905b81548152906001019060200180831161075857829003601f168201915b50505050509050919050565b7f000000000000000000000000000000000000000000000000000000000000000081565b6107ad611fc4565b60008060008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000206040518060c001604052908160008201805461080890612763565b80601f016020809104026020016040519081016040528092919081815260200182805461083490612763565b80156108815780601f1061085657610100808354040283529160200191610881565b820191906000526020600020905b81548152906001019060200180831161086457829003601f168201915b5050505050815260200160018201805461089a90612763565b80601f01602080910402602001604051908101604052809291908181526020018280546108c690612763565b80156109135780601f106108e857610100808354040283529160200191610913565b820191906000526020600020905b8154815290600101906020018083116108f657829003601f168201915b50505050508152602001600282015481526020016003820160009054906101000a900467ffffffffffffffff1667ffffffffffffffff1667ffffffffffffffff1681526020016003820160089054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020016004820180546109be90612763565b80601f01602080910402602001604051908101604052809291908181526020018280546109ea90612763565b8015610a375780601f10610a0c57610100808354040283529160200191610a37565b820191906000526020600020905b815481529060010190602001808311610a1a57829003601f168201915b50505050508152505090506040518060e00160405280610a5685610fca565b73ffffffffffffffffffffffffffffffffffffffff168152602001826000015181526020018260200151815260200182604001518152602001826060015167ffffffffffffffff168152602001826080015173ffffffffffffffffffffffffffffffffffffffff168152602001610acc85610c29565b815250915050919050565b827f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff16637dfd0ddb8233306000357fffffffff00000000000000000000000000000000000000000000000000000000166040518563ffffffff1660e01b8152600401610b5b94939291906127a3565b602060405180830381865afa158015610b78573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610b9c9190612814565b610bd2576040517f37c8602b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b82826000808773ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000206000019182610c22929190612a27565b5050505050565b60607f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663c3c5a547836040518263ffffffff1660e01b8152600401610c849190612527565b602060405180830381865afa158015610ca1573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610cc59190612814565b610ce057604051806020016040528060008152509050610fa1565b60008060008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000206040518060c0016040529081600082018054610d3b90612763565b80601f0160208091040260200160405190810160405280929190818152602001828054610d6790612763565b8015610db45780601f10610d8957610100808354040283529160200191610db4565b820191906000526020600020905b815481529060010190602001808311610d9757829003601f168201915b50505050508152602001600182018054610dcd90612763565b80601f0160208091040260200160405190810160405280929190818152602001828054610df990612763565b8015610e465780601f10610e1b57610100808354040283529160200191610e46565b820191906000526020600020905b815481529060010190602001808311610e2957829003601f168201915b50505050508152602001600282015481526020016003820160009054906101000a900467ffffffffffffffff1667ffffffffffffffff1667ffffffffffffffff1681526020016003820160089054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001600482018054610ef190612763565b80601f0160208091040260200160405190810160405280929190818152602001828054610f1d90612763565b8015610f6a5780601f10610f3f57610100808354040283529160200191610f6a565b820191906000526020600020905b815481529060010190602001808311610f4d57829003601f168201915b505050505081525050905060008160a001519050600081511115610f92578092505050610fa1565b610f9c84836118a3565b925050505b919050565b7f000000000000000000000000000000000000000000000000000000000000000081565b60007f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663c3c5a547836040518263ffffffff1660e01b81526004016110259190612527565b602060405180830381865afa158015611042573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906110669190612814565b61107357600090506110e5565b8173ffffffffffffffffffffffffffffffffffffffff16638da5cb5b6040518163ffffffff1660e01b8152600401602060405180830381865afa1580156110be573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906110e29190612b0c565b90505b919050565b7f000000000000000000000000000000000000000000000000000000000000000081565b60008060008373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020600201549050919050565b60008060008373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060030160009054906101000a900467ffffffffffffffff169050919050565b817f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff16637dfd0ddb8233306000357fffffffff00000000000000000000000000000000000000000000000000000000166040518563ffffffff1660e01b815260040161123c94939291906127a3565b602060405180830381865afa158015611259573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061127d9190612814565b6112b3576040517f37c8602b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b816000808573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002081816112fe9190612e84565b905050505050565b827f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff16637dfd0ddb8233306000357fffffffff00000000000000000000000000000000000000000000000000000000166040518563ffffffff1660e01b815260040161138a94939291906127a3565b602060405180830381865afa1580156113a7573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906113cb9190612814565b611401576040517f37c8602b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b82826000808773ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000206004019182611451929190612a27565b5050505050565b60007f0000000000000000000000000000000000000000000000000000000000000000905090565b60006020528060005260406000206000915090508060000180546114a390612763565b80601f01602080910402602001604051908101604052809291908181526020018280546114cf90612763565b801561151c5780601f106114f15761010080835404028352916020019161151c565b820191906000526020600020905b8154815290600101906020018083116114ff57829003601f168201915b50505050509080600101805461153190612763565b80601f016020809104026020016040519081016040528092919081815260200182805461155d90612763565b80156115aa5780601f1061157f576101008083540402835291602001916115aa565b820191906000526020600020905b81548152906001019060200180831161158d57829003601f168201915b5050505050908060020154908060030160009054906101000a900467ffffffffffffffff16908060030160089054906101000a900473ffffffffffffffffffffffffffffffffffffffff169080600401805461160590612763565b80601f016020809104026020016040519081016040528092919081815260200182805461163190612763565b801561167e5780601f106116535761010080835404028352916020019161167e565b820191906000526020600020905b81548152906001019060200180831161166157829003601f168201915b5050505050905086565b60008060008373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060030160089054906101000a900473ffffffffffffffffffffffffffffffffffffffff169050919050565b817f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff16637dfd0ddb8233306000357fffffffff00000000000000000000000000000000000000000000000000000000166040518563ffffffff1660e01b815260040161177794939291906127a3565b602060405180830381865afa158015611794573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906117b89190612814565b6117ee576040517f37c8602b00000000000000000000000000000000000000000000000000000000815260040160405180910390fd5b816000808573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060020181905550505050565b60007fbdbc0208000000000000000000000000000000000000000000000000000000007bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916827bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916149050919050565b606060006118b0846119cd565b83602001516040516020016118c6929190612fb2565b6040516020818303038152906040529050600083600001516119076118ea87610fca565b73ffffffffffffffffffffffffffffffffffffffff1660146119fa565b61192c866080015173ffffffffffffffffffffffffffffffffffffffff1660146119fa565b61193e876040015160001c60206119fa565b611955886060015167ffffffffffffffff16611c40565b6040516020016119699594939291906132c9565b60405160208183030381529060405290506119a482826040516020016119909291906133b8565b604051602081830303815290604052611d0e565b6040516020016119b49190613433565b6040516020818303038152906040529250505092915050565b60606119f38273ffffffffffffffffffffffffffffffffffffffff16601460ff166119fa565b9050919050565b6060600083905060006002846002611a129190613484565b611a1c91906134c6565b67ffffffffffffffff811115611a3557611a3461284c565b5b6040519080825280601f01601f191660200182016040528015611a675781602001600182028036833780820191505090505b5090507f300000000000000000000000000000000000000000000000000000000000000081600081518110611a9f57611a9e6134fa565b5b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916908160001a9053507f780000000000000000000000000000000000000000000000000000000000000081600181518110611b0357611b026134fa565b5b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916908160001a90535060006001856002611b439190613484565b611b4d91906134c6565b90505b6001811115611bed577f3031323334353637383961626364656600000000000000000000000000000000600f841660108110611b8f57611b8e6134fa565b5b1a60f81b828281518110611ba657611ba56134fa565b5b60200101907effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1916908160001a905350600483901c925080611be690613529565b9050611b50565b5060008214611c355784846040517fe22e27eb000000000000000000000000000000000000000000000000000000008152600401611c2c929190613561565b60405180910390fd5b809250505092915050565b606060006001611c4f84611e71565b01905060008167ffffffffffffffff811115611c6e57611c6d61284c565b5b6040519080825280601f01601f191660200182016040528015611ca05781602001600182028036833780820191505090505b509050600082602001820190505b600115611d03578080600190039150507f3031323334353637383961626364656600000000000000000000000000000000600a86061a8153600a8581611cf757611cf661358a565b5b04945060008503611cae575b819350505050919050565b60606000825103611d3057604051806020016040528060008152509050611e6c565b60006040518060600160405280604081526020016135eb6040913990506000600360028551611d5f91906134c6565b611d6991906135b9565b6004611d759190613484565b67ffffffffffffffff811115611d8e57611d8d61284c565b5b6040519080825280601f01601f191660200182016040528015611dc05781602001600182028036833780820191505090505b509050600182016020820185865187015b80821015611e2c576003820191508151603f8160121c168501518453600184019350603f81600c1c168501518453600184019350603f8160061c168501518453600184019350603f8116850151845360018401935050611dd1565b5050600386510660018114611e485760028114611e5b57611e63565b603d6001830353603d6002830353611e63565b603d60018303535b50505080925050505b919050565b600080600090507a184f03e93ff9f4daa797ed6e38ed64bf6a1f0100000000000000008310611ecf577a184f03e93ff9f4daa797ed6e38ed64bf6a1f0100000000000000008381611ec557611ec461358a565b5b0492506040810190505b6d04ee2d6d415b85acef81000000008310611f0c576d04ee2d6d415b85acef81000000008381611f0257611f0161358a565b5b0492506020810190505b662386f26fc100008310611f3b57662386f26fc100008381611f3157611f3061358a565b5b0492506010810190505b6305f5e1008310611f64576305f5e1008381611f5a57611f5961358a565b5b0492506008810190505b6127108310611f89576127108381611f7f57611f7e61358a565b5b0492506004810190505b60648310611fac5760648381611fa257611fa161358a565b5b0492506002810190505b600a8310611fbb576001810190505b80915050919050565b6040518060e00160405280600073ffffffffffffffffffffffffffffffffffffffff168152602001606081526020016060815260200160008019168152602001600067ffffffffffffffff168152602001600073ffffffffffffffffffffffffffffffffffffffff168152602001606081525090565b600080fd5b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b600061206f82612044565b9050919050565b61207f81612064565b811461208a57600080fd5b50565b60008135905061209c81612076565b92915050565b6000602082840312156120b8576120b761203a565b5b60006120c68482850161208d565b91505092915050565b600081519050919050565b600082825260208201905092915050565b60005b838110156121095780820151818401526020810190506120ee565b60008484015250505050565b6000601f19601f8301169050919050565b6000612131826120cf565b61213b81856120da565b935061214b8185602086016120eb565b61215481612115565b840191505092915050565b600060208201905081810360008301526121798184612126565b905092915050565b60007fffffffff0000000000000000000000000000000000000000000000000000000082169050919050565b6121b681612181565b81146121c157600080fd5b50565b6000813590506121d3816121ad565b92915050565b6000602082840312156121ef576121ee61203a565b5b60006121fd848285016121c4565b91505092915050565b60008115159050919050565b61221b81612206565b82525050565b60006020820190506122366000830184612212565b92915050565b600080fd5b600080fd5b600080fd5b60008083601f8401126122615761226061223c565b5b8235905067ffffffffffffffff81111561227e5761227d612241565b5b60208301915083600182028301111561229a57612299612246565b5b9250929050565b6000806000604084860312156122ba576122b961203a565b5b60006122c88682870161208d565b935050602084013567ffffffffffffffff8111156122e9576122e861203f565b5b6122f58682870161224b565b92509250509250925092565b6000819050919050565b600061232661232161231c84612044565b612301565b612044565b9050919050565b60006123388261230b565b9050919050565b600061234a8261232d565b9050919050565b61235a8161233f565b82525050565b60006020820190506123756000830184612351565b92915050565b61238481612064565b82525050565b600082825260208201905092915050565b60006123a6826120cf565b6123b0818561238a565b93506123c08185602086016120eb565b6123c981612115565b840191505092915050565b6000819050919050565b6123e7816123d4565b82525050565b600067ffffffffffffffff82169050919050565b61240a816123ed565b82525050565b600060e083016000830151612428600086018261237b565b5060208301518482036020860152612440828261239b565b9150506040830151848203604086015261245a828261239b565b915050606083015161246f60608601826123de565b5060808301516124826080860182612401565b5060a083015161249560a086018261237b565b5060c083015184820360c08601526124ad828261239b565b9150508091505092915050565b600060208201905081810360008301526124d48184612410565b905092915050565b60006124e78261232d565b9050919050565b6124f7816124dc565b82525050565b600060208201905061251260008301846124ee565b92915050565b61252181612064565b82525050565b600060208201905061253c6000830184612518565b92915050565b600061254d8261232d565b9050919050565b61255d81612542565b82525050565b60006020820190506125786000830184612554565b92915050565b612587816123d4565b82525050565b60006020820190506125a2600083018461257e565b92915050565b6125b1816123ed565b82525050565b60006020820190506125cc60008301846125a8565b92915050565b600080fd5b600060c082840312156125ed576125ec6125d2565b5b81905092915050565b6000806040838503121561260d5761260c61203a565b5b600061261b8582860161208d565b925050602083013567ffffffffffffffff81111561263c5761263b61203f565b5b612648858286016125d7565b9150509250929050565b600060c082019050818103600083015261266c8189612126565b905081810360208301526126808188612126565b905061268f604083018761257e565b61269c60608301866125a8565b6126a96080830185612518565b81810360a08301526126bb8184612126565b9050979650505050505050565b6126d1816123d4565b81146126dc57600080fd5b50565b6000813590506126ee816126c8565b92915050565b6000806040838503121561270b5761270a61203a565b5b60006127198582860161208d565b925050602061272a858286016126df565b9150509250929050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fd5b6000600282049050600182168061277b57607f821691505b60208210810361278e5761278d612734565b5b50919050565b61279d81612181565b82525050565b60006080820190506127b86000830187612518565b6127c56020830186612518565b6127d26040830185612518565b6127df6060830184612794565b95945050505050565b6127f181612206565b81146127fc57600080fd5b50565b60008151905061280e816127e8565b92915050565b60006020828403121561282a5761282961203a565b5b6000612838848285016127ff565b91505092915050565b600082905092915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b60008190508160005260206000209050919050565b60006020601f8301049050919050565b600082821b905092915050565b6000600883026128dd7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff826128a0565b6128e786836128a0565b95508019841693508086168417925050509392505050565b6000819050919050565b600061292461291f61291a846128ff565b612301565b6128ff565b9050919050565b6000819050919050565b61293e83612909565b61295261294a8261292b565b8484546128ad565b825550505050565b600090565b61296761295a565b612972818484612935565b505050565b5b818110156129965761298b60008261295f565b600181019050612978565b5050565b601f8211156129db576129ac8161287b565b6129b584612890565b810160208510156129c4578190505b6129d86129d085612890565b830182612977565b50505b505050565b600082821c905092915050565b60006129fe600019846008026129e0565b1980831691505092915050565b6000612a1783836129ed565b9150826002028217905092915050565b612a318383612841565b67ffffffffffffffff811115612a4a57612a4961284c565b5b612a548254612763565b612a5f82828561299a565b6000601f831160018114612a8e5760008415612a7c578287013590505b612a868582612a0b565b865550612aee565b601f198416612a9c8661287b565b60005b82811015612ac457848901358255600182019150602085019450602081019050612a9f565b86831015612ae15784890135612add601f8916826129ed565b8355505b6001600288020188555050505b50505050505050565b600081519050612b0681612076565b92915050565b600060208284031215612b2257612b2161203a565b5b6000612b3084828501612af7565b91505092915050565b600080fd5b600080fd5b600080fd5b60008083356001602003843603038112612b6557612b64612b39565b5b80840192508235915067ffffffffffffffff821115612b8757612b86612b3e565b5b602083019250600182023603831315612ba357612ba2612b43565b5b509250929050565b612bb6838383612a27565b505050565b60008135612bc8816126c8565b80915050919050565b60008160001b9050919050565b60007fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff612c0a84612bd1565b9350801983169250808416831791505092915050565b6000612c2b826123d4565b9050919050565b60008160001c9050919050565b6000612c4a82612c32565b9050919050565b612c5a82612c20565b612c6d612c6682612c3f565b8354612bde565b8255505050565b612c7d816123ed565b8114612c8857600080fd5b50565b60008135612c9881612c74565b80915050919050565b600067ffffffffffffffff612cb584612bd1565b9350801983169250808416831791505092915050565b6000612ce6612ce1612cdc846123ed565b612301565b6123ed565b9050919050565b6000819050919050565b612d0082612ccb565b612d13612d0c82612ced565b8354612ca1565b8255505050565b60008135612d2781612076565b80915050919050565b60008160401b9050919050565b60007bffffffffffffffffffffffffffffffffffffffff0000000000000000612d6584612d30565b9350801983169250808416831791505092915050565b6000612d868261232d565b9050919050565b6000819050919050565b612da082612d7b565b612db3612dac82612d8d565b8354612d3d565b8255505050565b6000810160008301612dcc8185612b48565b612dd7818386612bab565b505050506001810160208301612ded8185612b48565b612df8818386612bab565b50505050600281016040830180612e0e81612bbb565b9050612e1a8184612c51565b505050600381016060830180612e2f81612c8b565b9050612e3b8184612cf7565b505050600381016080830180612e5081612d1a565b9050612e5c8184612d97565b5050506004810160a08301612e718185612b48565b612e7c818386612bab565b505050505050565b612e8e8282612dba565b5050565b600081905092915050565b7f7b226e616d65223a202249502041737365742023000000000000000000000000600082015250565b6000612ed3601483612e92565b9150612ede82612e9d565b601482019050919050565b6000612ef4826120cf565b612efe8185612e92565b9350612f0e8185602086016120eb565b80840191505092915050565b7f222c20226465736372697074696f6e223a202200000000000000000000000000600082015250565b6000612f50601383612e92565b9150612f5b82612f1a565b601382019050919050565b7f222c202261747472696275746573223a205b0000000000000000000000000000600082015250565b6000612f9c601283612e92565b9150612fa782612f66565b601282019050919050565b6000612fbd82612ec6565b9150612fc98285612ee9565b9150612fd482612f43565b9150612fe08284612ee9565b9150612feb82612f8f565b91508190509392505050565b7f7b2274726169745f74797065223a20224e616d65222c202276616c7565223a2060008201527f2200000000000000000000000000000000000000000000000000000000000000602082015250565b6000613053602183612e92565b915061305e82612ff7565b602182019050919050565b7f227d2c7b2274726169745f74797065223a20224f776e6572222c202276616c7560008201527f65223a2022000000000000000000000000000000000000000000000000000000602082015250565b60006130c5602583612e92565b91506130d082613069565b602582019050919050565b7f227d2c7b2274726169745f74797065223a202252656769737472616e74222c2060008201527f2276616c7565223a202200000000000000000000000000000000000000000000602082015250565b6000613137602a83612e92565b9150613142826130db565b602a82019050919050565b7f227d2c0000000000000000000000000000000000000000000000000000000000600082015250565b6000613183600383612e92565b915061318e8261314d565b600382019050919050565b7f7b2274726169745f74797065223a202248617368222c202276616c7565223a2060008201527f2200000000000000000000000000000000000000000000000000000000000000602082015250565b60006131f5602183612e92565b915061320082613199565b602182019050919050565b7f7b2274726169745f74797065223a2022526567697374726174696f6e2044617460008201527f65222c202276616c7565223a2022000000000000000000000000000000000000602082015250565b6000613267602e83612e92565b91506132728261320b565b602e82019050919050565b7f227d000000000000000000000000000000000000000000000000000000000000600082015250565b60006132b3600283612e92565b91506132be8261327d565b600282019050919050565b60006132d482613046565b91506132e08288612ee9565b91506132eb826130b8565b91506132f78287612ee9565b91506133028261312a565b915061330e8286612ee9565b915061331982613176565b9150613324826131e8565b91506133308285612ee9565b915061333b82613176565b91506133468261325a565b91506133528284612ee9565b915061335d826132a6565b91508190509695505050505050565b7f5d7d000000000000000000000000000000000000000000000000000000000000600082015250565b60006133a2600283612e92565b91506133ad8261336c565b600282019050919050565b60006133c48285612ee9565b91506133d08284612ee9565b91506133db82613395565b91508190509392505050565b7f646174613a6170706c69636174696f6e2f6a736f6e3b6261736536342c000000600082015250565b600061341d601d83612e92565b9150613428826133e7565b601d82019050919050565b600061343e82613410565b915061344a8284612ee9565b915081905092915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b600061348f826128ff565b915061349a836128ff565b92508282026134a8816128ff565b915082820484148315176134bf576134be613455565b5b5092915050565b60006134d1826128ff565b91506134dc836128ff565b92508282019050808211156134f4576134f3613455565b5b92915050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b6000613534826128ff565b91506000820361354757613546613455565b5b600182039050919050565b61355b816128ff565b82525050565b60006040820190506135766000830185613552565b6135836020830184613552565b9392505050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601260045260246000fd5b60006135c4826128ff565b91506135cf836128ff565b9250826135df576135de61358a565b5b82820490509291505056fe4142434445464748494a4b4c4d4e4f505152535455565758595a6162636465666768696a6b6c6d6e6f707172737475767778797a303132333435363738392b2fa2646970667358221220b7164b29b500513c74e0c7150f5b05e1d2768519f6c576537db9d322b9f529f264736f6c63430008170033";

type IPMetadataResolverConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: IPMetadataResolverConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class IPMetadataResolver__factory extends ContractFactory {
  constructor(...args: IPMetadataResolverConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override getDeployTransaction(
    accessController: AddressLike,
    ipRecordRegistry: AddressLike,
    ipAccountRegistry: AddressLike,
    overrides?: NonPayableOverrides & { from?: string }
  ): Promise<ContractDeployTransaction> {
    return super.getDeployTransaction(
      accessController,
      ipRecordRegistry,
      ipAccountRegistry,
      overrides || {}
    );
  }
  override deploy(
    accessController: AddressLike,
    ipRecordRegistry: AddressLike,
    ipAccountRegistry: AddressLike,
    overrides?: NonPayableOverrides & { from?: string }
  ) {
    return super.deploy(
      accessController,
      ipRecordRegistry,
      ipAccountRegistry,
      overrides || {}
    ) as Promise<
      IPMetadataResolver & {
        deploymentTransaction(): ContractTransactionResponse;
      }
    >;
  }
  override connect(runner: ContractRunner | null): IPMetadataResolver__factory {
    return super.connect(runner) as IPMetadataResolver__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): IPMetadataResolverInterface {
    return new Interface(_abi) as IPMetadataResolverInterface;
  }
  static connect(
    address: string,
    runner?: ContractRunner | null
  ): IPMetadataResolver {
    return new Contract(address, _abi, runner) as unknown as IPMetadataResolver;
  }
}
