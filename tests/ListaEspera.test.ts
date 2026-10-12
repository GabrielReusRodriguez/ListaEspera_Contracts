/* eslint-disable no-undef */
// Right click on the script name and hit "Run" to execute
const { expect } = require("chai");
const { ethers } = require("hardhat");

async function expectRevert(promise, messageFragment) {
  try {
    await promise;
    expect.fail("Expected transaction to revert");
  } catch (error) {
    if (error.message === "Expected transaction to revert") throw error;
    expect(error.message).to.include(messageFragment);
  }
}

async function blockTimestamp() {
  const block = await ethers.provider.getBlock("latest");
  return block.timestamp;
}

/**
 * Orden de despliegue (igual que scripts/deploy_with_ethers.js):
 * 1) ListaEspera(admin)
 * 2) ListaEsperaImpl(listaEspera, admin) -> setImplementation
 * 3) ListaEsperaStorage(impl, admin) -> setStorage
 * 4) gestores hijos (owner = storage) -> setGestor*
 */
async function deployFullStack(admin, aseguradora) {
  const ListaEsperaFactory = await ethers.getContractFactory("ListaEspera");
  const listaEspera = await ListaEsperaFactory.deploy(admin.address);
  await listaEspera.deployed();

  const ImplFactory = await ethers.getContractFactory("ListaEsperaImpl");
  const impl = await ImplFactory.deploy(listaEspera.address, admin.address);
  await impl.deployed();
  await (await listaEspera.setImplementation(impl.address)).wait();

  const StorageFactory = await ethers.getContractFactory("ListaEsperaStorage");
  const storage = await StorageFactory.deploy(impl.address, admin.address);
  await storage.deployed();
  await (await impl.setStorage(storage.address)).wait();

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

  await (await storage.setGestorCentros(centros.address)).wait();
  await (await storage.setGestorPruebasDiagnosticas(pruebas.address)).wait();
  await (await storage.setGestorRedirecciones(redirecciones.address)).wait();
  await (await storage.setAseguradora(aseguradora.address)).wait();

  return { listaEspera, impl, storage, centros };
}

