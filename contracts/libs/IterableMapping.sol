// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./BionicStructs.sol";

library IterableMapping {
    function get(
        BionicStructs.Map storage map,
        address key
    ) public view returns (BionicStructs.UserInfo storage) {
        return map.values[key];
    }

    function getKeyAtIndex(
        BionicStructs.Map storage map,
        uint index
    ) public view returns (address) {
        return map.keys[index];
    }

    function size(BionicStructs.Map storage map) public view returns (uint) {
        return map.keys.length;
    }

    function set(
        BionicStructs.Map storage map,
        address key,
        BionicStructs.UserInfo calldata val
    ) public {
        if (map.inserted[key]) {
            map.values[key] = val;
        } else {
            map.inserted[key] = true;
            map.values[key] = val;
            map.indexOf[key] = map.keys.length;
            map.keys.push(key);
        }
    }

    function remove(BionicStructs.Map storage map, address key) public {
        if (!map.inserted[key]) {
            return;
        }

        delete map.inserted[key];
        delete map.values[key];

        uint index = map.indexOf[key];
        address lastKey = map.keys[map.keys.length - 1];

        map.indexOf[lastKey] = index;
        delete map.indexOf[key];

        map.keys[index] = lastKey;
        map.keys.pop();
    }
}

contract TestIterableMap {
    using IterableMapping for BionicStructs.Map;

    BionicStructs.Map private map;

    function testIterableMap() public {
        map.set(
            address(0),
            BionicStructs.UserInfo({
                amount: 0,
                pledgeFundingAmount: 0,
                rewardDebtRewards: 0,
                tokenAllocDebt: 0
            })
        );
        map.set(
            address(1),
            BionicStructs.UserInfo({
                amount: 100,
                pledgeFundingAmount: 0,
                rewardDebtRewards: 0,
                tokenAllocDebt: 0
            })
        );
        map.set(
            address(2),
            BionicStructs.UserInfo({
                amount: 200,
                pledgeFundingAmount: 0,
                rewardDebtRewards: 0,
                tokenAllocDebt: 0
            })
        ); // insert
        map.set(
            address(2),
            BionicStructs.UserInfo({
                amount: 200,
                pledgeFundingAmount: 0,
                rewardDebtRewards: 0,
                tokenAllocDebt: 0
            })
        ); // update
        map.set(
            address(3),
            BionicStructs.UserInfo({
                amount: 300,
                pledgeFundingAmount: 0,
                rewardDebtRewards: 0,
                tokenAllocDebt: 0
            })
        );

        for (uint i = 0; i < map.size(); i++) {
            address key = map.getKeyAtIndex(i);

            assert(map.get(key).amount == i * 100);
        }

        map.remove(address(1));

        // keys = [address(0), address(3), address(2)]
        assert(map.size() == 3);
        assert(map.getKeyAtIndex(0) == address(0));
        assert(map.getKeyAtIndex(1) == address(3));
        assert(map.getKeyAtIndex(2) == address(2));
    }
}