// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../ListaEsperaTypes.sol";
import "../ListaEsperaCommonFunctions.sol";

contract ListaEsperaStorageCentros{

    /*
        Este contrato sirve para guardar los datos del sistema entero. Los declaro como private porque aunque estará en una  blockchain publica 
        y se podrán leer los datos, quiero evitar que alguien desde otro contrato modifique las variables directamente con 
            contato.admin = "0x123434545645645"
        Tendrán que pasar obligatoriamente por la función de set y get que les ofrezco ( una especie de api )
    */

    bool private activo;

    address private owner;

    /* 
    Inventarios de centros. Se decide hacerlo como array en vez de hashtable ya que se ha de listar muchas veces y se calcula que habrán como mucho  50 centros?
    */
    Centro[] private centros;


    //Modifiers ***************************************************************************************************
    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el owner puede ejecutar la funcionalidad");
        _;
    }

    modifier activeContract() {
        require(activo, "El contrato no esta activo");
        _;
    }


    // Para cada centro (address de centro) obtenemos la lista de idPrueba que nos permite obtener la prueba 
//    mapping ( address => uint256[] ) private pruebasPorCentro;
    // Para cada centro (address de centro) obtenemos la lista de solicitudes de redireccion que ha recibido.

    // Constructor
    constructor() {
        owner  = msg.sender;
        /*
            Agrego unos pocos centros de ejemplo.
        */
        activo = true;
   }


    // Funciones sobre los admins, propietarios y aseguradoras *************************************************************************************
    // Getters / Setteers de admin
    function getOwner() public view returns(address) {
        return owner;
    }

    function setOwner(address _owner) public onlyOwner {
        require(_owner != address(0), "La nueva direccion NO ha de estar en blanco");

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

    function nuevoCentro(address _nuevoCentroAddress, string calldata _nuevoCentroNombre ) public onlyOwner activeContract {
        //require (_sender == aseguradora, "Solo la aseguradora puede gestionar los centros");
        require(_nuevoCentroAddress != address(0), "La nueva direccion NO ha de estar en blanco");
        require(isEmptyString(_nuevoCentroNombre) == false, "Has de informar el nombre edel centro");
        // Require que no exista ya el centro.
        require(_checkIfCentroExiste(_nuevoCentroAddress) == false, "EL centro que intentas agregar ya esta en la lista");

        Centro memory centro  = Centro(_nuevoCentroAddress, _nuevoCentroNombre, true);
        centros.push(centro);
    }

    function modificaCentro(address _centroAddress, string calldata _nuevoNombre) public onlyOwner activeContract {
        //require(_sender == aseguradora, "Solo la aseguradora puede gestionar los centros");
        require(isEmptyString(_nuevoNombre) == false, "Has de informar el nombre del centro");
        require(_checkIfCentroExiste(_centroAddress) == false, "EL centro que intentas agregar NO esta en la lista");
        
        for ( uint i = 0; i < centros.length; i++) {
            if (centros[i].direccion == _centroAddress) {
                centros[i].nombre = _nuevoNombre;
                break;
            }
        }
    }

    function activaCentro(address _centroAddress) public onlyOwner activeContract {
        //require(_sender == aseguradora, "Solo la aseguradora puede gestionar los centros");
        require(_checkIfCentroExiste(_centroAddress) == false, "EL centro que intentas agregar NO esta en la lista");
        
        for ( uint i = 0; i < centros.length; i++) {
            if (centros[i].direccion == _centroAddress) {
                centros[i].activo = true;
                break;
            }
        }
    }

    function desactivaCentro(address _centroAddress) public onlyOwner activeContract {
        //require(_sender == aseguradora, "Solo la aseguradora puede gestionar los centros");
        require(_checkIfCentroExiste(_centroAddress) == false, "EL centro que intentas agregar NO esta en la lista");

        // requiere que el centro no tenga ninguna derivacion activa ni ni tampoco solicitudes pendientes de responder.
  //      require( _esCentroConPacientesPendientes(_centroAddress) == true, "El centro aun no puede ser elminiado , ha de revisar sus pruebas");    
        for ( uint i = 0; i < centros.length; i++) {
            if (centros[i].direccion == _centroAddress) {
                centros[i].activo = false;
                break;
            }
        }    
    }

    function esCentroActivo(address _centroAddress) public view onlyOwner returns  (bool) {
        require(_centroAddress != address(0), "La direccion enviada es vacia");

        for (uint i = 0; i < centros.length; i++) {
            if (centros[i].direccion == _centroAddress) {
                return centros[i].activo;
            }
        }
        return false;
    }

   // Comprueba que la direccion esté en la lista de centros válidos.
    function existeCentro(address _centro) public view onlyOwner returns(bool) {
        for(uint16 i = 0; i < centros.length; i++) {
            if (centros[i].direccion == _centro) {
                return true;
            }
        }
        return false;
    }
}