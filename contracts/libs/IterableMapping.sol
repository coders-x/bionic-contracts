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

    function contains(BionicStructs.Map storage map, address[] memory members) public view returns (bool){
        // loop through array1
        for(uint i = 0; i < members.length; i++) {
            // check if each element in array1 exists in array2
            // if any element in array1 is not found in array2, return false
            if(!map.inserted[members[i]]) {
                return false; 
            }
        }
        // if all elements in array1 are found in array2, return true
        return true;
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
