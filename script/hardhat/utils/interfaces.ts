// https://github.com/dethcrypto/TypeChain/blob/master/packages/target-ethers-v5/static/common.ts
import type { EventFilter } from "ethers"

export interface TypedEvent<TArgsArray extends Array<any> = any, TArgsObject = any> extends Event {
  args: TArgsArray & TArgsObject
}

export interface TypedEventFilter<_TEvent extends TypedEvent> extends EventFilter {}
