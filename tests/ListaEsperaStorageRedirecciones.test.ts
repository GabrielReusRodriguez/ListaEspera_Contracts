/* eslint-disable no-undef */
// Right click on the script name and hit "Run" to execute
const { expect } = require("chai");
const { ethers } = require("hardhat");

/*
    Funcion que gestiona las otras funciones que se espera que fallen. Lo dará por bueno si detecta un fallo( revert o require del contrato )
*/ 
async function expectRevert(promise, messageFragment) {
  try {
    await promise;
    expect.fail("Expected transaction to revert");
  } catch (error) {
    if (error.message === "Expected transaction to revert") throw error;
    expect(error.message).to.include(messageFragment);
  }
}

describe("ListaEsperaStorageRedirecciones", function () {
  let owner;
  let centroDestino;
  let other;
  let redirecciones;

  beforeEach(async function () {
    [owner, centroDestino, other] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory(
      "ListaEsperaStorageRedirecciones"
    );
    redirecciones = await Factory.deploy(owner.address);
    await redirecciones.deployed();
  });

  it("despliega sin redirecciones pendientes", async function () {
    console.log(
      "ListaEsperaStorageRedirecciones deployed at:" + redirecciones.address
    );
    const lista = await redirecciones.listaRedireccionesPorCentro(
      centroDestino.address
    );
    expect(lista.length).to.equal(0);
  });

  it("crea y lista redirecciones por centro destino", async function () {
    await (await redirecciones.nuevaRedireccion(1, centroDestino.address)).wait();
    await (await redirecciones.nuevaRedireccion(2, centroDestino.address)).wait();

    const lista = await redirecciones.listaRedireccionesPorCentro(
      centroDestino.address
    );
    expect(lista.length).to.equal(2);
    expect(lista[0].toNumber()).to.equal(1);
    expect(lista[1].toNumber()).to.equal(2);
  });

  it("elimina una redireccion existente", async function () {
    await (await redirecciones.nuevaRedireccion(10, centroDestino.address)).wait();
    await (await redirecciones.nuevaRedireccion(20, centroDestino.address)).wait();
    await (
      await redirecciones.eliminaRedireccion(centroDestino.address, 10)
    ).wait();

    const lista = await redirecciones.listaRedireccionesPorCentro(
      centroDestino.address
    );
    expect(lista.length).to.equal(1);
    expect(lista[0].toNumber()).to.equal(20);
  });

  it("revierte al eliminar una redireccion inexistente", async function () {
    await expectRevert(
      redirecciones.eliminaRedireccion(centroDestino.address, 99),
      "La redireccion solicitada no existia"
    );
  });

  it("solo el owner puede crear o eliminar redirecciones", async function () {
    await expectRevert(
      redirecciones.connect(other).nuevaRedireccion(1, centroDestino.address),
      "Solo el owner puede ejecutar la funcionalidad"
    );
    await (await redirecciones.nuevaRedireccion(1, centroDestino.address)).wait();
    await expectRevert(
      redirecciones
        .connect(other)
        .eliminaRedireccion(centroDestino.address, 1),
      "Solo el owner puede ejecutar la funcionalidad"
    );
  });

  it("desactiva y reactiva el contrato", async function () {
    await (await redirecciones.disable()).wait();
    await expectRevert(
      redirecciones.nuevaRedireccion(1, centroDestino.address),
      "El contrato no esta activo"
    );
    await (await redirecciones.enable()).wait();
    await (await redirecciones.nuevaRedireccion(1, centroDestino.address)).wait();
    const lista = await redirecciones.listaRedireccionesPorCentro(
      centroDestino.address
    );
    expect(lista.length).to.equal(1);
  });
});
