import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from '../utils.js';


(async () => {
	
	// e2e example, usually need separate tx by different members
	// multisig is initialized with deployer's address and threshold 1

	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const packageId = getId("package_id");

		tx.moveCall({
			target: `${packageId}::multisig::propose_modify`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("add_members_increase_threshold"), // proposal name / human-readable id
				tx.pure(true), // is it to add members (false if remove)
				tx.pure(1), // new threshold, can be the same as before
				tx.pure([
					"0xb2b1148d2ee50063e292551956a906764762f8e1786083dc0adaf203a6e64bda",
					"0x244d0dd19b90b0ded063d5543b5e4b83b4e3b1ae1b8993e0f11abbd7ae77ad6b"
				]), // addresses to add or remove
			]
		});

		tx.moveCall({
			target: `${packageId}::multisig::approve_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("add_members_increase_threshold")
			]
		});

		const [proposal] = tx.moveCall({
			target: `${packageId}::multisig::execute_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("add_members_increase_threshold")
			]
		});

		const [request] = tx.moveCall({
			target: `${packageId}::multisig::start_modify`,
			arguments: [
				tx.object(proposal)
			]
		});
		
		tx.moveCall({
			target: `${packageId}::multisig::complete_modify`,
			arguments: [
				tx.object(getId("multisig::Multisig")),
				tx.object(request)
			]
		});

		tx.setGasBudget(10000000);

		const result = await client.signAndExecuteTransactionBlock({
			signer: keypair,
			transactionBlock: tx,
			options: {
				showObjectChanges: true,
				showEffects: true,
			},
			requestType: "WaitForLocalExecution"
		});

		console.log("result: ", JSON.stringify(result.objectChanges, null, 2));
		console.log("status: ", JSON.stringify(result.effects?.status, null, 2));

	} catch (e) {
		console.log(e)
	}
})()