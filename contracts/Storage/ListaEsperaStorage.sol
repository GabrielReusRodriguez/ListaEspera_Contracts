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

    /* 
    Inventarios de centros. Se decide hacerlo como array en vez de hashtable ya que se ha de listar muchas veces y se calcula que habrán como mucho  50 centros?
    Centro[] private centros;
    */
    address private addressGestorCentros;
    address private addressGestorPruebasDiagnosticas;
    address private addressGestorRedirecciones;

    // Para cada idPaciente, obtenemos los ids de las Pruebas diagnosticas para buscarlo en el anterior mapping.
    //mapping ( string => uint256[] ) private pruebasPorPaciente;
    // Para cada centro (address de centro) obtenemos la lista de idPrueba que nos permite obtener la prueba 
    //mapping ( address => uint256[] ) private pruebasPorCentro;


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
        //require (!centros[_centro].activo, "El centro ya esta registrado");
        //centros[_centro] = Centro(_nombre, true);
        ListaEsperaStorageCentros gestorCentros = ListaEsperaStorageCentros(addressGestorCentros);
        gestorCentros.nuevoCentro(_centro, _nombre);
    }


/*
    // Funciones sobre las pruebas diagnosticas ******************************************************************************************
    function existePrueba(uint256 _idPrueba) public view returns (bool) {
        if (pruebasDiagnosticas[_idPrueba].idPrueba != 0){
            return true;
        }
        return false;
    }

    function getPruebaDiagnostica(uint _idPrueba) public view returns (PruebaDiagnostica memory) {
        require(nextIdPrueba > 0, "No hay registradas ninguna  prueba");
        return pruebasDiagnosticas[_idPrueba];
    }
*/
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
        /*
        //require(_esCentroActivo(_sender), "El emisor no es un centro valido para redireccionar");
        //require(_esCentroActivo(_centroDestino), "El destino no es un centro activo o valido");
        require(_sender != _centroDestino, "El origen y el destino no pueden ser el mismo centro");
        require(pruebasDiagnosticas[_idPrueba].idPrueba != 0, "La prueba no existe");
        require(pruebasDiagnosticas[_idPrueba].activa  == true, "La prueba no esta activa");
        require(pruebasDiagnosticas[_idPrueba].propuestaRedireccion == false, "La prueba ya tiene una propuesta de redireccion");

        PruebaDiagnostica storage prueba =  pruebasDiagnosticas[_idPrueba];
        SolicitudRedireccion[] storage  redireccionesPorCentro = solicitudesRedirecciones[_centroDestino];
        SolicitudRedireccion memory redireccion = SolicitudRedireccion({
            idPrueba        : _idPrueba,
            centroOrigen    : _sender,
            centroDestino   : _centroDestino,
            idPaciente      : prueba.idPaciente
        });
        redireccionesPorCentro.push(redireccion);
        prueba.centroDestinoRedireccion = _centroDestino;
        prueba.propuestaRedireccion = true;
    */
    }

    function rechazaRedireccion(address _sender, uint256 _idPrueba) public {
        /*
        require (existePrueba(_idPrueba), "La prueba solicitada no existe");
        PruebaDiagnostica storage _prueba  = pruebasDiagnosticas[_idPrueba];
        _rechazaRedireccion(_sender,_prueba);
    */
    }
/*
    function _rechazaRedireccion(address _sender, PruebaDiagnostica storage _prueba) internal {
        //require(_esCentroActivo(_sender), "No eres un centro valido para rechazar la redireccion");
        require(_prueba.propuestaRedireccion, "No consta ninguna propuesta de redireccion");
        require(_prueba.centroDestinoRedireccion == _sender, "No eres el centro destino, no puedes rechazar la redireccion");
        _prueba.centroDestinoRedireccion = address(0);
        _prueba.propuestaRedireccion = false;
        _eliminaRedireccion(_sender, _prueba);

    }
*/
    function aceptaRedireccion(address _sender, uint256 _idPrueba) public {
  /*      require (existePrueba(_idPrueba), "La prueba solicitada no existe");
        PruebaDiagnostica storage _prueba  = pruebasDiagnosticas[_idPrueba];
        _aceptaRedireccion(_sender,_prueba);
    */    
    }

    /*
    function _aceptaRedireccion(address _sender, PruebaDiagnostica storage _prueba) internal {
      
        //require(_esCentroActivo(_sender), "No eres un centro valido para aceptar la redireccion");
        require(_prueba.propuestaRedireccion, "No consta ninguna propuesta de redireccion");address _sender, 
        require(_prueba.centroDestinoRedireccion == _sender, "No eres el centro destino, no puedes aceptar la redireccion");        
        _prueba.centroRealizador = _sender;
        _prueba.centroDestinoRedireccion = address(0);
        _prueba.propuestaRedireccion = false;
        _eliminaRedireccion(_sender, _prueba);        
    
    }
    */
    
    // FUnciones de listados *************************************************************************
    function listarPruebasPorPaciente(string calldata _idPaciente) public view returns (uint256[] memory) {
        //
    }

    function listarPruebasPorCentro(address _centro) public view returns (uint256[] memory) {
        //return pruebasPorCentro[_centro];
    }

    function listarRedireccionesPorCentro(address _centro) public view returns (SolicitudRedireccion[] memory) {
        //return solicitudesRedirecciones[_centro];
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