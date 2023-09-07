// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

library Utils {

    function excludeAddresses(address[] memory array1, address[] memory array2) 
        public 
        pure
        returns (address[] memory) 
    {
        // Store addresses from array1 that are not in array2
        address[] memory exclusionArray = new address[](array1.length);
        uint count = 0;

        for (uint i = 0; i < array1.length; i++) {
            address element = array1[i];
            bool found = false;
            for (uint j = 0; j < array2.length; j++) {
                if (element == array2[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                exclusionArray[count] = element;
                count++;
            }
        }

        // Copy exclusionArray into new array of correct length
        address[] memory result = new address[](count);
        for (uint i = 0; i < count; i++) {
            result[i] = exclusionArray[i];
        }

        return result;
    }
}