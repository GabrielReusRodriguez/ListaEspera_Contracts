// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ListaEsperaTypes.sol";
import "./ListaEsperaCommonFunctions.sol";

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

    uint256 nextIdPrueba;


    /* 
    Inventarios de centros. Se decide hacerlo como array en vez de hashtable ya que se ha de listar muchas veces y se calcula que habrán como mucho  50 centros?
    */
    Centro[] private centros;

    // Para cada idPrueba, obtenemos los datos enteros de la PruebaDiagnostica
    mapping ( uint256 => PruebaDiagnostica) private pruebasDiagnosticas;
    // Para cada idPaciente, obtenemos los ids de las Pruebas diagnosticas para buscarlo en el anterior mapping.
    mapping ( string => uint256[] ) private pruebasPorPaciente;
    // Para cada centro (address de centro) obtenemos la lista de idPrueba que nos permite obtener la prueba 
    mapping ( address => uint256[] ) private pruebasPorCentro;
    // Para cada centro (address de centro) obtenemos la lista de solicitudes de redireccion que ha recibido.
    mapping(address => SolicitudRedireccion[]) private solicitudesRedirecciones;

    // Constructor
    constructor() {
        admin = msg.sender;
        /*
            Agrego unos pocos centros de ejemplo.
        */
        activo = true;
        nextIdPrueba = 0;
    }


    // Funciones sobre los admins, propietarios y aseguradoras *************************************************************************************
    // Getters / Setteers de admin
    function getAdmin() public view returns(address) {
        return admin;
    }

    function setAdmin(address _admin) public {
        require (msg.sender == admin, "NO se te permite cambiar el admin");
        require(_admin != address(0), "La nueva direccion NO ha de estar en blanco");

        admin = _admin;
    }

    // Getters / Setters de la aseguradora.
    function getAseguradora() public view returns(address) {
        return aseguradora;
    }

    function setAseguradora(address _aseguradora) public {
        require (msg.sender == admin, "NO se te permite cambiar el admin");
        require(_aseguradora != address(0), "La nueva direccion NO ha de estar en blanco");

        aseguradora = _aseguradora;
    }

    // Funciones para activar y desactivar  el contrato ************************************************************************
    function enable() public {
        require (msg.sender == admin , "Solo el admin puede activar el contrato");
        require (activo == false, "El contrato ya esta activo");

        activo = true;

    }

    function disable() public {
        require (msg.sender == admin , "Solo el admin puede activar el contrato");
        require (activo, "El contrato ya esta desactivado");

        activo = false;
    }

    // Funciones sobre los centros ****************************************************************************

    //Getters / Setters de los centros.
    function getCentros() public view returns (Centro[] memory) {
        return centros;       
    }

    function _checkIfCentroExiste(address _centroAddress) private view returns (bool) {
        for (uint i = 0; i < centros.length; i++) {
            if (centros[i].direccion == _centroAddress) {
                return true;
            }
        }
        return false;
    }

    function nuevoCentro( address _nuevoCentroAddress, string calldata _nuevoCentroNombre ) public {
        require(activo, "El Storage no esta activo");
        require (msg.sender == aseguradora, "Solo la aseguradora puede gestionar los centros");
        require(_nuevoCentroAddress != address(0), "La nueva direccion NO ha de estar en blanco");
        require(isEmptyString(_nuevoCentroNombre) == false, "Has de informar el nombr edel centro");
        // Require que no exista ya el centro.
        require(_checkIfCentroExiste(_nuevoCentroAddress) == false, "EL centro que intentas agregar ya esta en la lista");

        Centro memory centro  = Centro(_nuevoCentroAddress, _nuevoCentroNombre);
        centros.push(centro);
    }

    function modificaCentro(address _centroAddress, string calldata _nuevoNombre) public {
        //TODO
    }

    function eliminaCentro(address _centroAddress) public {
        //TODO
    }

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
    // Creo y añado una prueba diagnostica a la lista de espera.
    function nuevaPruebaDiagnostica(
        string calldata _idPaciente, 
        string calldata _diagnostico,
        string calldata _codigoPrueba,
        uint16  _maximoDiasDemora,
        uint256 _timestampAlta
        ) public  {

        //La larga lista de validaciones
        require(activo, "El storage no esta activo");
        require(isEmptyString(_idPaciente) == false, "El id del paciente no puede estar vacio");
        require(isEmptyString(_diagnostico) == false, "El diagnostico no puede estar vacio");
        require(isEmptyString(_codigoPrueba) == false, "El codigo de prueba no puede estar vacio");
        require(_esCentroValido(msg.sender), "NO eres un centro permitido para dar de alta un paciente");
        require(_maximoDiasDemora > 0, "No se puede agregar a la lista de espera una prueba  con demora maxima 0 dias");
        require(timeDiffInDays({_newer: block.timestamp ,_older: _timestampAlta }) < 365, "No se pueden agregar pruebas de hace mas de un anyo");
        // Check que el paciente no tenga la misma prueba solicitada con el mismo diaagnostico.
        require(_existePruebaEnPaciente(_idPaciente,_diagnostico, _codigoPrueba) == false, "La prueba ya esta solicitada para ese paciente y para la misma causa ");

        // Genero la id de la siguiente prueba para evitar que haya un error y tenga que hacer rollback restando uno.
        uint256 _nextIdPrueba = nextIdPrueba + 1;
        //Los campos opcionales los genero con los valores by default para que consten vacios.
        PruebaDiagnostica memory prueba = PruebaDiagnostica({
            idPrueba: _nextIdPrueba,
            idPaciente: _idPaciente,
            diagnostico: _diagnostico,
            codigoPrueba: _codigoPrueba,
            centroRealizador: msg.sender,
            timestampAlta: _timestampAlta,
            timestampBaja: 0,
            maximoDiasDemora: _maximoDiasDemora,
            activa: true,
            motivoDeBaja: 0,
            propuestaRedireccion: false,  
            centroDestinoRedireccion: address(0)
        });

        pruebasDiagnosticas[_nextIdPrueba] = prueba;
        // Agrero la prueba a los siguientes mappings
        pruebasPorCentro[prueba.centroRealizador].push(prueba.idPrueba);
        pruebasPorPaciente[prueba.idPaciente].push(prueba.idPrueba);
        //Todo bien, asi que acutalizo el indice de nextIdPrueba global.
        nextIdPrueba = _nextIdPrueba;
    }  

    // Modificamos una prueba, hacemos 2 funciones una parqa modificar los datos de baja y otra para los datos de la redireccion.
    function modificaPruebaDiagnostica(uint256 _idPrueba, uint256 _timestampBaja, uint16 _motivoDeBaja) public {
        
        //Check que exista la prueba 
        require(pruebasDiagnosticas[_idPrueba].idPrueba != 0, "La prueba no existe");
        PruebaDiagnostica storage prueba = pruebasDiagnosticas[_idPrueba];
        require(msg.sender == aseguradora || msg.sender == prueba.centroRealizador, "NO tienes permisos para modificar la prueba Diagnostica");
        require(prueba.activa, "Estas intentando modificar una prueba ya dada de baja");
        require(_timestampBaja > prueba.timestampAlta, "La fecha de baja no puede ser anterior a la fecha de alta");
        require(_timestampBaja <= block.timestamp, "La fecha de baja no puede ser mayor a la fecha actual");

        prueba.timestampBaja = _timestampBaja;
        prueba.motivoDeBaja = _motivoDeBaja;
        //EN caso que tuviera una redireccion , la damos de baja.
        if (prueba.propuestaRedireccion) {
            _eliminaRedireccion(prueba);
        }
        prueba.activa = false;
    }

    function _modificaPruebaDiagnostica(PruebaDiagnostica storage _prueba, uint256 _timestampBaja, uint16 _motivoDeBaja) internal {
        // TODO
    }
  
    function modificaPruebaDiagnostica(uint256 _idPrueba, bool _aceptaRedireccion) public {
        //TODO
    }

    function _modificaPruebaDiagnostica(PruebaDiagnostica storage _prueba, bool _aceptaRedireccion) internal {
        // TODO
    }

    function eliminaPruebaDiagnostica(uint256 _idPrueba) public {
        // TODO
    }

    function _eliminaPruebaDiagnostica(PruebaDiagnostica storage _prueba) internal  {
        //TODO
    }

    // Funciones sobre redirecciones *********************************************************************************************************
    function nuevaRedireccion() public {
        // TODO
    }


    function _eliminaRedireccion(PruebaDiagnostica storage _prueba) internal {        
        require(_prueba.propuestaRedireccion, "La prueba no esta en estado redireccionada");
        /*
            Solo pueden eliminar una redireccion:
                - El centro realizador actual ( porque ya lo ha operado )
                - El centro destinatario ( la  rechaza )
                - La aseguradora ( como admin medico )
        */
        require(msg.sender == _prueba.centroDestinoRedireccion ||
            msg.sender == aseguradora ||
            msg.sender == _prueba.centroRealizador
                , "NO tiens autorizacion para borrar la redireccion");

        //Borramos la redireccion de la prueba
        
        SolicitudRedireccion[] storage _solicitudesRedireccion = solicitudesRedirecciones[_prueba.centroDestinoRedireccion];

        for (uint i = 0; i < _solicitudesRedireccion.length; i++) {
            if (_solicitudesRedireccion[i].idPrueba == _prueba.idPrueba) {
                delete _solicitudesRedireccion[i];
                break;
            }
        }
        _prueba.centroDestinoRedireccion = address(0);
        _prueba.propuestaRedireccion = false;
    }

    function eliminaRedireccion(uint256 _idPrueba) public {
        require(existePrueba(_idPrueba), "La prueba que pasas por parametro no existe");
        PruebaDiagnostica storage prueba = pruebasDiagnosticas[_idPrueba];
        _eliminaRedireccion(prueba);
    }

    // FUnciones de listados *************************************************************************
    function listarPruebasPorPaciente(string calldata _idPaciente) public view returns (uint256[] memory) {
        //TODO
    }

    function listarPruebasPorCentro(address _centro) public view returns (uint256[] memory) {

    }

    function listarRedireccionesPorCentro(address _centro) public view returns (uint256[] memory) {
    }

    // Funciones auxiliares **************************************************************************

    // Comprueba que la direccion esté en la lista de centros válidos.
    function _esCentroValido(address _centro) internal view returns(bool) {
        for(uint16 i = 0; i < centros.length; i++) {
            if (centros[i].direccion == _centro) {
                return true;
            }
        }
        return false;
    }

    function _existePruebaEnPaciente(
        string calldata _idPaciente,
        string calldata _diagnostico, 
        string calldata _codigoPrueba
        ) internal view returns (bool)
        {
            uint256[] memory pruebasDePaciente = pruebasPorPaciente[_idPaciente];
            for (uint i = 0; i < pruebasDePaciente[i]; i++ ) {
                PruebaDiagnostica memory prueba = pruebasDiagnosticas[pruebasDePaciente[i]]; 
                if (compareStrings(prueba.diagnostico, _diagnostico) && 
                    compareStrings(prueba.codigoPrueba, _codigoPrueba)) {
                    return true;
                }
            }
            return false;
    }

    // Funciones de exportacion  de datos*******************************************************************

    //Centros ya lo hemos declarado.
    /*
        En la propia estructura de  datos de PruebaDiagnostica ya tenemos el identificador de centro, los identificadores de la redireccion y de paciente por lo que con 
        esa información ya se deberia ser capaz de reconstruir la bbdd sin tener que pasar los mappings que relacionan.
        Solo faltaría exportar las solicitudes de redireccion de ese instante.
    */

    // pruebasDiagnosticas
    function exportaPruebasDiagnosticas() public view returns (PruebaDiagnostica[] memory) {
        require(msg.sender == admin, "Solo el admin puede obtener todas las pruebas Diagnosticas de la lista de espera");

        PruebaDiagnostica[] memory pruebas = new PruebaDiagnostica[] (nextIdPrueba);
        //OJO!! que la primera prueba qye introducimos tiene id 1.
        for (uint i = 1; i <= nextIdPrueba; i++) {
            pruebas[i] = pruebasDiagnosticas[i];
        }
        return pruebas;
    }
   
}