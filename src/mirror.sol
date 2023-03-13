pragma solidity 0.8.13;

contract Mirror {
    function mirror(uint256 x) public pure returns (uint256) {
        if(x==50){
            return 1;
        }
        return x;
    }
}