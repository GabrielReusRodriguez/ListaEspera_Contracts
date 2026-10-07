// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ListaEsperaTypes.sol";

contract ListaEsperaStorage{

    /*
        Este contrato sirve para guardar los datos del sistema entero. Los declaro como private porque aunque estará en una  blockchain publica 
        y se podrán leer los datos, quiero evitar que alguien desde otro contrato modifique las variables directamente con 
            contato.admin = "0x123434545645645"
        Tendrán que pasar obligatoriamente por la función de set y get que les ofrezco ( una especie de api )
    */

    // Address del administrador
    address private admin ;
    // Address de la aseguradora, vendria a ser el servicio publico de salud.
    address private aseguradora;

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

    function appendCentro( address _nuevoCentroAddress, string calldata _nuevoCentroDescripcion ) public {
        require (msg.sender == aseguradora, "Solo la aseguradora puede gestionar los centros");
        require(_nuevoCentroAddress != address(0), "La nueva direccion NO ha de estar en blanco");
        // Require que no exista ya el centro.
        require(_checkIfCentroExiste(_nuevoCentroAddress) == false, "EL centro que intentas agregar ya esta en la lista");

        Centro memory centro  = Centro(_nuevoCentroAddress, _nuevoCentroDescripcion);
        centros.push(centro);
    }

}