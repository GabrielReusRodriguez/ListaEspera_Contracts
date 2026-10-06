# Planning del proyecto lista de espera de pruebas diagnosticas

Propuesta de diseño de lista de espera de pruebas diagnosticas con Blockchain.

## Notas funcionales


Catsalut marca las prioridades en tres tipos
    - Prioridad preferente , máximo 30 dias
    - Prioridad ordinaria , máximo 90 dias.

Los motivos de baja de lista de espera son:
    - 1. Intervencion programada en el hospital: se realiza la prueba, la fecha de baja es la de la realizacion de la prueba
    - 2. Demanda satisfecha en urgencias : Antes de ser programado, el paciente acude  a urgencias y es atendido por el mismo proceso que estaba en espera
    - 3. Demanda satisfecha en centro privado /concertado: El paciente acep´to la derivacion a un centro concertado y es atendido por el mismo proceso.
    - 4. Por indicación clínica: un medico mediante informe, establece una contraindicacion permanente o que ya no se necesita la prueba o intervencion que motivó la inclusion
    - 5. Por renuncia voluntaria: el paciente manifiesta que aún sin haber resuelto el probema y sin contraindicacion médica,no está interesado a someterse en el proceso.
    - 6. Por aplaamiento por decision del paciente: El paciente solicita poponer la intervencion o prueba por un periodo indefinido.
    - 7. Por inclusion en otro centro del porpio servicio de salud: el paciente acepta la derivación a otro hospital público y se inscribe ne la lista del centro de destino por el mismo proceso ( transfiere la espera, no la elimina )
    - 8. Exitus del paciente: por fallecimiento.


## Acciones posibles 

Las acciones que se implementarán serían:
    - Alta en lista de espera
    - Baja en lista de espera
    - Listar Pruebas por paciente
    - Listar Pruebas por centro
    - Crear Redireccion de paciente (BONUS)
    - Aceptar / Rechazar Redireccion de paciente (BONUS)
    - Listar redirecciones pendientes de acepetar (BONUS)

## Enfoque 

La implementación se hará  en solidity. La idea es que cada centro tengra su propia wallet con su address para firmar las transacciones. También existirá una address administrador y una address de la aseguradora.

```solidity
    address public admin;
    address public aseguradora;
```

TODO pensar como traducir las address a literal de centro. problemA: si añadimos un nuevo centro o lo eliminamos... se tendría que regenerar el contrato.


Propuesta: hacer una lista de address

```solidity
struct Centro {
    address direccion;
    string descripcion;
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
