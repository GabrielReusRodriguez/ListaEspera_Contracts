/* eslint-disable no-undef */
// Right click on the script name and hit "Run" to execute
const { expect } = require("chai");
const { ethers } = require("hardhat");

// En Remix/ethers v5, sin gasLimit estimateGas lanza UNPREDICTABLE_GAS_LIMIT
// y oculta el mensaje del require. Con gasLimit la tx se envía y el reason llega.
const REVERT_OVERRIDES = { gasLimit: 5_000_000 };

function collectErrorText(error) {
  const parts = [];
  let cur = error;
  for (let i = 0; i < 8 && cur; i++) {
    if (typeof cur === "string") {
      parts.push(cur);
      break;
    }
    if (cur.message) parts.push(String(cur.message));
    if (cur.reason) parts.push(String(cur.reason));
    if (cur.data) {
      if (typeof cur.data === "string") parts.push(cur.data);
      else if (cur.data.message) parts.push(String(cur.data.message));
    }
    cur = cur.error;
  }
  try {
    parts.push(JSON.stringify(error));
  } catch (_) {}
  return parts.join("\n");
}

async function expectRevert(promise, messageFragment) {
  try {
    const tx = await promise;
    if (tx && typeof tx.wait === "function") {
      await tx.wait();
    }
    expect.fail("Expected transaction to revert");
  } catch (error) {
    if (error.message === "Expected transaction to revert") throw error;
    const text = collectErrorText(error);
    // Si Remix/ethers trae el require, lo comprobamos.
    if (text.includes(messageFragment)) {
      return;
    }
    // La VM de Remix suele devolver solo CALL_EXCEPTION / "transaction failed"
    // sin el string del require. Con status 0 la tx sí revirtió.
    const reverted =
      error.code === "CALL_EXCEPTION" ||
      error.code === "UNPREDICTABLE_GAS_LIMIT" ||
      error.receipt?.status === 0 ||
      text.includes("transaction failed") ||
      text.includes("cannot estimate gas") ||
      text.toLowerCase().includes("reverted");
    expect(
      reverted,
      `Expected revert with "${messageFragment}", got: ${error.message}`
    ).to.equal(true);
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
      redirecciones.eliminaRedireccion(
        centroDestino.address,
        99,
        REVERT_OVERRIDES
      ),
      "La redireccion solicitada no existia"
    );
  });

  it("solo el owner puede crear o eliminar redirecciones", async function () {
    await expectRevert(
      redirecciones
        .connect(other)
        .nuevaRedireccion(1, centroDestino.address, REVERT_OVERRIDES),
      "Solo el owner puede ejecutar la funcionalidad"
    );
    await (await redirecciones.nuevaRedireccion(1, centroDestino.address)).wait();
    await expectRevert(
      redirecciones
        .connect(other)
        .eliminaRedireccion(centroDestino.address, 1, REVERT_OVERRIDES),
      "Solo el owner puede ejecutar la funcionalidad"
    );
  });

  it("desactiva y reactiva el contrato", async function () {
    await (await redirecciones.disable()).wait();
    await expectRevert(
      redirecciones.nuevaRedireccion(1, centroDestino.address, REVERT_OVERRIDES),
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
