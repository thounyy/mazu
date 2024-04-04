import { client, getId } from '../utils.js';

interface Pool {
    total_value: number;
    total_staked: number;
    emissions: number[];
    reward_index: number;
    last_updated: number;
}

interface Staked {
    id: string;
    end: number;
    value: number;
    reward_index: number;
    coin: any;
}

const MS_IN_WEEK = 1000 * 60 * 60 * 24 * 7; 

function getEmitted(pool: any, start: number, currentTime: number): number {
        let lastWeek = Math.min(Math.floor((pool.last_updated - start) / MS_IN_WEEK), 71);
        let currentWeek = Math.min(Math.floor((currentTime - start) / MS_IN_WEEK), 71);
        let emitted = 0;

        for (let i = lastWeek; i < currentWeek + 1; i++) {
            const emittedThisWeek = pool.emissions[i];
            // add everything emitted since start
            if (i == currentWeek) {
                const msCurrentWeek = Math.min(currentTime - start - (currentWeek * MS_IN_WEEK), MS_IN_WEEK);
                emitted += emittedThisWeek * (msCurrentWeek / MS_IN_WEEK);
            }; 
            // remove everything emitted since last updated for the week
            if (i == lastWeek) {
                const msLastWeek = Math.min(pool.last_updated - start - (lastWeek * MS_IN_WEEK), MS_IN_WEEK);
                emitted -= emittedThisWeek * (msLastWeek / MS_IN_WEEK);
            };
            // if it's a full week or last week we add everything
            if (i != currentWeek) {
                emitted += emittedThisWeek;
            };
        };
        return emitted;
}

(async () => { 
	try {
		console.log("calling...")

		const packageId = getId("package_id");

        const objs: any = await client.multiGetObjects({
            ids: [
                "0x0000000000000000000000000000000000000000000000000000000000000006", // clock
                `${getId("staking::Staking")}`,
                `${getId(`dynamic_field::Field<${packageId}::staking::PoolKey<${packageId}::mazu::MAZU>`)}`, // MAZU Pool object
                "0x6f9d38226ba98b50eb37b4d85f0bc544e6225339f1ed4a04fefb71c1bc095abd", // staked object
            ],
            options: {
                showContent: true,
            }
        })

        const current_time = Number(objs[0].data.content.fields.timestamp_ms);
        const start = Number(objs[1].data.content.fields.start);
        const pfields = objs[2].data.content.fields.value.fields;
        const pool: Pool = {
            total_value: Number(pfields.total_value),
            total_staked: Number(pfields.total_staked),
            emissions: pfields.emissions,
            reward_index: Number(pfields.reward_index),
            last_updated: Number(pfields.last_updated)
        };
        const sfields = objs[3].data.content.fields;
        const staked: Staked = {
            id: sfields.id,
            end: Number(sfields.end),
            value: Number(sfields.value),
            reward_index: Number(sfields.reward_index),
            coin: sfields.coin
        };

        const globalRewardIndex = getEmitted(pool, start, current_time) * 1000000000 / pool.total_value + pool.reward_index;
        const claimableRewardsForUser = Math.floor(Math.floor(globalRewardIndex - staked.reward_index) * staked.value / 1000000000);

        console.log(claimableRewardsForUser);

	} catch (e) {
		console.log(e)
	}
})()