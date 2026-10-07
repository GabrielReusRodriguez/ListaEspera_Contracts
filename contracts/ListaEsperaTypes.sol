// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/*
    En este fichero declaramos las estructuras comunes a todo el sitema para que la puedan utilizar tanto implementación como storage y las interfaces.
*/

// Definicion de centro medico
struct Centro {
    address direccion;
    string descripcion;
}

// Definicion de prueba diagnostica
struct PruebaDiagnostica {
    uint256     idPrueba;
    string      idPaciente;
    string      diagnostico;
    string      codigoPrueba;
    address     centroRealizador;
    uint256     timestampAlta;
    uint256     timestampBaja;
    uint16      prioridad;
    bool        activa;
    uint16      motivoDeBaja;
    
    //Bonus
    address     centroDestinoRedireccion;
    bool        propuestaRedireccion;
}

// Definicion de solicitud de redireccion
struct SolicitudRedireccion {
    uint256 idPrueba;
    address centroOrigen;
    address centroDestino;
    string idPaciente;
}
