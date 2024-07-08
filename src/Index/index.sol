// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.7.0;
pragma abicoder v2;

// importing the ERC20 token contract
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./uniswap.sol";
contract Index is ERC20, Uniswap {

    // total supply of the token i.e total amount of tokens that can exist
    uint mintableSupply = 1000000 * (10 ** 18);
    uint ownerSupply = 10000 * (10 ** 18);
    address public Deployer;
    uint owners;

    // an array of the underlying assets for the index
    address[] public assetsContracts;
    string[] public assetsNames;
    uint[] public assetsRatio;

    // mapping to hold all users
    mapping (address => bool) holders;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Uniswap(msg.sender) {
        Deployer = msg.sender;
    }

    function deployerMint() internal {
        require(totalSupply() <= mintableSupply, "token supply limit has been reached");
        _mint(msg.sender, ownerSupply);
    }

    function mint (uint mintAmount) internal {
        require(totalSupply() <= mintableSupply, "token supply limit has been reached");
        _mint(msg.sender, mintAmount);
    }

    // function to get create index instantly
    function createFund(address[] memory tokenAddresses, string[] memory tokenNames, uint[] memory ratio, uint[3] memory tokenAmount) public returns(bytes[] memory results) {
        assetsContracts = tokenAddresses;
        assetsNames = tokenNames;
        assetsRatio = ratio;
        deployerMint();
        owners += 1;
        holders[msg.sender] = true;
        bytes[3] memory data = getData(tokenAddresses, tokenAmount);
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }

    // function to redeem stable coin
    function Redeem(uint amount) public returns(bytes[] memory results) {
        require(amount <= balanceOf(msg.sender), "You don not have enough tokens");
        
        // get price
        uint value = balanceOf(msg.sender) * Price();
        uint sum = assetsRatio[0] + assetsRatio[1] + assetsRatio[2];
        uint unit = value / sum;
        uint tokenValue1 = assetsRatio[0] * unit;
        uint tokenValue2 = assetsRatio[1] * unit;
        uint tokenValue3 = assetsRatio[2] * unit;

        uint[3] memory tokenAmount = [tokenValue1, tokenValue2, tokenValue3];
        bytes[3] memory data = getencodedData(assetsContracts, tokenAmount);

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
        // burn tokens
        _burn(msg.sender, amount);
    }

    // function to invest in fund
    function investFund(uint amount) public returns(bytes[] memory results) {
        // calculate the amount to be bought for each token
        uint sum = assetsRatio[0] + assetsRatio[1] + assetsRatio[2];
        uint unit = amount / sum;
        uint tokenAmount1 = unit * assetsRatio[0];
        uint tokenAmount2 = unit * assetsRatio[1];
        uint tokenAmount3 = unit * assetsRatio[2];

        uint[3] memory tokenAmount = [tokenAmount1, tokenAmount2, tokenAmount3];
        bytes[3] memory data = getData(assetsContracts, tokenAmount);
        
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
        // create function to get the price of the token
        uint price = Price();
        uint mintAmount = amount / price;
        // tokens are minted to owner
        mint(mintAmount);
        holders[msg.sender] = true;
        if (holders[msg.sender] != true) {
            owners += 1;
        }
        else {
            owners += 0;
        }
    }

    // function to calculate price of token
    function Price() public returns (uint price) {
        
        uint tokenSupply = totalSupply();
        uint assetPrice1 = getPrice(assetsContracts[0]);
        uint balance1 = getBalance(assetsContracts[0]);
        uint assetPrice2 = getPrice(assetsContracts[1]);
        uint balance2 = getBalance(assetsContracts[1]);
        uint assetPrice3 = getPrice(assetsContracts[2]);
        uint balance3 = getBalance(assetsContracts[2]);

        uint assetValue1 = assetPrice1 * balance1;
        uint assetValue2 = assetPrice2 * balance2;
        uint assetValue3 = assetPrice3 * balance3;

        uint nav = assetValue1 + assetValue2 + assetValue3;
        price = nav / tokenSupply;

    }

    // function to return all prices of the tokens
    function getPrice(address token) internal view returns(uint price) {
        // write interface and instatiate
        ERC20I Itoken = ERC20I(token);
        uint decimal = Itoken.decimals();
        uint amountIn = 1 * (10 ** decimal);
        price = estimateAmountOut(token, amountIn);
    }

    function getBalance(address token) internal view returns (uint) {
        // write interface and instatiate
        ERC20I Itoken = ERC20I(token);
        uint balance = Itoken.balanceOf(address(this));
        return balance;
    }

    function getDeployer() public view returns (address) {
        return Deployer;
    }
    // function to return underlying assets and ratio
    function getContracts() public view returns (address[] memory) {
        return assetsContracts;
    }
    function getNames() public view returns (string[] memory) {
        return assetsNames;
    }
    function getRatio() public view returns (uint[] memory) {
        return assetsRatio;
    }
    // function to return number of holders
    function getOwners() public view returns (uint) {
        return owners;
    }

    // function to return fund details
    function Details() public view returns (address, address[] memory, string[] memory, uint[] memory, uint) {
        return(Deployer, assetsContracts, assetsNames, assetsRatio, owners);
    }

    //function to encode functions params
    function getData(address[] memory tokenAddresses, uint[3] memory tokenAmount) internal view returns(bytes[3] memory) {
        require(tokenAddresses.length == tokenAmount.length, "All arrays have to be of the same length");

        bytes memory buy1 = abi.encodeWithSelector(this.buyAsset.selector, tokenAddresses[0], tokenAmount[0], address(this));
        bytes memory buy2 = abi.encodeWithSelector(this.buyAsset.selector, tokenAddresses[1], tokenAmount[1], address(this));
        bytes memory buy3 = abi.encodeWithSelector(this.buyAsset.selector, tokenAddresses[2], tokenAmount[2], address(this));

        bytes[3] memory Data = [buy1, buy2, buy3];
        return Data;
        
    }
    
    //function to encode functions params
    function getencodedData(address[] memory tokenAddresses, uint[3] memory tokenAmount) internal view returns(bytes[3] memory) {
        require(tokenAddresses.length == tokenAmount.length, "All arrays have to be of the same length");

        bytes memory sell1 = abi.encodeWithSelector(this.sellToken.selector, tokenAddresses[0], tokenAmount[0], msg.sender);
        bytes memory sell2 = abi.encodeWithSelector(this.sellToken.selector, tokenAddresses[1], tokenAmount[1], msg.sender);
        bytes memory sell3 = abi.encodeWithSelector(this.sellToken.selector, tokenAddresses[2], tokenAmount[2], msg.sender);

        bytes[3] memory Data = [sell1, sell2, sell3];
        return Data;
        
    }

}

interface ERC20I {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint256);
}