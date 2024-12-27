import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create new story",
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
    
    let story = chain.mineBlock([
      Tx.contractCall('story_weave', 'get-story', [
        types.uint(1)
      ], deployer.address)
    ]);
    
    story.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Can add contribution to story",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const contributor = accounts.get('wallet_1')!;
    
    // First create a story
    let block = chain.mineBlock([
      Tx.contractCall('story_weave', 'create-story', [
        types.utf8("Test Story")
      ], deployer.address)
    ]);
    
    // Add contribution
    let contribution = chain.mineBlock([
      Tx.contractCall('story_weave', 'add-contribution', [
        types.uint(1),
        types.utf8("Test contribution content")
      ], contributor.address)
    ]);
    
    contribution.receipts[0].result.expectOk();
    assertEquals(contribution.receipts[0].result, types.ok(types.uint(1)));
  },
});

Clarinet.test({
  name: "Can vote on contributions",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const contributor = accounts.get('wallet_1')!;
    const voter = accounts.get('wallet_2')!;
    
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
    
    // Vote on contribution
    let vote = chain.mineBlock([
      Tx.contractCall('story_weave', 'vote-contribution', [
        types.uint(1)
      ], voter.address)
    ]);
    
    vote.receipts[0].result.expectOk();
    
    // Check has-voted
    let hasVoted = chain.mineBlock([
      Tx.contractCall('story_weave', 'has-voted', [
        types.uint(1),
        types.principal(voter.address)
      ], voter.address)
    ]);
    
    assertEquals(hasVoted.receipts[0].result, types.bool(true));
  },
});