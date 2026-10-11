// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../ListaEsperaTypes.sol";
import "../ListaEsperaCommonFunctions.sol";

contract ListaEsperaStoragePruebasDiagnosticas{

    /*
        Este contrato sirve para guardar los datos del sistema entero. Los declaro como private porque aunque estará en una  blockchain publica 
        y se podrán leer los datos, quiero evitar que alguien desde otro contrato modifique las variables directamente con 
            contato.admin = "0x123434545645645"
        Tendrán que pasar obligatoriamente por la función de set y get que les ofrezco ( una especie de api )
    */

    bool private activo;

    address private owner;

    uint256 nextIdPrueba;


    // Para cada idPrueba, obtenemos los datos enteros de la PruebaDiagnostica
    mapping ( uint256 => PruebaDiagnostica) private pruebasDiagnosticas;

    // Para cada idPaciente, obtenemos los ids de las Pruebas diagnosticas para buscarlo en el anterior mapping.
    mapping ( string => uint256[] ) private pruebasPorPaciente;
    // Para cada centro (address de centro) obtenemos la lista de idPrueba que nos permite obtener la prueba 
    mapping ( address => uint256[] ) private pruebasPorCentro;

    // Modifiers ********************************************************************************************************************************

    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el owner puede ejecutar la funcionalidad");
        _;
    }

    modifier activeContract() {
        require(activo, "El contrato no esta activo");
        _;
    }


    // Constructor
    constructor() {
        /*
            Agrego unos pocos centros de ejemplo.
        */
        activo = true;
        nextIdPrueba = 0;
    }


    // Funciones sobre los admins, propietarios y aseguradoras *************************************************************************************
    function getOwner() public view returns (address) {
        return owner;
    }

    function setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }

    // Funciones para activar y desactivar  el contrato ************************************************************************
    function enable() public onlyOwner {
        require (activo == false, "El contrato ya esta activo");

        activo = true;

    }

    function disable() public onlyOwner {
        require (activo, "El contrato ya esta desactivado");

        activo = false;
    }

    // Funciones sobre los centros ****************************************************************************

    // Funciones sobre las pruebas diagnosticas ******************************************************************************************
    function existePrueba(uint256 _idPrueba) public view onlyOwner returns (bool) {
        if (pruebasDiagnosticas[_idPrueba].idPrueba != 0){
            return true;
        }
        return false;
    }

    function getPruebaDiagnostica(uint _idPrueba) public view onlyOwner returns (PruebaDiagnostica memory) {
        require(nextIdPrueba > 0, "No hay registradas ninguna  prueba");
        require(pruebasDiagnosticas[_idPrueba].idPrueba != 0, "No esiste la prueba reclamada");
        return pruebasDiagnosticas[_idPrueba];
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
        ) public  onlyOwner activeContract {

        //La larga lista de validaciones
        require(isEmptyString(_idPaciente) == false, "El id del paciente no puede estar vacio");
        require(isEmptyString(_diagnostico) == false, "El diagnostico no puede estar vacio");
        require(isEmptyString(_codigoPrueba) == false, "El codigo de prueba no puede estar vacio");
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
            centroRealizador: _centroRealizador,
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
    function bajaPruebaDiagnostica(address _centroRealizador, uint256 _idPrueba, uint256 _timestampBaja, uint16 _motivoDeBaja) public  onlyOwner activeContract{
        //Check que exista la prueba 
        require(pruebasDiagnosticas[_idPrueba].idPrueba != 0, "La prueba no existe");
        PruebaDiagnostica storage _prueba = pruebasDiagnosticas[_idPrueba];
        
        require(_prueba.activa, "Estas intentando modificar una prueba ya dada de baja");
        if (_centroRealizador != address(0)) {
            require(_prueba.centroRealizador == _centroRealizador, "No tienes permiso para dar de baja la prueba");
        }
        require(_timestampBaja > _prueba.timestampAlta, "La fecha de baja no puede ser anterior a la fecha de alta");
        require(_timestampBaja <= block.timestamp, "La fecha de baja no puede ser mayor a la fecha actual");

        _prueba.timestampBaja = _timestampBaja;
        _prueba.motivoDeBaja = _motivoDeBaja;

        _prueba.centroDestinoRedireccion = address(0);
        _prueba.propuestaRedireccion = false;
        _prueba.activa = false;

    }

    function pruebaTieneRedireccion(uint256 _idPrueba) public view onlyOwner returns (bool, address) {
        require(pruebasDiagnosticas[_idPrueba].idPrueba !=  0, "La prueba que nos indicas NO existe");
        PruebaDiagnostica memory prueba  = pruebasDiagnosticas[_idPrueba];
        return (prueba.propuestaRedireccion, prueba.centroDestinoRedireccion);
    }

    // Funciones auxiliares **************************************************************************

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
    function exportaPruebasDiagnosticas() public view onlyOwner returns (PruebaDiagnostica[] memory) {
        //require(msg.sender == admin, "Solo el admin puede obtener todas las pruebas Diagnosticas de la lista de espera");

        PruebaDiagnostica[] memory pruebas = new PruebaDiagnostica[] (nextIdPrueba);
        //OJO!! que la primera prueba qye introducimos tiene id 1.
        for (uint i = 1; i <= nextIdPrueba; i++) {
            pruebas[i] = pruebasDiagnosticas[i];
        }
        return pruebas;
    }
   
}