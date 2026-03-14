import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Owner can register a protocol",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const protocol = accounts.get('wallet_1')!;
    let block = chain.mineBlock([
      Tx.contractCall('sbtc-router', 'register-protocol', [
        types.ascii('alex-dex'), types.principal(protocol.address), types.uint(5000)
      ], deployer.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok u0)');
  }
});

Clarinet.test({
  name: "Non-owner cannot register a protocol",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const attacker = accounts.get('wallet_1')!;
    const protocol = accounts.get('wallet_2')!;
    let block = chain.mineBlock([
      Tx.contractCall('sbtc-router', 'register-protocol', [
        types.ascii('fake'), types.principal(protocol.address), types.uint(5000)
      ], attacker.address)
    ]);
    assertEquals(block.receipts[0].result, '(err u100)');
  }
});

Clarinet.test({
  name: "User can deposit and withdraw",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get('wallet_1')!;
    chain.mineBlock([Tx.contractCall('sbtc-router', 'deposit', [types.uint(1000000)], user.address)]);
    let query = chain.callReadOnlyFn('sbtc-router', 'get-user-deposit', [types.principal(user.address)], user.address);
    assertEquals(query.result, '(tuple (amount u1000000))');
    let block = chain.mineBlock([Tx.contractCall('sbtc-router', 'withdraw', [types.uint(500000)], user.address)]);
    assertEquals(block.receipts[0].result, '(ok u500000)');
  }
});

Clarinet.test({
  name: "Cannot withdraw more than deposited",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get('wallet_1')!;
    chain.mineBlock([Tx.contractCall('sbtc-router', 'deposit', [types.uint(1000)], user.address)]);
    let block = chain.mineBlock([Tx.contractCall('sbtc-router', 'withdraw', [types.uint(9999)], user.address)]);
    assertEquals(block.receipts[0].result, '(err u106)');
  }
});
