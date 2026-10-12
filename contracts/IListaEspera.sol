// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ListaEsperaTypes.sol";

/*
    Author: Gabriel Reus Rodriguez gabriel.reus[at]pm.me
    En este fichero definimos la interfaz  con las funciones que debe implementar OBLIGATORIAMENTE cualquier  contrato de implementacionde  de lista de espera.
    
    Las funciones de la interfaz serán:
        - alta
        - listaPruebasPorPaciente
        - listaPruebasPorCentro
        - obtenerPruebaPorId
        - muestraLogsPrueba
        - creaRedireccion
        - listaRedireccionesPendientes
        - aceptaRedireccion   
        - rechazaRedireccion
        - baja

*/

interface IListaEspera {

    function alta(
        address _centroRealizador,
        string calldata _idPaciente, 
        string calldata _codigoPrueba,
        string calldata _diagnostico,
        uint16 _diasDemora,
        uint256 _timestampAlta
        ) external returns (uint256);

    function listaPruebasPorPaciente(
        string calldata _idPaciente
    ) external view returns (uint256[] memory);

    function listaPruebasPorCentro(
        address _centro
    ) external view returns (uint256[] memory);

    function obtenerPruebaPorId(
        uint256 _idPrueba
    ) external view returns (PruebaDiagnostica memory);
    
    function creaRedireccion(
        address _solicitante,
        uint256 _idPrueba,
        address _centroDestino
    ) external;

    function listaRedireccionesPendientes(
        address _solicitante
    ) external view returns (uint256 [] memory);

    function aceptaRedireccion(
        address _solicitante,
        uint256 _idPrueba
    ) external;
    
    function rechazaRedireccion(
        address _solicitante,
        uint256 _idPrueba
    ) external;
    
    function baja(
        address _solicitante,
        uint256 _idPrueba,
        uint256 _timestampBaja, 
        uint16 _motivoDeBaja
    ) external;

    function enable() external;

    function disable() external;

}
