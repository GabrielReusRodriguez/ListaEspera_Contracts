// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IListaEsperaEvents.sol";
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

interface IListaEspera is IListaEsperaEvents {

    function alta(
        string calldata _idPaciente, 
        string calldata _codigoPrueba,
        string calldata _diagnostico,
        uint16 _diasDemora,
        uint256 _timestampAlta
        ) external;

    function listaPruebasPorPaciente(
        string calldata _idPaciente
    ) external view returns (PruebaDiagnostica[] memory);

    function listaPruebasPorCentro(
        address _centro
    ) external view returns (PruebaDiagnostica[] memory);

    function obtenerPruebaPorId(
        uint256 _idPrueba
    ) external view returns (PruebaDiagnostica memory);
    
    function muestraLogsPrueba(
        uint256 _idPrueba
    ) external view;

    function creaRedireccion(
        uint256 _idPrueba,
        address _centroDestino
    ) external;

    function listaRedireccionesPendientes(

    ) external view returns (SolicitudRedireccion[] memory);

    function aceptaRedireccion(
        uint256 _idPrueba
    ) external;
    
    function rechazaRedireccion(
        uint256 _idPrueba
    ) external;
    
    function baja(
        uint256 _idPrueba
    ) external;

}
