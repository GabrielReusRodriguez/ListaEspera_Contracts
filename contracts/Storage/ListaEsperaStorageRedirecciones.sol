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

    address private immutable owner;

    // Para cada centro (address de centro) obtenemos la lista de solicitudes de redireccion que ha recibido.
    //mapping(address => SolicitudRedireccion[]) private solicitudesRedirecciones;
    mapping(address => uint256[]) private solicitudesRedirecciones;
    
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
    constructor(address _owner) {
        require(_owner != address(0), "Owner zero");
        owner = _owner;
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
        address _centroDestino
            ) public onlyOwner activeContract {

        uint256[] storage  redireccionesPorCentro = solicitudesRedirecciones[_centroDestino];
        redireccionesPorCentro.push(_idPrueba);
    }

    function eliminaRedireccion(address _centroDestinoRedireccion, uint256 _idPrueba) public onlyOwner activeContract {        
        //Borramos la redireccion de la prueba
        
        uint256[] storage _solicitudesRedireccion = solicitudesRedirecciones[_centroDestinoRedireccion];

        for (uint i = 0; i < _solicitudesRedireccion.length; i++) {
            if (_solicitudesRedireccion[i] == _idPrueba) {
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
                return;
            }
        }
        revert("La redireccion solicitada no existia");
    }

    function listaRedireccionesPorCentro(address _centroDestinoRedireccion) public view onlyOwner returns (uint256[] memory) {
        return solicitudesRedirecciones[_centroDestinoRedireccion];
    }


}