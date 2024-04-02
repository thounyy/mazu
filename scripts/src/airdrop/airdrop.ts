import { TransactionBlock } from '@mysten/sui.js/transactions';
import { client, keypair, getId } from '../utils.js';


(async () => {
	const addresses = [
		"0x67fa77f2640ca7e0141648bf008e13945263efad6dc429303ad49c740e2084a9",
	]
	try {
		console.log("calling...")

		const tx = new TransactionBlock();

		const packageId = getId("package_id");

		tx.moveCall({
			target: `${packageId}::airdrop::propose`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("airdrop")
			]
		});

		tx.moveCall({
			target: `${packageId}::multisig::approve_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("airdrop")
			]
		});

		const [proposal] = tx.moveCall({
			target: `${packageId}::multisig::execute_proposal`,
			arguments: [
				tx.object(getId("multisig::Multisig")), 
				tx.pure("airdrop")
			]
		});

		const [request] = tx.moveCall({
			target: `${packageId}::airdrop::start`,
			arguments: [
				tx.object(proposal)
			]
		});

		// for (let i = 0; i < 20; i++) {
			tx.moveCall({
				target: `${packageId}::airdrop::drop`,
				arguments: [
					tx.object(request),
					tx.pure(1000000000000000),
					tx.pure(addresses)
				]
			});
		// }

		tx.moveCall({
			target: `${packageId}::airdrop::complete`,
			arguments: [
				tx.object(request)
			]
		});

		tx.setGasBudget(5000000000);

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