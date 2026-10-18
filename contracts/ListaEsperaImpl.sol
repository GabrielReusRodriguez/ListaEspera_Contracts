// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IListaEspera.sol";
import "./Storage/ListaEsperaStorage.sol";


contract ListaEsperaImpl is IListaEspera{


    /*
        Las llamadas con la logica ( que delegaran en storage y demas ) han de ser con only owner, solo se pueden llamar si lo ha pedido el contrato principal.
        Las llamadas de administracion ( activo o no, setear adresses... las puede llamar un admin :  personas humanas )
    */
    address private admin;
    address private immutable owner;
    address private addrStorage;
    bool private activo;

    function setAdmin(address _admin) public {
        require(_admin != address(0), "la nueva direccion ha de estar informada");
        require(msg.sender == admin, "Solo lo pude gestionar el admin");

        admin = _admin;
    }

    function setStorage(address _addrStorage) public {
        require(msg.sender == admin, "Solo lo pude gestionar el admin");
        require(_addrStorage != address(0), "la nueva direccion ha de estar informada");
        
        addrStorage = _addrStorage;
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "Solo el owner puede ejeccutarlo");
        _;
    }

    modifier contratoActivo(){
        require(activo, "Contrato NO activo");
        _;
    }


    constructor(address _owner, address _admin) {
        require(_owner != address(0), "owner es zero");
        require(_admin != address(0), "admin es zero");
        owner = _owner;
        admin = _admin;
        activo = true;
    }

    function alta(
        address _solicitante,
        string calldata _idPaciente, 
        string calldata _codigoPrueba,
        string calldata _diagnostico,
        uint16 _diasDemora,
        uint256 _timestampAlta
        ) external override contratoActivo onlyOwner returns (uint256){

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
    ) external override view onlyOwner returns (uint256[] memory) {
        
        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        return gestorStorage.listarPruebasPorPaciente(_idPaciente);
    }

    function listaPruebasPorCentro(
        address _centro
    ) external override view onlyOwner returns (uint256[] memory)
    {
        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        return gestorStorage.listarPruebasPorCentro(_centro);
    }

    function obtenerPruebaPorId(
        uint256 _idPrueba
    ) external override view onlyOwner returns (PruebaDiagnostica memory) {

        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        return gestorStorage.getPrueba(_idPrueba);
    }

    function creaRedireccion(
        address _solicitante,
        uint256 _idPrueba,
        address _centroDestino
    ) external override contratoActivo onlyOwner {

        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        gestorStorage.nuevaRedireccion(_solicitante, _idPrueba, _centroDestino );
    }

    function listaRedireccionesPendientes(
        address _solicitante
    ) external view override onlyOwner returns (uint256 [] memory) {

        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        return gestorStorage.listarRedireccionesPorCentro(_solicitante);
    }

    function aceptaRedireccion(
        address _solicitante,
        uint256 _idPrueba
    ) external override contratoActivo onlyOwner {

        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        PruebaDiagnostica memory prueba  = gestorStorage.getPrueba(_idPrueba);
        require(_solicitante == prueba.centroDestinoRedireccion, "No tienes permiso para aceptar la redireccion");

        gestorStorage.aceptaRedireccion(_solicitante, _idPrueba);
    }
    
    function rechazaRedireccion(
        address _solicitante,
        uint256 _idPrueba
    ) external override contratoActivo onlyOwner {

        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        PruebaDiagnostica memory prueba  = gestorStorage.getPrueba(_idPrueba);
        require(_solicitante == prueba.centroDestinoRedireccion, "No tienes permiso para rechazar la redireccion");

        gestorStorage.rechazaRedireccion(_solicitante, _idPrueba);
    }

    function baja(
        address _solicitante,
        uint256 _idPrueba,
        uint256 _timestampBaja, 
        uint16 _motivoDeBaja
    ) external override contratoActivo onlyOwner {
        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        gestorStorage.bajaPruebaDiagnostica(_solicitante, _idPrueba, _timestampBaja, _motivoDeBaja);
    }

    function enable() external override {
        require(msg.sender == admin || msg.sender  == owner, "No estas autorizado");
        require(activo == false, "YA esta activo");
        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        gestorStorage.enable();
        activo = true;

    }

    function disable() external override {
        require(msg.sender == admin || msg.sender == owner, "No estas autorizado");
        require(activo == true, "YA esta desactivo");
        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        gestorStorage.disable();        
        activo = false;

    }

    function listaCentros() external view override returns (Centro[] memory) {
        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        return gestorStorage.listaCentros();
    }

    function creaCentro(address _sender, address _centro, string calldata _nombre ) external override onlyOwner contratoActivo  {
        ListaEsperaStorage gestorStorage = ListaEsperaStorage(addrStorage);
        gestorStorage.creaCentro(_sender, _centro, _nombre );
    }


}