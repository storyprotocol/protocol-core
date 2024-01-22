/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumberish,
  BytesLike,
  FunctionFragment,
  Result,
  Interface,
  AddressLike,
  ContractRunner,
  ContractMethod,
  Listener,
} from "ethers";
import type {
  TypedContractEvent,
  TypedDeferredTopicFilter,
  TypedEventLog,
  TypedListener,
  TypedContractMethod,
} from "../../../common";

export interface RoyaltyModuleInterface extends Interface {
  getFunction(
    nameOrSignature:
      | "isWhitelistedRoyaltyPolicy"
      | "payRoyalty"
      | "royaltyPolicies"
      | "setRoyaltyPolicy"
      | "whitelistRoyaltyPolicy"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "isWhitelistedRoyaltyPolicy",
    values: [AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "payRoyalty",
    values: [AddressLike, AddressLike, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "royaltyPolicies",
    values: [AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "setRoyaltyPolicy",
    values: [AddressLike, AddressLike, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "whitelistRoyaltyPolicy",
    values: [AddressLike, boolean]
  ): string;

  decodeFunctionResult(
    functionFragment: "isWhitelistedRoyaltyPolicy",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "payRoyalty", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "royaltyPolicies",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setRoyaltyPolicy",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "whitelistRoyaltyPolicy",
    data: BytesLike
  ): Result;
}

export interface RoyaltyModule extends BaseContract {
  connect(runner?: ContractRunner | null): RoyaltyModule;
  waitForDeployment(): Promise<this>;

  interface: RoyaltyModuleInterface;

  queryFilter<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;
  queryFilter<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;

  on<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  on<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  once<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  once<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  listeners<TCEvent extends TypedContractEvent>(
    event: TCEvent
  ): Promise<Array<TypedListener<TCEvent>>>;
  listeners(eventName?: string): Promise<Array<Listener>>;
  removeAllListeners<TCEvent extends TypedContractEvent>(
    event?: TCEvent
  ): Promise<this>;

  isWhitelistedRoyaltyPolicy: TypedContractMethod<
    [royaltyPolicy: AddressLike],
    [boolean],
    "view"
  >;

  payRoyalty: TypedContractMethod<
    [_ipId: AddressLike, _token: AddressLike, _amount: BigNumberish],
    [void],
    "nonpayable"
  >;

  royaltyPolicies: TypedContractMethod<[ipId: AddressLike], [string], "view">;

  setRoyaltyPolicy: TypedContractMethod<
    [_ipId: AddressLike, _royaltyPolicy: AddressLike, _data: BytesLike],
    [void],
    "nonpayable"
  >;

  whitelistRoyaltyPolicy: TypedContractMethod<
    [_royaltyPolicy: AddressLike, _allowed: boolean],
    [void],
    "nonpayable"
  >;

  getFunction<T extends ContractMethod = ContractMethod>(
    key: string | FunctionFragment
  ): T;

  getFunction(
    nameOrSignature: "isWhitelistedRoyaltyPolicy"
  ): TypedContractMethod<[royaltyPolicy: AddressLike], [boolean], "view">;
  getFunction(
    nameOrSignature: "payRoyalty"
  ): TypedContractMethod<
    [_ipId: AddressLike, _token: AddressLike, _amount: BigNumberish],
    [void],
    "nonpayable"
  >;
  getFunction(
    nameOrSignature: "royaltyPolicies"
  ): TypedContractMethod<[ipId: AddressLike], [string], "view">;
  getFunction(
    nameOrSignature: "setRoyaltyPolicy"
  ): TypedContractMethod<
    [_ipId: AddressLike, _royaltyPolicy: AddressLike, _data: BytesLike],
    [void],
    "nonpayable"
  >;
  getFunction(
    nameOrSignature: "whitelistRoyaltyPolicy"
  ): TypedContractMethod<
    [_royaltyPolicy: AddressLike, _allowed: boolean],
    [void],
    "nonpayable"
  >;

  filters: {};
}
