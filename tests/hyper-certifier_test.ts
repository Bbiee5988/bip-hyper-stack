import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "Bip Hyper Stack: Verify initial platform setup",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = chain.mineBlock([
      Tx.contractCall('hyper-certifier', 'get-platform-statistics', [], deployer.address)
    ]);

    block.receipts[0].result.expectOk();
    block.receipts[0].result.expectJSONEquals({
      'total-auditors': 0,
      'total-certifications': 0,
      'total-certified-contracts': 0
    });
  }
});

Clarinet.test({
  name: "Bip Hyper Stack: Allow auditor application",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const alice = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(
        'hyper-certifier', 
        'apply-as-auditor', 
        [
          types.ascii('Alice'), 
          types.ascii('Tech Solutions'), 
          types.ascii('https://example.com'), 
          types.ascii('Expert security auditor')
        ], 
        alice.address
      )
    ]);

    block.receipts[0].result.expectOk();
  }
});

Clarinet.test({
  name: "Bip Hyper Stack: Prevent duplicate auditor applications",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const alice = accounts.get('wallet_1')!;
    const block = chain.mineBlock([
      Tx.contractCall(
        'hyper-certifier', 
        'apply-as-auditor', 
        [
          types.ascii('Alice'), 
          types.ascii('Tech Solutions'), 
          types.ascii('https://example.com'), 
          types.ascii('Expert security auditor')
        ], 
        alice.address
      ),
      Tx.contractCall(
        'hyper-certifier', 
        'apply-as-auditor', 
        [
          types.ascii('Alice'), 
          types.ascii('Tech Solutions'), 
          types.ascii('https://example.com'), 
          types.ascii('Expert security auditor')
        ], 
        alice.address
      )
    ]);

    block.receipts[0].result.expectOk();
    block.receipts[1].result.expectErr().expectUint(101);
  }
});