// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Funciones de Strings *************************************************************************

// Funcion para compararStrings.
function compareStrings(string memory string1, string memory string2) pure returns (bool) {
    /* 
        Recuerda, en solidity NO se puede comparar strings.
        Hemos de convertirlo a bytes y posteriormente pasarle la función criptografica.
        Si el resultado es el mismo, es que son strings ituales.
    */
     return keccak256(bytes(string1)) == keccak256(bytes(string2));
}

// Funcion para comprobar si el string está vacio.
function isEmptyString(string memory _string) pure returns (bool) {
    return bytes(_string).length == 0;
}

// Funciones de tiempo ************************************************************************

// Diferencia de tiempo pero la retornamos en dias.
function timeDiffInDays(uint _older, uint _newer) pure returns (uint) {
    return ( _newer - _older ) / 1 days;
}
