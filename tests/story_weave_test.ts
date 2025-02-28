import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create new story with valid title",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const title = "Test Story";
    
    let block = chain.mineBlock([
      Tx.contractCall('story_weave', 'create-story', [
        types.utf8(title)
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    assertEquals(block.receipts[0].result, types.ok(types.uint(1)));
  },
});

Clarinet.test({
  name: "Cannot create story with empty title",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const title = "";
    
    let block = chain.mineBlock([
      Tx.contractCall('story_weave', 'create-story', [
        types.utf8(title)
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectErr(104); // err-invalid-content
  },
});

Clarinet.test({
  name: "Cannot vote on own contribution",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const contributor = accounts.get('wallet_1')!;
    
    // Setup story and contribution
    let setup = chain.mineBlock([
      Tx.contractCall('story_weave', 'create-story', [
        types.utf8("Test Story")
      ], deployer.address),
      Tx.contractCall('story_weave', 'add-contribution', [
        types.uint(1),
        types.utf8("Test contribution")
      ], contributor.address)
    ]);
    
    // Try to self-vote
    let vote = chain.mineBlock([
      Tx.contractCall('story_weave', 'vote-contribution', [
        types.uint(1)
      ], contributor.address)
    ]);
    
    vote.receipts[0].result.expectErr(105); // err-self-vote
  },
});
