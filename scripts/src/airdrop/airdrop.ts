import { Transaction } from '@mysten/sui/transactions';
import { client, keypair, getId } from '../utils.js';

async function loadAirdrops() {
	const fs = require('fs');
	const path = require('path');
	const csv = require('csv-parser');

	let airdrops: { user: string, amount: string }[] = [];
	const filePath = path.resolve(__dirname, './airdrops.csv');

	await new Promise((resolve, reject) => {
		fs.createReadStream(filePath)
			.pipe(csv())
			.on('data', (data: any) => airdrops.push({ user: data.owner, amount: data.alloc }))
			.on('end', resolve)
			.on('error', reject);
	});

	airdrops = airdrops.map(drop => ({
		user: drop.user,
		amount: (parseFloat(drop.amount.replace(',', '')) * 1e9).toFixed(0)
	}));

	return airdrops;
}

(async () => {
	try {
		console.log("calling...")

		const packageId = getId("package_id");
		const airdrops = await loadAirdrops();
		console.log(airdrops)

		while (airdrops.length > 0) {
			const tx = new Transaction();

			tx.moveCall({
				target: `${packageId}::airdrop::propose`,
				arguments: [
					tx.object(getId("multisig::Multisig")), 
					tx.pure.string("airdrop")
				]
			});

			tx.moveCall({
				target: `${packageId}::multisig::approve_proposal`,
				arguments: [
					tx.object(getId("multisig::Multisig")), 
					tx.pure.string("airdrop")
				]
			});

			const [proposal] = tx.moveCall({
				target: `${packageId}::multisig::execute_proposal`,
				arguments: [
					tx.object(getId("multisig::Multisig")), 
					tx.pure.string("airdrop")
				]
			});

			const [request] = tx.moveCall({
				target: `${packageId}::airdrop::start`,
				arguments: [
					tx.object(proposal)
				]
			});

			const drops = airdrops.splice(0, 500);

			drops.forEach(drop => {
				tx.moveCall({
					target: `${packageId}::airdrop::drop`,
					arguments: [
						tx.object(request),
						tx.pure.u64(drop.amount),
						tx.pure.address(drop.user)
					]
				});
			});

			tx.moveCall({
				target: `${packageId}::airdrop::complete`,
				arguments: [
					tx.object(request)
				]
			});

			tx.setGasBudget(5000000000);

			const result = await client.signAndExecuteTransaction({
				signer: keypair,
				transaction: tx,
				options: {
					showObjectChanges: true,
					showEffects: true,
				},
				requestType: "WaitForLocalExecution"
			});

			await new Promise(resolve => setTimeout(resolve, 1000));

			console.log("result: ", JSON.stringify(result.objectChanges, null, 2));
			console.log("status: ", JSON.stringify(result.effects?.status, null, 2));
		}

	} catch (e) {
		console.log(e)
	}
})()