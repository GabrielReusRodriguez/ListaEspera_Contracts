// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IListaEspera.sol";
import "./Storage/ListaEsperaStorage.sol";


contract ListaEsperaImpl is IListaEspera{

    address private addrStorage;

    function alta(
        address _solicitante,
        string calldata _idPaciente, 
        string calldata _codigoPrueba,
        string calldata _diagnostico,
        uint16 _diasDemora,
        uint256 _timestampAlta
        ) external override returns (uint256){

            ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
            return gestorStorage.altaPruebaDiagnostica({
                _centroRealizador: _solicitante,
                _idPaciente : _idPaciente,
                _diagnostico : _diagnostico,
                _codigoPrueba: _codigoPrueba,
                _maximoDiasDemora : _diasDemora,
                _timestampAlta : _timestampAlta
                });
        }

    function listaPruebasPorPaciente(
        string calldata _idPaciente
    ) external override view returns (uint256[] memory) {
        
        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        return gestorStorage.listarPruebasPorPaciente(_idPaciente);
    }

    function listaPruebasPorCentro(
        address _centro
    ) external override view returns (uint256[] memory)
    {
        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        return gestorStorage.listarPruebasPorCentro(_centro);
    }

    function obtenerPruebaPorId(
        uint256 _idPrueba
    ) external override view returns (PruebaDiagnostica memory) {

        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        return gestorStorage.getPrueba(_idPrueba);
    }

    function creaRedireccion(
        address _solicitante,
        uint256 _idPrueba,
        address _centroDestino
    ) external override {

        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        gestorStorage.nuevaRedireccion(_solicitante, _idPrueba, _centroDestino );
    }

    function listaRedireccionesPendientes(
        address _solicitante
    ) external view override returns (uint256 [] memory) {

        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        return gestorStorage.listarRedireccionesPorCentro(_solicitante);
    }

    function aceptaRedireccion(
        address _solicitante,
        uint256 _idPrueba
    ) external override {

        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        gestorStorage.aceptaRedireccion(_solicitante, _idPrueba);
    }
    
    function rechazaRedireccion(
        address _solicitante,
        uint256 _idPrueba
    ) external override {

        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        gestorStorage.rechazaRedireccion(_solicitante, _idPrueba);
    }

    function baja(
        address _solicitante,
        uint256 _idPrueba,
        uint256 _timestampBaja, 
        uint16 _motivoDeBaja
    ) external override {
        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        gestorStorage.bajaPruebaDiagnostica(_solicitante, _idPrueba, _timestampBaja, _motivoDeBaja);
        //function bajaPruebaDiagnostica(address _centroRealizador, uint256 _idPrueba, uint256 _timestampBaja, uint16 _motivoDeBaja) public {

    }
}