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

    function appendCentro( address _nuevoCentroAddress, string calldata _nuevoCentroNombre ) public {
        require (msg.sender == aseguradora, "Solo la aseguradora puede gestionar los centros");
        require(_nuevoCentroAddress != address(0), "La nueva direccion NO ha de estar en blanco");
        require(isEmptyString(_nuevoCentroNombre) == false, "Has de informar el nombr edel centro");
        // Require que no exista ya el centro.
        require(_checkIfCentroExiste(_nuevoCentroAddress) == false, "EL centro que intentas agregar ya esta en la lista");

        Centro memory centro  = Centro(_nuevoCentroAddress, _nuevoCentroNombre);
        centros.push(centro);
    }

    /* Funciones para activar y desactivar  el contrato */
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

    /* Funciones sobre las pruebas medicas */
    function getPruebaDiagnostica(uint _idPrueba) public view returns (PruebaDiagnostica memory) {
        require(nextIdPrueba > 0, "No hay registradas ninguna  prueba");
        return pruebasDiagnosticas[_idPrueba];
    }
    // Creo y añado una prueba diagnostica a la lista de espera.
    function newPruebaDiagnostica(
        string calldata _idPaciente, 
        string calldata _diagnostico,
        string calldata _codigoPrueba,
        uint16  _maximoDiasDemora,
        uint256 _timestampAlta
        ) public  {

        //La larga lista de validaciones
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

            return true;
        }

}