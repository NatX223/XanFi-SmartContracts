/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  PayableOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type { FunctionFragment, Result } from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
} from "./common";

export type LiquidityProvidedStruct = {
  senderChain: BigNumberish;
  sender: string;
  tokenA: string;
  tokenB: string;
  amount: BigNumberish;
};

export type LiquidityProvidedStructOutput = [
  number,
  string,
  string,
  string,
  BigNumber
] & {
  senderChain: number;
  sender: string;
  tokenA: string;
  tokenB: string;
  amount: BigNumber;
};

export interface HelloTokensInterface extends utils.Interface {
  functions: {
    "getLiquiditiesProvidedHistory()": FunctionFragment;
    "liquidityProvidedHistory(uint256)": FunctionFragment;
    "quoteRemoteLP(uint16)": FunctionFragment;
    "receiveWormholeMessages(bytes,bytes[],bytes32,uint16,bytes32)": FunctionFragment;
    "sendRemoteLP(uint16,address,uint256,address,address)": FunctionFragment;
    "tokenBridge()": FunctionFragment;
    "wormhole()": FunctionFragment;
    "wormholeRelayer()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "getLiquiditiesProvidedHistory"
      | "liquidityProvidedHistory"
      | "quoteRemoteLP"
      | "receiveWormholeMessages"
      | "sendRemoteLP"
      | "tokenBridge"
      | "wormhole"
      | "wormholeRelayer"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "getLiquiditiesProvidedHistory",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "liquidityProvidedHistory",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "quoteRemoteLP",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "receiveWormholeMessages",
    values: [BytesLike, BytesLike[], BytesLike, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "sendRemoteLP",
    values: [BigNumberish, string, BigNumberish, string, string]
  ): string;
  encodeFunctionData(
    functionFragment: "tokenBridge",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "wormhole", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "wormholeRelayer",
    values?: undefined
  ): string;

  decodeFunctionResult(
    functionFragment: "getLiquiditiesProvidedHistory",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "liquidityProvidedHistory",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "quoteRemoteLP",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "receiveWormholeMessages",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "sendRemoteLP",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "tokenBridge",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "wormhole", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "wormholeRelayer",
    data: BytesLike
  ): Result;

  events: {};
}

export interface HelloTokens extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: HelloTokensInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    getLiquiditiesProvidedHistory(
      overrides?: CallOverrides
    ): Promise<[LiquidityProvidedStructOutput[]]>;

    liquidityProvidedHistory(
      arg0: BigNumberish,
      overrides?: CallOverrides
    ): Promise<
      [number, string, string, string, BigNumber] & {
        senderChain: number;
        sender: string;
        tokenA: string;
        tokenB: string;
        amount: BigNumber;
      }
    >;

    quoteRemoteLP(
      targetChain: BigNumberish,
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { cost: BigNumber }>;

    receiveWormholeMessages(
      payload: BytesLike,
      additionalVaas: BytesLike[],
      arg2: BytesLike,
      sourceChain: BigNumberish,
      arg4: BytesLike,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<ContractTransaction>;

    sendRemoteLP(
      targetChain: BigNumberish,
      targetAddress: string,
      amount: BigNumberish,
      tokenA: string,
      tokenB: string,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<ContractTransaction>;

    tokenBridge(overrides?: CallOverrides): Promise<[string]>;

    wormhole(overrides?: CallOverrides): Promise<[string]>;

    wormholeRelayer(overrides?: CallOverrides): Promise<[string]>;
  };

  getLiquiditiesProvidedHistory(
    overrides?: CallOverrides
  ): Promise<LiquidityProvidedStructOutput[]>;

  liquidityProvidedHistory(
    arg0: BigNumberish,
    overrides?: CallOverrides
  ): Promise<
    [number, string, string, string, BigNumber] & {
      senderChain: number;
      sender: string;
      tokenA: string;
      tokenB: string;
      amount: BigNumber;
    }
  >;

  quoteRemoteLP(
    targetChain: BigNumberish,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  receiveWormholeMessages(
    payload: BytesLike,
    additionalVaas: BytesLike[],
    arg2: BytesLike,
    sourceChain: BigNumberish,
    arg4: BytesLike,
    overrides?: PayableOverrides & { from?: string }
  ): Promise<ContractTransaction>;

  sendRemoteLP(
    targetChain: BigNumberish,
    targetAddress: string,
    amount: BigNumberish,
    tokenA: string,
    tokenB: string,
    overrides?: PayableOverrides & { from?: string }
  ): Promise<ContractTransaction>;

  tokenBridge(overrides?: CallOverrides): Promise<string>;

  wormhole(overrides?: CallOverrides): Promise<string>;

  wormholeRelayer(overrides?: CallOverrides): Promise<string>;

  callStatic: {
    getLiquiditiesProvidedHistory(
      overrides?: CallOverrides
    ): Promise<LiquidityProvidedStructOutput[]>;

    liquidityProvidedHistory(
      arg0: BigNumberish,
      overrides?: CallOverrides
    ): Promise<
      [number, string, string, string, BigNumber] & {
        senderChain: number;
        sender: string;
        tokenA: string;
        tokenB: string;
        amount: BigNumber;
      }
    >;

    quoteRemoteLP(
      targetChain: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    receiveWormholeMessages(
      payload: BytesLike,
      additionalVaas: BytesLike[],
      arg2: BytesLike,
      sourceChain: BigNumberish,
      arg4: BytesLike,
      overrides?: CallOverrides
    ): Promise<void>;

    sendRemoteLP(
      targetChain: BigNumberish,
      targetAddress: string,
      amount: BigNumberish,
      tokenA: string,
      tokenB: string,
      overrides?: CallOverrides
    ): Promise<void>;

    tokenBridge(overrides?: CallOverrides): Promise<string>;

    wormhole(overrides?: CallOverrides): Promise<string>;

    wormholeRelayer(overrides?: CallOverrides): Promise<string>;
  };

  filters: {};

  estimateGas: {
    getLiquiditiesProvidedHistory(
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    liquidityProvidedHistory(
      arg0: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    quoteRemoteLP(
      targetChain: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    receiveWormholeMessages(
      payload: BytesLike,
      additionalVaas: BytesLike[],
      arg2: BytesLike,
      sourceChain: BigNumberish,
      arg4: BytesLike,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<BigNumber>;

    sendRemoteLP(
      targetChain: BigNumberish,
      targetAddress: string,
      amount: BigNumberish,
      tokenA: string,
      tokenB: string,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<BigNumber>;

    tokenBridge(overrides?: CallOverrides): Promise<BigNumber>;

    wormhole(overrides?: CallOverrides): Promise<BigNumber>;

    wormholeRelayer(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    getLiquiditiesProvidedHistory(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    liquidityProvidedHistory(
      arg0: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    quoteRemoteLP(
      targetChain: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    receiveWormholeMessages(
      payload: BytesLike,
      additionalVaas: BytesLike[],
      arg2: BytesLike,
      sourceChain: BigNumberish,
      arg4: BytesLike,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    sendRemoteLP(
      targetChain: BigNumberish,
      targetAddress: string,
      amount: BigNumberish,
      tokenA: string,
      tokenB: string,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    tokenBridge(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    wormhole(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    wormholeRelayer(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}
