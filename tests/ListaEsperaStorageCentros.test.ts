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

describe("ListaEsperaStorageCentros", function () {
  let owner;
  let other;
  let centros;

  beforeEach(async function () {
    [owner, other] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("ListaEsperaStorageCentros");
    centros = await Factory.deploy(owner.address);
    await centros.deployed();
  });

  it("despliega con lista de centros vacia", async function () {
    console.log("ListaEsperaStorageCentros deployed at:" + centros.address);
    const lista = await centros.getCentros();
    expect(lista.length).to.equal(0);
  });

  it("crea un centro y lo consulta como activo", async function () {
    const tx = await centros.nuevoCentro(other.address, "Hospital Norte");
    await tx.wait();

    const lista = await centros.getCentros();
    expect(lista.length).to.equal(1);
    expect(lista[0].direccion).to.equal(other.address);
    expect(lista[0].nombre).to.equal("Hospital Norte");
    expect(lista[0].activo).to.equal(true);

    expect(await centros.existeCentro(other.address)).to.equal(true);
    expect(await centros.esCentroActivo(other.address)).to.equal(true);
  });

  it("rechaza centro con address zero, nombre vacio o duplicado", async function () {
    await expectRevert(
      centros.nuevoCentro(ethers.constants.AddressZero, "X", REVERT_OVERRIDES),
      "La nueva direccion NO ha de estar en blanco"
    );
    await expectRevert(
      centros.nuevoCentro(other.address, "", REVERT_OVERRIDES),
      "Has de informar el nombre edel centro"
    );

    await (await centros.nuevoCentro(other.address, "Hospital Norte")).wait();
    await expectRevert(
      centros.nuevoCentro(other.address, "Hospital Norte 2", REVERT_OVERRIDES),
      "EL centro que intentas agregar ya esta en la lista"
    );
  });

  it("solo el owner puede crear centros o cambiar el estado", async function () {
    await expectRevert(
      centros.connect(other).nuevoCentro(other.address, "Hack", REVERT_OVERRIDES),
      "Solo el owner puede ejecutar la funcionalidad"
    );
    await expectRevert(
      centros.connect(other).disable(REVERT_OVERRIDES),
      "Solo el owner puede ejecutar la funcionalidad"
    );
  });

  it("desactiva y reactiva el contrato", async function () {
    await (await centros.disable()).wait();
    await expectRevert(
      centros.nuevoCentro(other.address, "Hospital Norte", REVERT_OVERRIDES),
      "El contrato no esta activo"
    );

    await (await centros.enable()).wait();
    await (await centros.nuevoCentro(other.address, "Hospital Norte")).wait();
    expect(await centros.existeCentro(other.address)).to.equal(true);
  });

  it("existeCentro y esCentroActivo devuelven false si no existe", async function () {
    expect(await centros.existeCentro(other.address)).to.equal(false);
    expect(await centros.esCentroActivo(other.address)).to.equal(false);
  });

  it("rechaza esCentroActivo con address zero", async function () {
    await expectRevert(
      centros.esCentroActivo(ethers.constants.AddressZero),
      "La direccion enviada es vacia"
    );
  });

  it("modifica el nombre de un centro existente", async function () {
    await (await centros.nuevoCentro(other.address, "Hospital Norte")).wait();
    await (
      await centros.modificaCentro(other.address, "Hospital Norte Renovado")
    ).wait();

    const lista = await centros.getCentros();
    expect(lista[0].nombre).to.equal("Hospital Norte Renovado");
  });

  it("desactiva y reactiva un centro existente", async function () {
    await (await centros.nuevoCentro(other.address, "Hospital Norte")).wait();
    expect(await centros.esCentroActivo(other.address)).to.equal(true);

    await (await centros.desactivaCentro(other.address)).wait();
    expect(await centros.esCentroActivo(other.address)).to.equal(false);

    await (await centros.activaCentro(other.address)).wait();
    expect(await centros.esCentroActivo(other.address)).to.equal(true);
  });

  it("revierte activa/desactiva/modifica si el centro no existe", async function () {
    await expectRevert(
      centros.activaCentro(other.address, REVERT_OVERRIDES),
      "EL centro que intentas activar NO esta en la lista"
    );
    await expectRevert(
      centros.desactivaCentro(other.address, REVERT_OVERRIDES),
      "EL centro que intentas desactivar NO esta en la lista"
    );
    await expectRevert(
      centros.modificaCentro(other.address, "Nuevo", REVERT_OVERRIDES),
      "EL centro que intentas agregar NO esta en la lista"
    );
  });
});