describe("ListaEspera", function () {
  let admin;
  let aseguradora;
  let centroA;
  let centroB;
  let other;
  let listaEspera;
  let storage;

  beforeEach(async function () {
    [admin, aseguradora, centroA, centroB, other] = await ethers.getSigners();
    ({ listaEspera, storage } = await deployFullStack(admin, aseguradora));
  });

  it("despliega el facade con implementacion configurada", async function () {
    console.log("ListaEspera deployed at:" + listaEspera.address);
    expect(listaEspera.address).to.be.a("string");
    expect(listaEspera.address.length).to.equal(42);
  });

  it("revierte operaciones de negocio sin implementacion", async function () {
    const Facade = await ethers.getContractFactory("ListaEspera");
    const bare = await Facade.deploy(admin.address);
    await bare.deployed();

    const ts = (await blockTimestamp()) - 60;
    await expectRevert(
      bare.alta(centroA.address, "CIP001", "RX", "Fractura", 10, ts),
      "Implementacion no configurada"
    );
  });

  it("flujo completo: alta, listados, redireccion, aceptacion y baja", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Hospital A")
    ).wait();
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroB.address, "Hospital B")
    ).wait();

    const tsAlta = (await blockTimestamp()) - 180;
    const altaTx = await listaEspera.alta(
      centroA.address,
      "CIP001",
      "RX-TORAX",
      "Fractura costal",
      30,
      tsAlta
    );
    const altaReceipt = await altaTx.wait();
    expect(altaReceipt.status).to.equal(1);

    const porPaciente = await listaEspera.listaPruebasPorPaciente("CIP001");
    expect(porPaciente.length).to.equal(1);
    expect(porPaciente[0].toNumber()).to.equal(1);

    const porCentro = await listaEspera.listaPruebasPorCentro(centroA.address);
    expect(porCentro.length).to.equal(1);

    const prueba = await listaEspera.obtenerPruebaPorId(1);
    expect(prueba.idPaciente).to.equal("CIP001");
    expect(prueba.codigoPrueba).to.equal("RX-TORAX");
    expect(prueba.diagnostico).to.equal("Fractura costal");
    expect(prueba.centroRealizador).to.equal(centroA.address);
    expect(prueba.activa).to.equal(true);

    const redireccionTx = await listaEspera.creaRedireccion(
      centroA.address,
      1,
      centroB.address
    );
    await redireccionTx.wait();

    const pendientes = await listaEspera.listaRedireccionesPendientes(
      centroB.address
    );
    expect(pendientes.length).to.equal(1);
    expect(pendientes[0].toNumber()).to.equal(1);

    await (
      await listaEspera.aceptaRedireccion(centroB.address, 1)
    ).wait();

    const trasAceptar = await listaEspera.obtenerPruebaPorId(1);
    expect(trasAceptar.centroRealizador).to.equal(centroB.address);

    const tsBaja = await blockTimestamp();
    await (
      await listaEspera.baja(centroB.address, 1, tsBaja, 1)
    ).wait();

    const baja = await listaEspera.obtenerPruebaPorId(1);
    expect(baja.activa).to.equal(false);
    expect(baja.motivoDeBaja).to.equal(1);
    expect(baja.timestampBaja.toNumber()).to.equal(tsBaja);
  });

  it("emite eventos Alta, CreaRedireccion, RechazaRedireccion y Baja", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Hospital A")
    ).wait();
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroB.address, "Hospital B")
    ).wait();

    const tsAlta = (await blockTimestamp()) - 120;
    const altaTx = await listaEspera.alta(
      centroA.address,
      "CIP002",
      "ECO",
      "Quiste",
      20,
      tsAlta
    );
    const altaReceipt = await altaTx.wait();
    expect(altaReceipt.events.length).to.be.greaterThan(0);
    expect(altaReceipt.events[0].event).to.equal("Alta");

    const creaTx = await listaEspera.creaRedireccion(
      centroA.address,
      1,
      centroB.address
    );
    const creaReceipt = await creaTx.wait();
    expect(creaReceipt.events[0].event).to.equal("CreaRedireccion");

    const rechazaTx = await listaEspera.rechazaRedireccion(centroB.address, 1);
    const rechazaReceipt = await rechazaTx.wait();
    expect(rechazaReceipt.events[0].event).to.equal("RechazaRedireccion");

    const tsBaja = await blockTimestamp();
    const bajaTx = await listaEspera.baja(centroA.address, 1, tsBaja, 5);
    const bajaReceipt = await bajaTx.wait();
    expect(bajaReceipt.events[0].event).to.equal("Baja");
  });

  it("emite evento AceptaRedireccion", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Hospital A")
    ).wait();
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroB.address, "Hospital B")
    ).wait();

    const ts = (await blockTimestamp()) - 60;
    await (
      await listaEspera.alta(
        centroA.address,
        "CIP003",
        "TAC",
        "Tumor",
        40,
        ts
      )
    ).wait();
    await (
      await listaEspera.creaRedireccion(centroA.address, 1, centroB.address)
    ).wait();

    const tx = await listaEspera.aceptaRedireccion(centroB.address, 1);
    const receipt = await tx.wait();
    expect(receipt.events[0].event).to.equal("AceptaRedireccion");
  });

  it("solo el admin puede setImplementation, setAdmin, enable y disable", async function () {
    await expectRevert(
      listaEspera.connect(other).setImplementation(other.address),
      "Solo el admin puede gestionarlo"
    );
    await expectRevert(
      listaEspera.connect(other).setAdmin(other.address),
      "Solo el admin puede gestionarlo"
    );
    await expectRevert(
      listaEspera.connect(other).disable(),
      "SOlo el admin puede gestionarlo"
    );

    await (await listaEspera.connect(admin).disable()).wait();
    await expectRevert(
      listaEspera.connect(admin).disable(),
      "El contrato ya esta desactivado"
    );
    await (await listaEspera.connect(admin).enable()).wait();
    await expectRevert(
      listaEspera.connect(admin).enable(),
      "El contrato ya esta activado"
    );
  });

  it("disable del facade bloquea altas en la capa de storage", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Hospital A")
    ).wait();

    await (await listaEspera.connect(admin).disable()).wait();
    const ts = (await blockTimestamp()) - 60;
    await expectRevert(
      listaEspera.alta(centroA.address, "CIP001", "RX", "Fractura", 10, ts),
      "El contrato no esta activo"
    );

    await (await listaEspera.connect(admin).enable()).wait();
    await (
      await listaEspera.alta(
        centroA.address,
        "CIP001",
        "RX",
        "Fractura",
        10,
        ts
      )
    ).wait();
    const prueba = await listaEspera.obtenerPruebaPorId(1);
    expect(prueba.activa).to.equal(true);
  });
});
