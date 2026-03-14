import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Member can join cooperative and gets base score",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get('wallet_1')!;
    let block = chain.mineBlock([
      Tx.contractCall('coop-credit', 'join-cooperative', [], user.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    let member = chain.callReadOnlyFn('coop-credit', 'get-member', [types.principal(user.address)], user.address);
    assertEquals(member.result.includes('score u100'), true);
  }
});

Clarinet.test({
  name: "Cannot join twice",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const user = accounts.get('wallet_1')!;
    chain.mineBlock([Tx.contractCall('coop-credit', 'join-cooperative', [], user.address)]);
    let block = chain.mineBlock([Tx.contractCall('coop-credit', 'join-cooperative', [], user.address)]);
    assertEquals(block.receipts[0].result, '(err u302)');
  }
});

Clarinet.test({
  name: "Member with sufficient score can borrow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user = accounts.get('wallet_1')!;
    chain.mineBlock([
      Tx.contractCall('coop-credit', 'join-cooperative', [], user.address),
      Tx.contractCall('coop-credit', 'fund-pool', [types.uint(500000)], deployer.address)
    ]);
    // Score 100 × multiplier 1000 = 100,000 borrow limit
    let block = chain.mineBlock([
      Tx.contractCall('coop-credit', 'borrow', [types.uint(50000)], user.address)
    ]);
    assertEquals(block.receipts[0].result, '(ok u0)');
  }
});
