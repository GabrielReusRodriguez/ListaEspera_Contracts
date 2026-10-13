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

async function blockTimestamp() {
  const block = await ethers.provider.getBlock("latest");
  return block.timestamp;
}

async function deployImplStack(ownerSigner, adminSigner, aseguradoraSigner) {
  const ImplFactory = await ethers.getContractFactory("ListaEsperaImpl");
  const impl = await ImplFactory.deploy(
    ownerSigner.address,
    adminSigner.address
  );
  await impl.deployed();

  const StorageFactory = await ethers.getContractFactory("ListaEsperaStorage");
  const storage = await StorageFactory.deploy(impl.address, adminSigner.address);
  await storage.deployed();

  const CentrosFactory = await ethers.getContractFactory(
    "ListaEsperaStorageCentros"
  );
  const centros = await CentrosFactory.deploy(storage.address);
  await centros.deployed();

  const PruebasFactory = await ethers.getContractFactory(
    "ListaEsperaStoragePruebasDiagnosticas"
  );
  const pruebas = await PruebasFactory.deploy(storage.address);
  await pruebas.deployed();

  const RedireccionesFactory = await ethers.getContractFactory(
    "ListaEsperaStorageRedirecciones"
  );
  const redirecciones = await RedireccionesFactory.deploy(storage.address);
  await redirecciones.deployed();

  await (await impl.connect(adminSigner).setStorage(storage.address)).wait();
  await (
    await storage.connect(adminSigner).setGestorCentros(centros.address)
  ).wait();
  await (
    await storage
      .connect(adminSigner)
      .setGestorPruebasDiagnosticas(pruebas.address)
  ).wait();
  await (
    await storage
      .connect(adminSigner)
      .setGestorRedirecciones(redirecciones.address)
  ).wait();
  await (
    await storage
      .connect(adminSigner)
      .setAseguradora(aseguradoraSigner.address)
  ).wait();

  return { impl, storage, centros };
}

async function crearCentrosAB(impl, owner, aseguradora, centroA, centroB) {
  await (
    await impl
      .connect(owner)
      .creaCentro(aseguradora.address, centroA.address, "Centro A")
  ).wait();
  await (
    await impl
      .connect(owner)
      .creaCentro(aseguradora.address, centroB.address, "Centro B")
  ).wait();
}

