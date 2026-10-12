// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IListaEspera.sol";
import "./IListaEsperaEvents.sol";

contract ListaEspera is IListaEsperaEvents{


    //Resumen del contrato, llamamos a la implementacion y añadimos los eventos. (considero que estan fuera de la implementacion)
    address private addrImplementation;

    address  private admin;
    bool private activo;

    function setAdmin(address _admin) public {
        require(_admin != address(0), "La direccion ha de estar informada");
        require(msg.sender == admin, "Solo el admin puede gestionarlo");
        admin = _admin;
    }

    function setImplementation(address _implementationContract) public {
        require(msg.sender == admin, "Solo el admin puede gestionarlo");
        require(_implementationContract != address(0), "La direccion ha de estar informada");

        addrImplementation = _implementationContract;
    }

    modifier contratoActivo(){
        require(activo, "COntrato no activo");
        _;
    }

    /*
        NO enviamos la direccion de la implementacion  al constructor para evitar dependencias circulares. 
        Implementacion tiene un constructor que necesita ListaEspera como owner y lista de espera loe necesita como implementacion
        SOLUCION: instanciar listaespera  , listaEsperaimpl l(pasandole la address de lista espera ) y luego  al final le hacemo sun set de la addr en listaespera
    
    */
    constructor(address _admin){
        require(_admin != address(0), "admin es zero");
        admin = _admin;
        activo = true;
    }

    // Esta funcion genera una instancia de algo que implementa IListaEspera. De esta forma nos ahorramos llamar
    // Explicitamente al nmombre de la implementacion.
    function _impl() private view returns (IListaEspera) {
        require(addrImplementation != address(0), "Implementacion no configurada");
        return IListaEspera(addrImplementation);
    }

    function alta(
        string calldata _idPaciente, 
        string calldata _codigoPrueba,
        string calldata _diagnostico,
        uint16 _diasDemora,
        uint256 _timestampAlta
        ) external contratoActivo returns (uint256) {
            // Aqui _solcititante debe ser el msg.sender, en la implementacion, no ya que el msg.sender será el owner. 
            IListaEspera implementation = _impl();
            
            uint256 idnuevaPrueba = implementation.alta({
                 _centroRealizador: msg.sender,
                 _idPaciente : _idPaciente,
                 _diagnostico : _diagnostico,
                 _codigoPrueba: _codigoPrueba,
                 _diasDemora : _diasDemora,
                 _timestampAlta : _timestampAlta
            });

            emit Alta({
                pruebaID : idnuevaPrueba,
                CIP: _idPaciente,
                centroRealizador: msg.sender,
                timestampAlta:  _timestampAlta,
                diagnostico : _diagnostico,
                codigoPrueba : _codigoPrueba,
                maximoDiasDemora: _diasDemora
            });
            return idnuevaPrueba;
        }

    function listaPruebasPorPaciente(
        string calldata _idPaciente
    ) external view returns (uint256[] memory) {
        
        IListaEspera implementation = _impl();
        return implementation.listaPruebasPorPaciente(_idPaciente);
    }

    function listaPruebasPorCentro(
        address _centro
    ) external view returns (uint256[] memory)
    {

        IListaEspera implementation = _impl();
        return implementation.listaPruebasPorCentro(_centro);
    }

    function obtenerPruebaPorId(
        uint256 _idPrueba
    ) external view returns (PruebaDiagnostica memory) {

        IListaEspera implementation = _impl();
        return implementation.obtenerPruebaPorId(_idPrueba);
    }

    function creaRedireccion(
        uint256 _idPrueba,
        address _centroDestino
    ) external contratoActivo {

        IListaEspera implementation = _impl();
        implementation.creaRedireccion(msg.sender, _idPrueba, _centroDestino );
        PruebaDiagnostica memory prueba = implementation.obtenerPruebaPorId(_idPrueba);
        emit CreaRedireccion( _idPrueba, prueba.idPaciente, _centroDestino);
    }

    function listaRedireccionesPendientes(
    ) external view returns (uint256 [] memory) {

 
        IListaEspera implementation = _impl();
        return implementation.listaRedireccionesPendientes(msg.sender);
    }

    function aceptaRedireccion(
        uint256 _idPrueba
    ) external contratoActivo {
 
        IListaEspera implementation = _impl();
        implementation.aceptaRedireccion(msg.sender, _idPrueba);
        PruebaDiagnostica memory prueba = implementation.obtenerPruebaPorId(_idPrueba);
        emit AceptaRedireccion( _idPrueba, prueba.idPaciente, msg.sender);
    }
    
    function rechazaRedireccion(
        uint256 _idPrueba
    ) external contratoActivo {
 
        IListaEspera implementation = _impl();
        implementation.rechazaRedireccion(msg.sender, _idPrueba);
        PruebaDiagnostica memory prueba = implementation.obtenerPruebaPorId(_idPrueba);
        emit RechazaRedireccion( _idPrueba, prueba.idPaciente, msg.sender);
    }

    function baja(
        uint256 _idPrueba,
        uint256 _timestampBaja, 
        uint16 _motivoDeBaja
    ) external contratoActivo{
 
        IListaEspera implementation = _impl();
        implementation.baja(msg.sender, _idPrueba, _timestampBaja, _motivoDeBaja);
        PruebaDiagnostica memory prueba = implementation.obtenerPruebaPorId(_idPrueba);
        emit Baja( _idPrueba, prueba.idPaciente, _timestampBaja, _motivoDeBaja);
    }

    function enable() external {
        require(msg.sender == admin, "SOlo el admin puede gestionarlo");
        require(activo == false, "El contrato ya esta activado");

        IListaEspera implementation = _impl();
        implementation.enable();
        activo = true;
    }

    function disable() external {
        require(msg.sender == admin, "SOlo el admin puede gestionarlo");
        require(activo == true, "El contrato ya esta desactivado");

        IListaEspera implementation = _impl();
        implementation.disable();
        activo = false;

    }
}