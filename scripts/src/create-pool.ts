import { Transaction } from '@mysten/sui/transactions';
import { client, keypair, getId } from './utils.js';

(async () => {
    try {
        console.log("calling...")
        const pkg = getId("package_id");
        const admin = "0xd81ca6b6c28b8e8d4e2f39da61e5bc147c4a52ec0c255f401b6fb203d968c508";

        const tx = new Transaction();
        tx.setGasBudget(100000000);

        const sui = tx.splitCoins(tx.gas, [10000]);

        const [pool, coin] = tx.moveCall({
            target: `0xc4049b2d1cc0f6e017fda8260e4377cecd236bd7f56a54fee120816e72e2e0dd::pool_factory::create_pool_2_coins`,
            typeArguments: [
                `${pkg}::af_lp::AF_LP`,
                `0x2::sui::SUI`,
                `${pkg}::mazu::MAZU`,
            ],
            arguments: [
                tx.object("0xb7b96241554bf55775ca651500e8d995ba8fb0311bbf47a6a032f771b2d5b364"), // create_pool_cap
                tx.object("0xfcc774493db2c45c79f688f88d28023a3e7d98e4ee9f48bbf5c7990f651577ae"),
                tx.pure.vector("u8", Array.from("SUI/MAZU Pool").map(char => char.charCodeAt(0))),
                tx.pure.vector("u8", Array.from("AfLpSuiMazu").map(char => char.charCodeAt(0))),
                tx.pure.vector("u8", Array.from("AF_LP_SUI_MAZU").map(char => char.charCodeAt(0))),
                tx.pure.vector("u8", Array.from("LP coin for the Aftermath Pool: SUI/MAZU").map(char => char.charCodeAt(0))),
                tx.pure.vector("u8", Array.from("https://aftermath.finance/coins/lp/sui-mazu.svg").map(char => char.charCodeAt(0))),
                tx.pure.vector("u64", [500000000000000000, 500000000000000000]),
                tx.pure.u64(0),
                tx.pure.vector("u64", [3000000000000000, 3000000000000000]),
                tx.pure.vector("u64", [0, 0]),
                tx.pure.vector("u64", [0, 0]),
                tx.pure.vector("u64", [0, 0]),
                sui, // sui_coin,
                tx.object("0xb5170778142201a6926c855fe8d9827dd03f4e3f9e00184e2c96509d19047f5e"), // mazu_coin,
                tx.pure.option("vector<u8>", null),
                tx.pure.bool(false),
                tx.pure.option("u8", null),
            ],
        });

        const [dao_pool, cap] = tx.moveCall({
            target: `0x6f60a091637054e23915b8745c0c0d47b1d49618ee3435b5f68eccf6a44fb53d::pool::new`,
            typeArguments: [`${pkg}::af_lp::AF_LP`],
            arguments: [
                pool,
                tx.object("0xb4bfb0f917f12ad2a772bea9b4f22431f6f5f9653162c3ae6fae5b99b21392b7"), // version
                tx.pure.u16(400), // fee bps
                tx.pure.address(admin), // recipient
            ],
        });

        tx.moveCall({
            target: `0x2::transfer::public_share_object`,
            typeArguments: [`0x6f60a091637054e23915b8745c0c0d47b1d49618ee3435b5f68eccf6a44fb53d::pool::DaoFeePool<${pkg}::af_lp::AF_LP>`],
            arguments: [dao_pool],
        });

        tx.transferObjects([coin, cap], admin);

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