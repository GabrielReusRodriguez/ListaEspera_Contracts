// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/*
    Author: Gabriel Reus Rodriguez gabriel.reus[at]pm.me
    En este fichero definimos la interfaz con los eventos que usaremos en todo el sistema de lista de espera. Seran:
        - Alta
        - CreaRedireccion
        - AceptaRedireccion   
        - RechazaRedireccion
        - Baja

    Es muy importante que definamos bien los topics para que la blockchain indexe los eventos en el log por esos campos y podamos filtrarlos con rapidez
*/

//   ***********************************************************************************************************************

interface IListaEsperaEvents {

    /*
        Evento que nos indica el alta de una prueba diagnostica en la lista de espera. 
        Los campos que incluimos en los topics  son:
            - pruebaID: identificador único de la prueba
            - CIP: codigo identificador del paciente
            - centroRealizador: address del centro realizador.
    */
    event Alta(
        uint256 indexed pruebaID, 
        string indexed CIP, 
        address indexed centroRealizador, 
        uint256 timestampAlta, 
        string diagnostico, 
        string codigoPrueba, 
        uint16 prioridad
        );

    /*
        Evento que nos sirve para indicar que se ha creado una petición de redireccion. Los campos topic que usaremos serán:
            - pruebaId: identificador único de la prueba
            - CIP: codigo identificador del paciente
    */
    event CreaRedireccion(
        uint256 indexed pruebaID, 
        string indexed CIP, 
        address centroDestino
        );

    /*
        Evento que nos sirve para indicar que se ha aceptado una petición de redireccion. Los campos topic que usaremos serán:
            - pruebaId: identificador único de la prueba
            - CIP: codigo identificador del paciente
    */
    event AceptaRedireccion(
        uint256 indexed pruebaID, 
        string indexed CIP, 
        address centroDestino
        );

    /*
        Evento que nos sirve para indicar que se ha rechazado una petición de redireccion. Los campos topic que usaremos serán:
            - pruebaId: identificador único de la prueba
            - CIP: codigo identificador del paciente
    */
    event RechazaRedireccion(
        uint256 indexed  pruebaID, 
        string indexed CIP, 
        address centroDestino
        );

    /*
        Evento que nos sirve para indicar que se ha dado de baja de la lista de espera una prueba diagnostica. Los campos topic que usaremos serán:
            - pruebaId: identificador único de la prueba
            - CIP: codigo identificador del paciente
    */
    event Baja(
        uint256 indexed pruebaID, 
        string indexed CIP, 
        uint256 timestampBaja, 
        string motivo
        );

}