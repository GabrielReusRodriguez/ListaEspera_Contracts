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

    function setAdmin(address _sender, address _admin) public {
        require (_sender == admin, "NO se te permite cambiar el admin");
        require(_admin != address(0), "La nueva direccion NO ha de estar en blanco");

        admin = _admin;
    }

    // Getters / Setters de la aseguradora.
    function getAseguradora() public view returns(address) {
        return aseguradora;
    }

    function setAseguradora(address _sender, address _aseguradora) public {
        require (_sender == admin, "NO se te permite cambiar el admin");
        require(_aseguradora != address(0), "La nueva direccion NO ha de estar en blanco");

        aseguradora = _aseguradora;
    }

    // Funciones para activar y desactivar  el contrato ************************************************************************
    function enable(address _sender) public {
        require (_sender == admin , "Solo el admin puede activar el contrato");
        require (activo == false, "El contrato ya esta activo");

        activo = true;

    }

    function disable(address _sender) public {
        require (_sender == admin , "Solo el admin puede activar el contrato");
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

    function nuevoCentro( address _sender, address _nuevoCentroAddress, string calldata _nuevoCentroNombre ) public {
        require(activo, "El Storage no esta activo");
        require (_sender == aseguradora, "Solo la aseguradora puede gestionar los centros");
        require(_nuevoCentroAddress != address(0), "La nueva direccion NO ha de estar en blanco");
        require(isEmptyString(_nuevoCentroNombre) == false, "Has de informar el nombre edel centro");
        // Require que no exista ya el centro.
        require(_checkIfCentroExiste(_nuevoCentroAddress) == false, "EL centro que intentas agregar ya esta en la lista");

        Centro memory centro  = Centro(_nuevoCentroAddress, _nuevoCentroNombre, true);
        centros.push(centro);
    }

    function modificaCentro(address _sender, address _centroAddress, string calldata _nuevoNombre) public {
        require(activo, "El Storage no esta activo");
        require(_sender == aseguradora, "Solo la aseguradora puede gestionar los centros");
        require(isEmptyString(_nuevoNombre) == false, "Has de informar el nombre del centro");
        require(_checkIfCentroExiste(_centroAddress) == false, "EL centro que intentas agregar NO esta en la lista");
        
        for ( uint i = 0; i < centros.length; i++) {
            if (centros[i].direccion == _centroAddress) {
                centros[i].nombre = _nuevoNombre;
                break;
            }
        }
    }

    function activaCentro(address _sender, address _centroAddress) public {
        require(activo, "El Storage no esta activo");
        require(_sender == aseguradora, "Solo la aseguradora puede gestionar los centros");
        require(_checkIfCentroExiste(_centroAddress) == false, "EL centro que intentas agregar NO esta en la lista");
        
        for ( uint i = 0; i < centros.length; i++) {
            centros[i].activo = true;
            break;
        }
    }

    function desactivaCentro(address _sender, address _centroAddress) public {
        require(activo, "El Storage no esta activo");
        require(_sender == aseguradora, "Solo la aseguradora puede gestionar los centros");
        require(_checkIfCentroExiste(_centroAddress) == false, "EL centro que intentas agregar NO esta en la lista");

        // requiere que el centro no tenga ninguna derivacion activa ni ni tampoco solicitudes pendientes de responder.
        require( _esCentroConPacientesPendientes(_centroAddress) == true, "El centro aun no puede ser elminiado , ha de revisar sus pruebas");    
        for ( uint i = 0; i < centros.length; i++) {
            centros[i].activo = false;
            break;
        }    
    }

    function _esCentroConPacientesPendientes(address _centroAddress) internal view returns (bool){
        // Si tiene derivaciones pendientes, NO es eliminable, el  usuario ha de rechazarlas primero.        
        if (solicitudesRedirecciones[_centroAddress].length == 0) {
            // Check si tiene alguna prueba pendiente de tramitar, si fuera el caso NO es desactivable, primero ha de atender al paciente o redireccionarlo.
            uint256[] memory _idsPrueba = pruebasPorCentro[_centroAddress];
            for (uint i = 0 ; i < _idsPrueba.length; i++) {
                if (pruebasDiagnosticas[_idsPrueba[i]].activa == true){
                    return false;
                }
            }
            return true;
        }
        return false;
    }


    function _esCentroActivo(address _centroAddress) internal view returns  (bool) {
        require(_centroAddress != address(0), "La direccion enviada es vacia");

        for (uint i = 0; i < centros.length; i++) {
            if (centros[i].direccion == _centroAddress) {
                return centros[i].activo;
            }
        }
        return false;
    }

   // Comprueba que la direccion esté en la lista de centros válidos.
    function _existeCentro(address _centro) internal view returns(bool) {
        for(uint16 i = 0; i < centros.length; i++) {
            if (centros[i].direccion == _centro) {
                return true;
            }
        }
        return false;
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

    // RECUERDA!!! el msg.sender será el contrato de implementacion por lo que siempre hay que pasar el address del wallet que lo ejecuta.
    // Creo y añado una prueba diagnostica a la lista de espera.
    function altaPruebaDiagnostica(
        address _sender,
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
        require(_esCentroActivo(_sender), "NO eres un centro permitido para dar de alta un paciente");
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
            centroRealizador: _sender,
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
    function bajaPruebaDiagnostica(address _sender, uint256 _idPrueba, uint256 _timestampBaja, uint16 _motivoDeBaja) public {
        //Check que exista la prueba 
        require(pruebasDiagnosticas[_idPrueba].idPrueba != 0, "La prueba no existe");
        PruebaDiagnostica storage _prueba = pruebasDiagnosticas[_idPrueba];
        _bajaPruebaDiagnostica(_sender, _prueba, _timestampBaja, _motivoDeBaja);
    }

    function _bajaPruebaDiagnostica(address _sender, PruebaDiagnostica storage _prueba, uint256 _timestampBaja, uint16 _motivoDeBaja) internal {
        require(_sender == aseguradora || _sender == _prueba.centroRealizador, "NO tienes permisos para modificar la prueba Diagnostica");
        require(_prueba.activa, "Estas intentando modificar una prueba ya dada de baja");
        require(_timestampBaja > _prueba.timestampAlta, "La fecha de baja no puede ser anterior a la fecha de alta");
        require(_timestampBaja <= block.timestamp, "La fecha de baja no puede ser mayor a la fecha actual");

        _prueba.timestampBaja = _timestampBaja;
        _prueba.motivoDeBaja = _motivoDeBaja;
        //Eliminamos la prueba de la lista de pacientes y centros, deberia estar el log para el registro.
        //EN caso que tuviera una redireccion , la damos de baja.
        if (_prueba.propuestaRedireccion) {
            _rechazaRedireccion(_sender, _prueba);
        }
        _prueba.activa = false;
    }

    // Funciones sobre redirecciones *********************************************************************************************************

    function nuevaRedireccion(address _sender, uint256 _idPrueba, address _centroDestino ) public {
        require(_esCentroActivo(_sender), "El emisor no es un centro valido para redireccionar");
        require(_esCentroActivo(_centroDestino), "El destino no es un centro activo o valido");
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
    }

    function rechazaRedireccion(address _sender, uint256 _idPrueba) public {
        require (existePrueba(_idPrueba), "La prueba solicitada no existe");
        PruebaDiagnostica storage _prueba  = pruebasDiagnosticas[_idPrueba];
        _rechazaRedireccion(_sender,_prueba);
    }

    function _rechazaRedireccion(address _sender, PruebaDiagnostica storage _prueba) internal {
        require(_esCentroActivo(_sender), "No eres un centro valido para rechazar la redireccion");
        require(_prueba.propuestaRedireccion, "No consta ninguna propuesta de redireccion");
        require(_prueba.centroDestinoRedireccion == _sender, "No eres el centro destino, no puedes rechazar la redireccion");
        _prueba.centroDestinoRedireccion = address(0);
        _prueba.propuestaRedireccion = false;
        _eliminaRedireccion(_sender, _prueba);

    }

    function aceptaRedireccion(address _sender, uint256 _idPrueba) public {
        require (existePrueba(_idPrueba), "La prueba solicitada no existe");
        PruebaDiagnostica storage _prueba  = pruebasDiagnosticas[_idPrueba];
        _aceptaRedireccion(_sender,_prueba);
        
    }

    function _aceptaRedireccion(address _sender, PruebaDiagnostica storage _prueba) internal {
        require(_esCentroActivo(_sender), "No eres un centro valido para aceptar la redireccion");
        require(_prueba.propuestaRedireccion, "No consta ninguna propuesta de redireccion");
        require(_prueba.centroDestinoRedireccion == _sender, "No eres el centro destino, no puedes aceptar la redireccion");        
        _prueba.centroRealizador = _sender;
        _prueba.centroDestinoRedireccion = address(0);
        _prueba.propuestaRedireccion = false;
        _eliminaRedireccion(_sender, _prueba);        

    }

    function _eliminaRedireccion(address _sender, PruebaDiagnostica storage _prueba) internal {        
        require(_prueba.propuestaRedireccion, "La prueba no esta en estado redireccionada");
        /*
            Solo pueden eliminar una redireccion:
                - El centro realizador actual ( porque ya lo ha operado )
                - El centro destinatario ( la  rechaza )
                - La aseguradora ( como admin medico )
        */
        require(_sender == _prueba.centroDestinoRedireccion ||
            _sender == aseguradora ||
            _sender == _prueba.centroRealizador
                , "NO tiens autorizacion para borrar la redireccion");

        //Borramos la redireccion de la prueba
        
        SolicitudRedireccion[] storage _solicitudesRedireccion = solicitudesRedirecciones[_prueba.centroDestinoRedireccion];

        for (uint i = 0; i < _solicitudesRedireccion.length; i++) {
            if (_solicitudesRedireccion[i].idPrueba == _prueba.idPrueba) {
                /*
                    EL delete solo pone el valor de la variable a default pero no elimina la posicion del vector, no lo haec mas corto.
                    Para eso tenemos que mover el valor a la ultima posicion y hacer un pop.
                */
                //delete _solicitudesRedireccion[i];
                uint256 last = _solicitudesRedireccion.length - 1;
                if (i != last) {
                    // Machaco la posicion actual por la ultima
                    _solicitudesRedireccion[i] = _solicitudesRedireccion[last];
                }
                // Hago pop para eliminar del vector la ultima posicion, ahora el vector será más croto
                _solicitudesRedireccion.pop();
                break;
            }
        }
    }

    // FUnciones de listados *************************************************************************
    function listarPruebasPorPaciente(string calldata _idPaciente) public view returns (uint256[] memory) {
        return pruebasPorPaciente[_idPaciente];
    }

    function listarPruebasPorCentro(address _centro) public view returns (uint256[] memory) {
        return pruebasPorCentro[_centro];
    }

    function listarRedireccionesPorCentro(address _centro) public view returns (SolicitudRedireccion[] memory) {
        return solicitudesRedirecciones[_centro];
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