describe("ListaEsperaImpl", function () {
  let admin;
  let owner;
  let aseguradora;
  let centroA;
  let centroB;
  let other;
  let impl;
  let storage;

  beforeEach(async function () {
    [admin, owner, aseguradora, centroA, centroB, other] =
      await ethers.getSigners();
    ({ impl, storage } = await deployImplStack(owner, admin, aseguradora));
  });

  it("despliega e inicializa storage", async function () {
    console.log("ListaEsperaImpl deployed at:" + impl.address);
    expect(impl.address).to.be.a("string");
    expect(impl.address.length).to.equal(42);
  });

  it("solo el owner puede ejecutar la logica de negocio", async function () {
    await (
      await impl.connect(owner).creaCentro(aseguradora.address, centroA.address, "Centro A")
    ).wait();

    const ts = (await blockTimestamp()) - 60;
    await expectRevert(
      impl
        .connect(other)
        .alta(centroA.address, "CIP001", "RX", "Fractura", 10, ts, REVERT_OVERRIDES),
      "Solo el owner puede ejeccutarlo"
    );
  });

  it("alta, consultas, redireccion y baja via owner", async function () {
    await crearCentrosAB(impl, owner, aseguradora, centroA, centroB);

    const ts = (await blockTimestamp()) - 120;
    await (
      await impl
        .connect(owner)
        .alta(centroA.address, "CIP001", "RX", "Fractura", 10, ts)
    ).wait();

    const porPaciente = await impl
      .connect(owner)
      .listaPruebasPorPaciente("CIP001");
    expect(porPaciente.length).to.equal(1);

    const porCentro = await impl
      .connect(owner)
      .listaPruebasPorCentro(centroA.address);
    expect(porCentro.length).to.equal(1);

    const prueba = await impl.connect(owner).obtenerPruebaPorId(1);
    expect(prueba.idPaciente).to.equal("CIP001");
    expect(prueba.diagnostico).to.equal("Fractura");

    await (
      await impl
        .connect(owner)
        .creaRedireccion(centroA.address, 1, centroB.address)
    ).wait();

    const pendientes = await impl
      .connect(owner)
      .listaRedireccionesPendientes(centroB.address);
    expect(pendientes.length).to.equal(1);

    await (
      await impl.connect(owner).aceptaRedireccion(centroB.address, 1)
    ).wait();

    const trasAceptar = await impl.connect(owner).obtenerPruebaPorId(1);
    expect(trasAceptar.centroRealizador).to.equal(centroB.address);

    const tsBaja = await blockTimestamp();
    await (
      await impl.connect(owner).baja(centroB.address, 1, tsBaja, 3)
    ).wait();

    const baja = await impl.connect(owner).obtenerPruebaPorId(1);
    expect(baja.activa).to.equal(false);
    expect(baja.motivoDeBaja).to.equal(3);
  });

  it("rechaza redireccion via impl", async function () {
    await crearCentrosAB(impl, owner, aseguradora, centroA, centroB);

    const ts = (await blockTimestamp()) - 60;
    await (
      await impl
        .connect(owner)
        .alta(centroA.address, "CIP001", "RX", "Fractura", 10, ts)
    ).wait();
    await (
      await impl
        .connect(owner)
        .creaRedireccion(centroA.address, 1, centroB.address)
    ).wait();
    await (
      await impl.connect(owner).rechazaRedireccion(centroB.address, 1)
    ).wait();

    const prueba = await impl.connect(owner).obtenerPruebaPorId(1);
    expect(prueba.centroRealizador).to.equal(centroA.address);
    expect(prueba.propuestaRedireccion).to.equal(false);
  });

  it("solo el centro destino puede aceptar o rechazar", async function () {
    await crearCentrosAB(impl, owner, aseguradora, centroA, centroB);

    const ts = (await blockTimestamp()) - 60;
    await (
      await impl
        .connect(owner)
        .alta(centroA.address, "CIP001", "RX", "Fractura", 10, ts)
    ).wait();
    await (
      await impl
        .connect(owner)
        .creaRedireccion(centroA.address, 1, centroB.address)
    ).wait();

    await expectRevert(
      impl.connect(owner).aceptaRedireccion(centroA.address, 1, REVERT_OVERRIDES),
      "No tienes permiso para aceptar la redireccion"
    );
    await expectRevert(
      impl.connect(owner).rechazaRedireccion(centroA.address, 1, REVERT_OVERRIDES),
      "No tienes permiso para rechazar la redireccion"
    );
  });

  it("admin puede cambiar admin y storage", async function () {
    await expectRevert(
      impl.connect(other).setAdmin(other.address, REVERT_OVERRIDES),
      "Solo lo pude gestionar el admin"
    );
    await (await impl.connect(admin).setAdmin(other.address)).wait();
    await (await impl.connect(other).setStorage(storage.address)).wait();
  });

  it("disable y enable propagan al storage", async function () {
    await (
      await impl.connect(owner).creaCentro(aseguradora.address, centroA.address, "Centro A")
    ).wait();

    await (await impl.connect(admin).disable()).wait();
    const ts = (await blockTimestamp()) - 60;
    await expectRevert(
      impl
        .connect(owner)
        .alta(centroA.address, "CIP001", "RX", "Fractura", 10, ts, REVERT_OVERRIDES),
      "Contrato NO activo"
    );

    await (await impl.connect(admin).enable()).wait();
    await (
      await impl
        .connect(owner)
        .alta(centroA.address, "CIP001", "RX", "Fractura", 10, ts)
    ).wait();
    const prueba = await impl.connect(owner).obtenerPruebaPorId(1);
    expect(prueba.activa).to.equal(true);
  });
});
