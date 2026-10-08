# Planning del proyecto lista de espera de pruebas diagnosticas

Propuesta de diseño una lista de espera de pruebas diagnosticas con Blockchain. Se trata de una prueba de concepto de una lista de espera médica SIMPLIFICADA con fines puramente académicos. 

Este proyecto se ha hecho para la microcredencial universitaria de  Tecnologías Blockchain, Contratos Inteligentes, Aplicaciones Descentralizadas y la Web 3.0 por parte del alumno (Gabriel Reus)[https://github.com/GabrielReusRodriguez]

## Notas funcionales

Las funcionalidades que ha de soportar son:
  - Alta de paciente en la lista.
  - Baja de paciente de la lista.
  - Listar Pruebas por paciente
  - Listar Pruebas por centro
  - Obtener una prueba.
  - Mostrar histórico de eventos de una prueba
  - Crear Redireccion de paciente (BONUS)
  - Aceptar / Rechazar Redireccion de paciente (BONUS)
  - Listar redirecciones pendientes de acepetar (BONUS)

### Alta en lista de espera

Cada prueba diagnostica ha de tener informado en el momento de alta:
  - CIP del paciente
  - Fecha de alta en la lista
  - Codigo de la prueba a realizar ( en SNOMED )
  - Codigo del diagnóstico de sospecha por la que se pide la prueba ( en cie10 ).
  - Prioridad de la prueba: demora máxima en días.
  - Referencia al centro que la pide.

Catsalut marca las prioridades en dos tipos
  - Prioridad preferente, máximo 30 dias.
  - Prioridad ordinaria, máximo 90 dias.

Cuando se de de alta al paciente, se generará un identificador único de prueba de lista de espera.
  
Por temas de confidencialidad, del Codigo Identificador de Paciente (CIP) se guardará un hash para evitar problemas legales ya que la información es publica en la blockchain.

**MUY IMPORTANTE:** al dar de alta una nueva prueba, se ha de verificar que ese paciente no esté ya de alta en la lista de espera  para la misma prueba y diagnostico de sospecha.

### Baja de la lista de espera

Se da da baja de lista de espera al paciente para la prueba que solicitó.
Los motivos de baja de lista de espera son:
  1. Intervencion programada en el hospital: se realiza la prueba, la fecha de baja es la de la realizacion de la prueba
  2. Demanda satisfecha en urgencias : Antes de ser programado, el paciente acude  a urgencias y es atendido por el mismo proceso que estaba en espera
  3. Demanda satisfecha en centro privado /concertado: El paciente aceptó la derivacion a un centro concertado y es atendido por el mismo proceso.
  4. Por indicación clínica: un medico mediante informe, establece una contraindicacion permanente o que ya no se necesita la prueba o intervencion que motivó la inclusion
  5. Por renuncia voluntaria: el paciente manifiesta que aún sin haber resuelto el probema y sin contraindicacion médica,no está interesado a someterse en el proceso.
  6. Por aplazamiento por decision del paciente: El paciente solicita poponer la intervencion o prueba por un periodo indefinido.
  7. Por inclusion en otro centro del porpio servicio de salud: el paciente acepta la derivación a otro hospital público y se inscribe ne la lista del centro de destino por el mismo proceso ( transfiere la espera, no la elimina )
  8. Exitus del paciente: por fallecimiento.

### Listar Pruebas por paciente
Dado un CIP de paciente, se devuelve una lista de las pruebas en las que está apuntado. 

### Listar Pruebas por centro
Dado un centro realizador, se devuelve una lista de las pruebas que tiene asignadas.

### Crear Redireccion de paciente
Un centro puede elegir un paciente que tenga en SU lista de espera y proponer que se traslade a la lista de espera de otro centro con las mismas condiciones que ya tiene. La petición quedará en espera de que se acepte o rechace.

Cada prueba puede tener como mucho 1 petición de redirección activa.

### Listar redirecciones pendientes de aceptar
Cada centro puede consultar las peticiones de redireccion que tiene pendientes de responder.

### Aceptar / Rechazar Redireccion de paciente
El centro destinatario de la redirección  consulta su lista de redirecciones y acepta o rechaza la redirección.
En caso que la acepte la prueba pasa a tener el centro destinatario como centro realizador y **NO DEBEN CAMBIAR EL RESTO DE DATOS**

### Mostrar histórico de eventos de una prueba
Dado un paciente, se ha de devolver todos los eventos /cambios que ha tenido esa prueba.





## Diseño de la solución 

La implementación se hará  mediante contratos inteligentes en solidity y un frontend web en React 

## Arquitectura

Se decide crear una arquitectura de proxy. En ella habrán varios contratos contratos que cumplirian los siguientes roles:
  - Contrato Proxy
  - Contrato Almacenamiento de datos
  - Contrato Implementacion de la logica de negocio
  - Interface IEvents con los eventos
  - Interface IFunctions con las funciones básicas a implementar en Proxy y las diferentes implementaciones.
  - Contrato ListaEsperaTypes con las definiciones de estructuras necesarias. Así podemos reaprovecharlas en las interfaces, storage e implementacion haciendo un import.
  - Contrato ListaEsperaCommonFunctions con las funciones auxiliares clasicas como por ejemplo manejo de strings ( asi evitamos escribirlas n veces)

  NOTA: Ejemplos de interfaces:

  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.10;
  
  interface IListaEsperaEvents {
      event Created(address indexed owner, uint256 id);
      event Updated(uint256 indexed id, uint256 value);
  }

interface IListaEspera is IListaEsperaEvents {
    function add(uint256 listId) external;
    function remove(uint256 listId) external;
}

contract Logic is IListaEspera {
    function add(uint256 listId) external override {
        emit UserAdded(msg.sender, listId);
    }
    function remove(uint256 listId) external override {
        emit UserRemoved(msg.sender, listId);
    }
}
```

## Estructuras de datos.

Existirá una address administrador y una address de la aseguradora. Serán quienes ejercerán los roles de propietario y administrador de los contratos.

```solidity
    address public admin;
    address public aseguradora;
```

TODO pensar como traducir las address a literal de centro. problemA: si añadimos un nuevo centro o lo eliminamos... se tendría que regenerar el contrato.

Por otra parte, cada centro tendra su propia wallet con su address para firmar las transacciones. También e

Propuesta: hacer una lista de address

```solidity
struct Centro {
    address direccion;
    string  nombre;
}

Centro[] public centros;
```
**Esto comporta hacer funciones para agregar y eliminar centros**

Las estructuras de datos de la prueba seria la siguiente:

```solidity
//Describe una prueba diagnostica
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
    address     centroDestinoRedirección;
    bool        propuestaRedireccion;
}
``` 

Se implementarán los siguientes mappings:

```solidity
// Para cada idPrueba, obtenemos los datos enteros de la PruebaDiagnostica
mapping ( uint256 => PruebaDiagnostica) public pruebasDiagnosticas;
// Para cada idPaciente, obtenemos los ids de las Pruebas diagnosticas para buscarlo en el anterior mapping.
mapping ( string => uint256[] ) public pruebasPorPaciente;
// Para cada centro (address de centro) obtenemos la lista de idPrueba que nos permite obtener la prueba 
mapping ( address => uint256[] ) public pruebasPorCentro;
``` 

## Funcionalidades implementadas

### Alta 

Para el alta se creará una función que recibirá los datos. Pero ha de validar lo siguiente:
  - Todos los datos vienen correctament informados.
  - Que no tenga abierto otra prueba igual **activa** para el mismo paciente (aunque sea en otro centro).

En caso que cumpla los requisitos, se crea las estructuras y se insertan en los mappings de pruebasPorPaciente y pruebasPorCentro.

### Baja
Para la baja, se  creará una función que recibirá los datos y validará lo siguiente:
  - Todos los datos vienen correctamente informados.
  - El paciente "pertenece" a la lista del centro que llama a la funcion o el address que llama es el de la aseguradora publica. 

Una vez validado se harán las siguientes acciones: 
  - Eliminar las peticiones de redireccion existentes.
  - Modificar la PruebaDiagnostica para que figure la fecha de baja y el motivo de baja.
  - Marcar el flag de activo a false.

### Redireccion

Para las redirecciones, la idea es hacer un mapping  con clave address del centro destino donde se guarden los datos necesarios para localizar la prueba.  Así cada centro sabe cuantas redirecciones tiene pendiente de aceptar / rechazar.

Se hará una estructura  de solicitud de redirección

```solidity
struct SolicitiudRedireccion {
    uint256 id;
    address centroOrigen;
    address centroDestino;
    string idPaciente;
}
```

Se guardará en un mapping

```solidity
mapping(address => SolicitudRedireccion []) public SolicitudesRedireccion;
```

La idea es que el centro destino consulte su lista de solicitudes de redireccion y acepte o rechace la petición.
  - Si la acepta:
      - En la prueba diagnostica:
          - Se cambia el centro realizador en la prueba diagnostcia
          - Se pone a false propuestaRedireccion
          - Se pone a address(0) centroDestinoRedireccion
      - En el mapping SolicitudesRedireccion se borra la entrada .
      - En pruebasPorCentro se elimina la antigua entrada  y  se agrega la nueva.
  - Si la rechaza
      - En la prueba diagnostica:
          - Se cambia el centro realizador en la prueba diagnostcia
          - Se pone a false propuestaRedireccion
          - Se pone a address(0) centroDestinoRedireccion


Las validaciones que ha de hacer:
  - Para crear redireccion:
      - Que el centro que la crea, tiene al paciente asignado
      - Que la prueba que se redirecciona está activa
      - Que no exista otra redireccion 
  - Para aceptar / rechazar :
      - Que el centro que acepta/rechaza la validacion  es centro destino de la redireccion
      - Que el la prueba redireccionada está activa.


## Eventos

Se necesitan los siguientes eventos:
```solidity
event Alta(uint256 indexed pruebaID, string indexed CIP, uint256 timestampAlta, string diagnostico, string codigoPrueba, uint16 prioridad, address indexed centroRealizador);
event CreaRedireccion(uint256 indexed pruebaID, string indexed CIP, address centroDestino);
event AceptaRedireccion(uint256 indexed pruebaID, string indexed CIP, address centroDestino);
event RechazaRedireccion(uint256 indexed  pruebaID, string indexed CIP, address centroDestino);
event Baja(uint256 indexed pruebaID, string indexed CIP, uint256 timestampBaja, string motivo)
```

Recuerda que el modificador indexed es el que indica  a solidity que ese parametro lo ocnvierte en topic que permite filtrarlo eficientement en los logs.
