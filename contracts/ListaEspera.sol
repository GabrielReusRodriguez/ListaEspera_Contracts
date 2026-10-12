// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IListaEspera.sol";
import "./ListaEsperaImpl.sol";
import "./IListaEsperaEvents.sol";


contract ListaEspera is IListaEspera, IListaEsperaEvents{


    //Resumen del contrato, llamamos a la implementacion y añadimos los eventos. (considero que estan fuera de la implementacion)
    address private addrImplementation;

    function alta(
        address _solicitante,
        string calldata _idPaciente, 
        string calldata _codigoPrueba,
        string calldata _diagnostico,
        uint16 _diasDemora,
        uint256 _timestampAlta
        ) external override  returns (uint256) {

            ListaEsperaImpl implementation = ListaEsperaImpl(addrImplementation);
            
            uint256 idnuevaPrueba = implementation.alta({
                 _solicitante: _solicitante,
                 _idPaciente : _idPaciente,
                 _diagnostico : _diagnostico,
                 _codigoPrueba: _codigoPrueba,
                 _diasDemora : _diasDemora,
                 _timestampAlta : _timestampAlta
            });

            emit Alta({
                pruebaID : idnuevaPrueba,
                CIP: _idPaciente,
                centroRealizador: _solicitante,
                timestampAlta:  _timestampAlta,
                diagnostico : _diagnostico,
                codigoPrueba : _codigoPrueba,
                maximoDiasDemora: _diasDemora
            });
            return idnuevaPrueba;
        }

    function listaPruebasPorPaciente(
        string calldata _idPaciente
    ) external override view returns (uint256[] memory) {
        
        ListaEsperaImpl implementation = ListaEsperaImpl(addrImplementation);
        return implementation.listaPruebasPorPaciente(_idPaciente);
    }

    function listaPruebasPorCentro(
        address _centro
    ) external override view returns (uint256[] memory)
    {

        ListaEsperaImpl implementation = ListaEsperaImpl(addrImplementation);
        return implementation.listaPruebasPorCentro(_centro);
    }

    function obtenerPruebaPorId(
        uint256 _idPrueba
    ) external override view returns (PruebaDiagnostica memory) {

        ListaEsperaImpl implementation = ListaEsperaImpl(addrImplementation);
        return implementation.obtenerPruebaPorId(_idPrueba);
    }

    
    function muestraLogsPrueba(
        uint256 _idPrueba
    ) external override view {

    }

    function creaRedireccion(
        address _solicitante,
        uint256 _idPrueba,
        address _centroDestino
    ) external override {

        ListaEsperaImpl implementation = ListaEsperaImpl(addrImplementation);
        implementation.creaRedireccion(_solicitante, _idPrueba, _centroDestino );
        PruebaDiagnostica memory prueba = implementation.obtenerPruebaPorId(_idPrueba);
        emit CreaRedireccion( _idPrueba, prueba.idPaciente, _centroDestino);
    }

    function listaRedireccionesPendientes(
        address _solicitante
    ) external override view returns (uint256 [] memory) {

        ListaEsperaImpl implementation = ListaEsperaImpl(addrImplementation);
        

    }

    function aceptaRedireccion(
        address _solicitante,
        uint256 _idPrueba
    ) external override{

        ListaEsperaImpl implementation = ListaEsperaImpl(addrImplementation);
        implementation.aceptaRedireccion(_solicitante, _idPrueba);
        PruebaDiagnostica memory prueba = implementation.obtenerPruebaPorId(_idPrueba);
        emit AceptaRedireccion( _idPrueba, prueba.idPaciente, _solicitante);
    }
    
    function rechazaRedireccion(
        address _solicitante,
        uint256 _idPrueba
    ) external override{

        ListaEsperaImpl implementation = ListaEsperaImpl(addrImplementation);
        implementation.rechazaRedireccion(_solicitante, _idPrueba);
        PruebaDiagnostica memory prueba = implementation.obtenerPruebaPorId(_idPrueba);
        emit RechazaRedireccion( _idPrueba, prueba.idPaciente, _solicitante);
    }

    function baja(
        address _solicitante,
        uint256 _idPrueba,
        uint256 _timestampBaja, 
        uint16 _motivoDeBaja
    ) external override{

        ListaEsperaImpl implementation = ListaEsperaImpl(addrImplementation);
        implementation.baja(_solicitante, _idPrueba, _timestampBaja, _motivoDeBaja);
        PruebaDiagnostica memory prueba = implementation.obtenerPruebaPorId(_idPrueba);
        emit Baja( _idPrueba, prueba.idPaciente, _timestampBaja, _motivoDeBaja);
    }
}