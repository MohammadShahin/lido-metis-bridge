// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title Lib_Uint
 * @author 
 */
library Lib_Uint {
    /**********************
     * Internal Functions *
     **********************/

    /**
     * Convert uint to string
     * @param _i uint value.
     * @return _uintAsString string momery value.
     */
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
