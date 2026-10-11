// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../ListaEsperaTypes.sol";
import "../ListaEsperaCommonFunctions.sol";

contract ListaEsperaStorageRedirecciones{

    /*
        Este contrato sirve para guardar los datos del sistema entero. Los declaro como private porque aunque estará en una  blockchain publica 
        y se podrán leer los datos, quiero evitar que alguien desde otro contrato modifique las variables directamente con 
            contato.admin = "0x123434545645645"
        Tendrán que pasar obligatoriamente por la función de set y get que les ofrezco ( una especie de api )
    */

    bool private activo;

    address private owner;

    // Para cada centro (address de centro) obtenemos la lista de solicitudes de redireccion que ha recibido.
    mapping(address => SolicitudRedireccion[]) private solicitudesRedirecciones;

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
        owner = msg.sender;
        /*
            Agrego unos pocos centros de ejemplo.
        */
        activo = true;
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

    // Funciones sobre redirecciones *********************************************************************************************************

    function nuevaRedireccion(
        uint256 _idPrueba, 
        string calldata _idPaciente, 
        address _centroOrigen, 
        address _centroDestino 
            ) public onlyOwner activeContract {
        //require(_esCentroActivo(_sender), "El emisor no es un centro valido para redireccionar");
        //require(_esCentroActivo(_centroDestino), "El destino no es un centro activo o valido");
        //require(_sender != _centroDestino, "El origen y el destino no pueden ser el mismo centro");
        //require(pruebasDiagnosticas[_idPrueba].idPrueba != 0, "La prueba no existe");
        //require(pruebasDiagnosticas[_idPrueba].activa  == true, "La prueba no esta activa");
        //require(pruebasDiagnosticas[_idPrueba].propuestaRedireccion == false, "La prueba ya tiene una propuesta de redireccion");

        SolicitudRedireccion[] storage  redireccionesPorCentro = solicitudesRedirecciones[_centroDestino];
        SolicitudRedireccion memory redireccion = SolicitudRedireccion({
            idPrueba        : _idPrueba,
            centroOrigen    : _centroOrigen,
            centroDestino   : _centroDestino,
            idPaciente      : _idPaciente
        });
        redireccionesPorCentro.push(redireccion);
        //prueba.centroDestinoRedireccion = _centroDestino;
        //prueba.propuestaRedireccion = true;
    }

    function getRedireccion(address _centroDestinoRedireccion, uint256 _idPrueba) public view onlyOwner activeContract returns (SolicitudRedireccion memory ) {
        SolicitudRedireccion[] memory solicitudes = solicitudesRedirecciones[_centroDestinoRedireccion];
        for (uint i = 0; i < solicitudes.length; i++) {
            if (solicitudes[i].idPrueba == _idPrueba) {
                return solicitudes[i];
            }
        }
        revert("Redireccion NO encontrada");
    }

    function eliminaRedireccion(address _centroDestinoRedireccion, uint256 _idPrueba) public onlyOwner activeContract {        
         //require(_prueba.propuestaRedireccion, "La prueba no esta en estado redireccionada");
        
        /*
            Solo pueden eliminar una redireccion:
                - El centro realizador actual ( porque ya lo ha operado )
                - El centro destinatario ( la  rechaza )
                - La aseguradora ( como admin medico )
        */
        /*
        require(_sender == _prueba.centroDestinoRedireccion ||
            _sender == aseguradora ||
            _sender == _prueba.centroRealizador
                , "NO tiens autorizacion para borrar la redireccion");
        */
        //Borramos la redireccion de la prueba
        
        SolicitudRedireccion[] storage _solicitudesRedireccion = solicitudesRedirecciones[_centroDestinoRedireccion];

        for (uint i = 0; i < _solicitudesRedireccion.length; i++) {
            if (_solicitudesRedireccion[i].idPrueba == _idPrueba) {
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
  
}