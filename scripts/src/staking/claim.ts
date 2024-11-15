import { Transaction } from '@mysten/sui/transactions';
import { client, keypair, getId } from '../utils.js';

(async () => {
	try {
		console.log("calling...")

		const tx = new Transaction();

		const packageId = getId("package_id");

		const [rewards] = tx.moveCall({
			target: `${packageId}::staking::claim`,
			arguments: [
				tx.object(getId("mazu::Vault")), 
				tx.object(getId("staking::Staking")), 
				tx.object("0x38bc44e3d097a599acdfd14875a2a1783503ddf07f63f88c30e770c93ed6ca75"), // the Staked object
				tx.object("0x0000000000000000000000000000000000000000000000000000000000000006"),
			],
			typeArguments: [
				`${packageId}::mazu::MAZU`
			],
		});

		tx.transferObjects([rewards], keypair.getPublicKey().toSuiAddress());

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