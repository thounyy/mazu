import { Transaction } from '@mysten/sui/transactions';
import { client, keypair, getId } from '../utils.js';

(async () => {
	try {
		console.log("calling...")

		const tx = new Transaction();

		const packageId = getId("package_id");
		console.log(getId("airdrop::Airdrop"))

		const [mazu] = tx.moveCall({
			target: `${packageId}::airdrop::claim`,
			arguments: [
				tx.object("0x31fee16e00a6b176e454b0c6281dccff10479abc3d962232745fd7474a6159b7"), 
				tx.object(getId("airdrop::Airdrop")), 
				tx.object(getId("mazu::Vault")),
			],
		});

		tx.transferObjects([mazu], keypair.getPublicKey().toSuiAddress());

		tx.setGasBudget(10000000);

		const result = await client.signAndExecuteTransaction({
			signer: keypair,
			transaction: tx,
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