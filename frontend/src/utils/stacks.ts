import { openContractCall } from '@stacks/connect';
import { StacksTestnet } from '@stacks/network';
import {
  uintCV,
  stringAsciiCV,
  principalCV,
  AnchorMode,
  PostConditionMode,
  ClarityValue,
} from '@stacks/transactions';
import { userSession } from '../App';

export const DEPLOYER = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
export const NETWORK = new StacksTestnet();

function toCV(value: any): ClarityValue {
  if (typeof value === 'number') return uintCV(value);
  if (typeof value === 'string' && value.startsWith('ST')) return principalCV(value);
  if (typeof value === 'string') return stringAsciiCV(value);
  return uintCV(value);
}

export async function callContract(
  contractName: string,
  functionName: string,
  args: any[]
): Promise<void> {
  await openContractCall({
    network: NETWORK,
    contractAddress: DEPLOYER,
    contractName,
    functionName,
    functionArgs: args.map(toCV),
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow,
    onFinish: (data) => {
      console.log(`Transaction broadcast: ${data.txId}`);
    },
    onCancel: () => {
      console.log('Transaction cancelled');
    },
  });
}

export async function readContract(
  contractName: string,
  functionName: string,
  args: any[]
): Promise<any> {
  const { callReadOnlyFunction } = await import('@stacks/transactions');
  return await callReadOnlyFunction({
    network: NETWORK,
    contractAddress: DEPLOYER,
    contractName,
    functionName,
    functionArgs: args.map(toCV),
    senderAddress: DEPLOYER,
  });
}
