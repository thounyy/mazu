import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from '../utils.js';


(async () => {
	
	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const packageId = getId("package_id");

		tx.moveCall({
			target: `${packageId}::mazu::propose_transfer`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("transfer"), // proposal name / human-readable id
				tx.pure("community"), // stakeholder name (Vault fields)
				tx.pure(10), // amount
				tx.pure("0x67fa77f2640ca7e0141648bf008e13945263efad6dc429303ad49c740e2084a9"), // recipient
			]
		});

		tx.moveCall({
			target: `${packageId}::multisig::approve_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("transfer")
			]
		});

		const [proposal] = tx.moveCall({
			target: `${packageId}::multisig::execute_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("transfer")
			]
		});

		const [request] = tx.moveCall({
			target: `${packageId}::mazu::start_transfer`,
			arguments: [
				tx.object(proposal)
			]
		});
		
		tx.moveCall({
			target: `${packageId}::mazu::complete_transfer`,
			arguments: [
				tx.object(getId("mazu::Vault")),
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