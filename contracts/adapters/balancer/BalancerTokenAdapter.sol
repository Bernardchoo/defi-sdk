// Copyright (C) 2020 Zerion Inc. <https://zerion.io>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

import { ERC20 } from "../../ERC20.sol";
import { TokenMetadata, Component } from "../../Structs.sol";
import { TokenAdapter } from "../TokenAdapter.sol";
import { StringHelpers } from "../../StringHelpers.sol";


/**
 * @dev BPool contract interface.
 * Only the functions required for UniswapAdapter contract are added.
 * The BPool contract is available here
 * github.com/balancer-labs/balancer-core/blob/master/contracts/BPool.sol.
 */
interface BPool {
    function getFinalTokens() external view returns (address[] memory);
    function getBalance(address) external view returns (uint256);
    function getNormalizedWeight(address) external view returns (uint256);
}


/**
 * @title Token adapter for Balancer pool tokens.
 * @dev Implementation of TokenAdapter abstract contract.
 * @author Igor Sobolev <sobolev@zerion.io>
 */
contract BalancerTokenAdapter is TokenAdapter {

    using StringHelpers for bytes32;
    using StringHelpers for uint256;

    /**
     * @return Array of Component structs with underlying tokens rates for the given asset.
     * @dev Implementation of TokenAdapter abstract contract function.
     */
    function getComponents(address token) external view override returns (Component[] memory) {
        address[] memory underlyingTokensAddresses;
        try BPool(token).getFinalTokens() returns (address[] memory result) {
            underlyingTokensAddresses = result;
        } catch {
            underlyingTokensAddresses = new address[](0);
        }

        uint256 totalSupply = ERC20(token).totalSupply();

        Component[] memory underlyingTokens = new Component[](underlyingTokensAddresses.length);

        for (uint256 i = 0; i < underlyingTokens.length; i++) {
            address underlyingToken = underlyingTokensAddresses[i];
            underlyingTokens[i] = Component({
                token: underlyingToken,
                tokenType: "ERC20",
                rate: BPool(token).getBalance(underlyingToken) * 1e18 / totalSupply
            });
        }

        return underlyingTokens;
    }

    /**
     * @return Pool name.
     */
    function getName(address token) internal view override returns (string memory) {
        address[] memory underlyingTokensAddresses;
        try BPool(token).getFinalTokens() returns (address[] memory result) {
            underlyingTokensAddresses = result;
        } catch {
            return "Unknown pool";
        }

        string memory poolName = "";
        uint256 lastIndex = underlyingTokensAddresses.length - 1;
        for (uint256 i = 0; i < underlyingTokensAddresses.length; i++) {
            poolName = string(abi.encodePacked(
                poolName,
                getPoolElement(token, underlyingTokensAddresses[i]),
                i == lastIndex ? " pool" : " + "
            ));
        }
        return poolName;
    }

    function getPoolElement(address pool, address token) internal view returns (string memory) {
        return string(abi.encodePacked(
            (BPool(pool).getNormalizedWeight(token) / 1e16).toString(),
            "% ",
            getUnderlyingSymbol(token)
        ));
    }

    function getUnderlyingSymbol(address token) internal view returns (string memory) {
        (, bytes memory returnData) = token.staticcall(
            abi.encodeWithSelector(ERC20(token).symbol.selector)
        );

        if (returnData.length == 32) {
            return abi.decode(returnData, (bytes32)).toString();
        } else {
            return abi.decode(returnData, (string));
        }
    }
}
