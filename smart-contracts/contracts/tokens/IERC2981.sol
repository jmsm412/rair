// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.35;

interface IERC2981 {
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (
        address receiver,
        uint256 royaltyAmount
    );
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}