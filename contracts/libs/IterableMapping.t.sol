// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
import "./BionicStructs.sol";
import "./IterableMapping.sol";

contract TestIterableMap {
    using IterableMapping for BionicStructs.Map;

    BionicStructs.Map private map;
    address[] private memberAddresses;

    function testIterableMap() public {
        map.set(
            address(0),
            BionicStructs.UserInfo({
                amount: 0
            })
        );
        map.set(
            address(1),
            BionicStructs.UserInfo({
                amount: 100
            })
        );
        map.set(
            address(2),
            BionicStructs.UserInfo({
                amount: 200
            })
        ); // insert
        map.set(
            address(2),
            BionicStructs.UserInfo({
                amount: 200

            })
        ); // update
        map.set(
            address(3),
            BionicStructs.UserInfo({
                amount: 300

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
        
        memberAddresses.push(address(0));
        memberAddresses.push(address(2));
        assert(map.contains(memberAddresses)==true);
        memberAddresses.push(address(1));
        assert(map.contains(memberAddresses)==false);
    }
}
