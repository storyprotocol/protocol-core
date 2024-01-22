/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BytesLike,
  FunctionFragment,
  Result,
  Interface,
  EventFragment,
  AddressLike,
  ContractRunner,
  ContractMethod,
  Listener,
} from "ethers";
import type {
  TypedContractEvent,
  TypedDeferredTopicFilter,
  TypedEventLog,
  TypedLogDescription,
  TypedListener,
  TypedContractMethod,
} from "../../../common";

export interface IModuleRegistryInterface extends Interface {
  getFunction(
    nameOrSignature:
      | "getModule"
      | "isRegistered"
      | "registerModule"
      | "removeModule"
  ): FunctionFragment;

  getEvent(
    nameOrSignatureOrTopic: "ModuleAdded" | "ModuleRemoved"
  ): EventFragment;

  encodeFunctionData(functionFragment: "getModule", values: [string]): string;
  encodeFunctionData(
    functionFragment: "isRegistered",
    values: [AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "registerModule",
    values: [string, AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "removeModule",
    values: [string]
  ): string;

  decodeFunctionResult(functionFragment: "getModule", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "isRegistered",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "registerModule",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "removeModule",
    data: BytesLike
  ): Result;
}

export namespace ModuleAddedEvent {
  export type InputTuple = [name: string, module: AddressLike];
  export type OutputTuple = [name: string, module: string];
  export interface OutputObject {
    name: string;
    module: string;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export namespace ModuleRemovedEvent {
  export type InputTuple = [name: string, module: AddressLike];
  export type OutputTuple = [name: string, module: string];
  export interface OutputObject {
    name: string;
    module: string;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export interface IModuleRegistry extends BaseContract {
  connect(runner?: ContractRunner | null): IModuleRegistry;
  waitForDeployment(): Promise<this>;

  interface: IModuleRegistryInterface;

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

  getModule: TypedContractMethod<[name: string], [string], "view">;

  isRegistered: TypedContractMethod<
    [moduleAddress: AddressLike],
    [boolean],
    "view"
  >;

  registerModule: TypedContractMethod<
    [name: string, moduleAddress: AddressLike],
    [void],
    "nonpayable"
  >;

  removeModule: TypedContractMethod<[name: string], [void], "nonpayable">;

  getFunction<T extends ContractMethod = ContractMethod>(
    key: string | FunctionFragment
  ): T;

  getFunction(
    nameOrSignature: "getModule"
  ): TypedContractMethod<[name: string], [string], "view">;
  getFunction(
    nameOrSignature: "isRegistered"
  ): TypedContractMethod<[moduleAddress: AddressLike], [boolean], "view">;
  getFunction(
    nameOrSignature: "registerModule"
  ): TypedContractMethod<
    [name: string, moduleAddress: AddressLike],
    [void],
    "nonpayable"
  >;
  getFunction(
    nameOrSignature: "removeModule"
  ): TypedContractMethod<[name: string], [void], "nonpayable">;

  getEvent(
    key: "ModuleAdded"
  ): TypedContractEvent<
    ModuleAddedEvent.InputTuple,
    ModuleAddedEvent.OutputTuple,
    ModuleAddedEvent.OutputObject
  >;
  getEvent(
    key: "ModuleRemoved"
  ): TypedContractEvent<
    ModuleRemovedEvent.InputTuple,
    ModuleRemovedEvent.OutputTuple,
    ModuleRemovedEvent.OutputObject
  >;

  filters: {
    "ModuleAdded(string,address)": TypedContractEvent<
      ModuleAddedEvent.InputTuple,
      ModuleAddedEvent.OutputTuple,
      ModuleAddedEvent.OutputObject
    >;
    ModuleAdded: TypedContractEvent<
      ModuleAddedEvent.InputTuple,
      ModuleAddedEvent.OutputTuple,
      ModuleAddedEvent.OutputObject
    >;

    "ModuleRemoved(string,address)": TypedContractEvent<
      ModuleRemovedEvent.InputTuple,
      ModuleRemovedEvent.OutputTuple,
      ModuleRemovedEvent.OutputObject
    >;
    ModuleRemoved: TypedContractEvent<
      ModuleRemovedEvent.InputTuple,
      ModuleRemovedEvent.OutputTuple,
      ModuleRemovedEvent.OutputObject
    >;
  };
}
