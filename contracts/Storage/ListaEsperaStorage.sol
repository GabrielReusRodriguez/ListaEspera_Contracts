// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../ListaEsperaTypes.sol";
import "../ListaEsperaCommonFunctions.sol";
import "./ListaEsperaStorageCentros.sol";
import "./ListaEsperaStoragePruebasDiagnosticas.sol";
import "./ListaEsperaStorageRedirecciones.sol";


contract ListaEsperaStorage{

    /*
        Este contrato sirve para guardar los datos del sistema entero. Los declaro como private porque aunque estará en una  blockchain publica 
        y se podrán leer los datos, quiero evitar que alguien desde otro contrato modifique las variables directamente con 
            contato.admin = "0x123434545645645"
        Tendrán que pasar obligatoriamente por la función de set y get que les ofrezco ( una especie de api )
    */

    bool private activo;

    // Address del administrador
    address private admin ;
    // Address de la aseguradora, vendria a ser el servicio publico de salud.
    address private aseguradora;

    address private addressGestorCentros;
    address private addressGestorPruebasDiagnosticas;
    address private addressGestorRedirecciones;


    //Modifiers ***************************************************************************************************
    modifier onlyAdmin() {
        require(msg.sender == admin, "Solo el owner puede ejecutar la funcionalidad");
        _;
    }

    modifier activeContract() {
        require(activo, "El contrato no esta activo");
        _;
    }

    modifier onlyAseguradora() {
        require(msg.sender == aseguradora, "Solo la aseguradora puede ejecutar la funcionalidad");
        _;
    }
    
    // Constructor
    constructor() {
        admin = msg.sender;
        activo = true;
    }


    // Funciones sobre los admins, propietarios y aseguradoras *************************************************************************************
    // Getters / Setteers de admin
    function getAdmin() public view returns(address) {
        return admin;
    }

    function setAdmin(address _admin) public onlyAdmin{
        require(_admin != address(0), "La nueva direccion NO ha de estar en blanco");

        admin = _admin;
    }

    // Getters / Setters de la aseguradora.
    function getAseguradora() public view returns(address) {
        return aseguradora;
    }

    function setAseguradora(address _aseguradora) public onlyAdmin {
        require(_aseguradora != address(0), "La nueva direccion NO ha de estar en blanco");

        aseguradora = _aseguradora;
    }


    function setGestorCentros(address _gestor) public onlyAdmin {
        require(_gestor != address(0), "La direccion del gestor ha de estar informada");
        addressGestorCentros = _gestor;
    }

    function setGestorRedirecciones(address _gestor) public onlyAdmin {
        require(_gestor != address(0), "La direccion del gestor ha de estar informada");
        addressGestorRedirecciones = _gestor;
    }
    
    function setGestorPruebasDiagnosticas(address _gestor) public onlyAdmin {
        require(_gestor != address(0), "La direccion del gestor ha de estar informada");
        addressGestorPruebasDiagnosticas = _gestor;
    }

    // Funciones para activar y desactivar  el contrato ************************************************************************
    function enable() public onlyAdmin {
        require (activo == false, "El contrato ya esta activado");
        activo = true;

        ListaEsperaStorageCentros gestorCentros = ListaEsperaStorageCentros(addressGestorCentros);
        gestorCentros.enable();

        ListaEsperaStoragePruebasDiagnosticas gestorPruebas = ListaEsperaStoragePruebasDiagnosticas(addressGestorPruebasDiagnosticas);
        gestorPruebas.enable();

        ListaEsperaStorageRedirecciones  gestorRedirecciones = ListaEsperaStorageRedirecciones(addressGestorRedirecciones);
        gestorRedirecciones.enable();

    }

    function disable() public  onlyAdmin {
        require (activo, "El contrato ya esta desactivado");
        activo = false;

        ListaEsperaStorageCentros gestorCentros = ListaEsperaStorageCentros(addressGestorCentros);
        gestorCentros.disable();

        ListaEsperaStoragePruebasDiagnosticas gestorPruebas = ListaEsperaStoragePruebasDiagnosticas(addressGestorPruebasDiagnosticas);
        gestorPruebas.disable();

        ListaEsperaStorageRedirecciones  gestorRedirecciones = ListaEsperaStorageRedirecciones(addressGestorRedirecciones);
        gestorRedirecciones.disable();

    }

    // Funciones sobre los centros ****************************************************************************
    function creaCentro(address _centro, string calldata _nombre ) public onlyAseguradora{
        ListaEsperaStorageCentros gestorCentros = ListaEsperaStorageCentros(addressGestorCentros);
        gestorCentros.nuevoCentro(_centro, _nombre);
    }

    // RECUERDA!!! el msg.sender será el contrato de implementacion por lo que siempre hay que pasar el address del wallet que lo ejecuta.
    // Creo y añado una prueba diagnostica a la lista de espera.
    function altaPruebaDiagnostica(
        address _centroRealizador,
        string calldata _idPaciente, 
        string calldata _diagnostico,
        string calldata _codigoPrueba,
        uint16  _maximoDiasDemora,
        uint256 _timestampAlta
        ) public  activeContract {
        
        ListaEsperaStorageCentros gestorCentros =  ListaEsperaStorageCentros(addressGestorCentros);
        require(gestorCentros.esCentroActivo(_centroRealizador) == true, "El centro realizador no es un centro activo");


        ListaEsperaStoragePruebasDiagnosticas gestorPruebas = ListaEsperaStoragePruebasDiagnosticas(addressGestorPruebasDiagnosticas);
        gestorPruebas.altaPruebaDiagnostica({
            _centroRealizador : _centroRealizador,
            _idPaciente : _idPaciente,
            _diagnostico : _diagnostico,
            _codigoPrueba : _codigoPrueba,
            _maximoDiasDemora : _maximoDiasDemora,
            _timestampAlta: _timestampAlta
        });
    }  

    // Modificamos una prueba, hacemos 2 funciones una parqa modificar los datos de baja y otra para los datos de la redireccion.
    function bajaPruebaDiagnostica(address _centroRealizador, uint256 _idPrueba, uint256 _timestampBaja, uint16 _motivoDeBaja) public {
    
        ListaEsperaStorageCentros gestorCentros =  ListaEsperaStorageCentros(addressGestorCentros);
        require (gestorCentros.esCentroActivo(_centroRealizador) == true, "EL centro realizador NO esta activo o no existe");

        ListaEsperaStoragePruebasDiagnosticas gestorPruebas = ListaEsperaStoragePruebasDiagnosticas(addressGestorPruebasDiagnosticas);
        
        address autorBaja;
        if (_centroRealizador == aseguradora) {
            autorBaja = address(0);
        } else {
            autorBaja = _centroRealizador;
        }

        bool tieneRedireccion;
        address centroDestinoRedireccion;

        (tieneRedireccion, centroDestinoRedireccion) = gestorPruebas.pruebaTieneRedireccion(_idPrueba);
        gestorPruebas.bajaPruebaDiagnostica(autorBaja, _idPrueba, _timestampBaja, _motivoDeBaja);
        if (tieneRedireccion) {
            ListaEsperaStorageRedirecciones gestorRedirecciones = ListaEsperaStorageRedirecciones(addressGestorRedirecciones);
            gestorRedirecciones.eliminaRedireccion(centroDestinoRedireccion, _idPrueba);
        }

    
    }

    // Funciones sobre redirecciones *********************************************************************************************************

    function nuevaRedireccion(address _sender, uint256 _idPrueba, address _centroDestino ) public {

        ListaEsperaStorageCentros gestorCentros = ListaEsperaStorageCentros(addressGestorCentros);
        ListaEsperaStoragePruebasDiagnosticas gestorPruebas = ListaEsperaStoragePruebasDiagnosticas(addressGestorPruebasDiagnosticas);
        ListaEsperaStorageRedirecciones gestorRedirecciones = ListaEsperaStorageRedirecciones(addressGestorRedirecciones);

        require(gestorCentros.esCentroActivo(_centroDestino), "El centro destino no esta activo o no existe.");
        require(gestorCentros.esCentroActivo(_sender), "El centro destino no esta activo o no existe.");
        require(_centroDestino != _sender, "El centro detino y origen son los mismos.");

        // En realidad, se valida en los require de antes y en el gestor de pruebas, el gestor de redirecciones lo da todo por validado y solo hace push
        // en la lista de redirecciones del centro destino.
        gestorPruebas.nuevaRedireccion(_idPrueba, _centroDestino);
        gestorRedirecciones.nuevaRedireccion(_idPrueba, _centroDestino);
    }

    function rechazaRedireccion(address _sender, uint256 _idPrueba) public {        
        /*
            Solo pueden eliminar una redireccion:
                - El centro realizador actual ( porque ya lo ha operado )
                - El centro destinatario ( la  rechaza )
                - La aseguradora ( como admin medico )
        */
        ListaEsperaStorageCentros gestorCentros = ListaEsperaStorageCentros(addressGestorCentros);
        ListaEsperaStoragePruebasDiagnosticas gestorPruebas = ListaEsperaStoragePruebasDiagnosticas(addressGestorPruebasDiagnosticas);
        ListaEsperaStorageRedirecciones gestorRedirecciones = ListaEsperaStorageRedirecciones(addressGestorRedirecciones);

        require(gestorCentros.esCentroActivo(_sender), "El centro destino no esta activo o no existe.");
        
        gestorPruebas.eliminaRedireccion(_idPrueba,false);
        gestorRedirecciones.eliminaRedireccion(_sender, _idPrueba);
    }

    function aceptaRedireccion(address _sender, uint256 _idPrueba) public {

        ListaEsperaStorageCentros gestorCentros = ListaEsperaStorageCentros(addressGestorCentros);
        ListaEsperaStoragePruebasDiagnosticas gestorPruebas = ListaEsperaStoragePruebasDiagnosticas(addressGestorPruebasDiagnosticas);
        ListaEsperaStorageRedirecciones gestorRedirecciones = ListaEsperaStorageRedirecciones(addressGestorRedirecciones);

        require(gestorCentros.esCentroActivo(_sender), "El centro destino no esta activo o no existe.");
        
        gestorPruebas.eliminaRedireccion(_idPrueba,true);
        gestorRedirecciones.eliminaRedireccion(_sender, _idPrueba);
    }
    
    // FUnciones de listados *************************************************************************
    function listarPruebasPorPaciente(string calldata _idPaciente) public view returns (uint256[] memory) {
        ListaEsperaStoragePruebasDiagnosticas gestorPruebas = ListaEsperaStoragePruebasDiagnosticas(addressGestorPruebasDiagnosticas);
        return gestorPruebas.listaPruebasPorPaciente(_idPaciente);

    }

    function listarPruebasPorCentro(address _centro) public view returns (uint256[] memory) {
        ListaEsperaStoragePruebasDiagnosticas gestorPruebas = ListaEsperaStoragePruebasDiagnosticas(addressGestorPruebasDiagnosticas);
        return gestorPruebas.listaPruebasPorCentro(_centro);
    }

    function listarRedireccionesPorCentro(address _centro) public view returns (uint256[] memory) {
        ListaEsperaStorageRedirecciones gestorRedirecciones = ListaEsperaStorageRedirecciones(addressGestorRedirecciones);
        return gestorRedirecciones.listaRedireccionesPorCentro(_centro);
    }

    function getPrueba(uint256 _idPrueba) public view returns (PruebaDiagnostica memory) {
        ListaEsperaStoragePruebasDiagnosticas gestorPruebas = ListaEsperaStoragePruebasDiagnosticas(addressGestorPruebasDiagnosticas);
        return gestorPruebas.getPruebaDiagnostica(_idPrueba);
    }

    // Funciones de exportacion  de datos*******************************************************************

    // pruebasDiagnosticas
    function exportaPruebasDiagnosticas() public view returns (PruebaDiagnostica[] memory) {
 /*
        require(msg.sender == admin, "Solo el admin puede obtener todas las pruebas Diagnosticas de la lista de espera");

        PruebaDiagnostica[] memory pruebas = new PruebaDiagnostica[] (nextIdPrueba);
        //OJO!! que la primera prueba qye introducimos tiene id 1.
        for (uint i = 1; i <= nextIdPrueba; i++) {
            pruebas[i] = pruebasDiagnosticas[i];
        }
        return pruebas;
        */
    }
   
}